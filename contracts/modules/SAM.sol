// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import { Ownable, OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { ISAM, SAMInfo } from "./interfaces/ISAM.sol";
import { ISoundCreatorV1 } from "@core/interfaces/ISoundCreatorV1.sol";
import { BondingCurveLib } from "./utils/BondingCurveLib.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { ISoundEditionV1_2 } from "@core/interfaces/ISoundEditionV1_2.sol";
import { LibMulticaller } from "multicaller/LibMulticaller.sol";

/*
 * @title SAM
 * @notice Module for Sound automated market.
 * @author Sound.xyz
 */
contract SAM is ISAM, Ownable {
    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /**
     * @dev This is the denominator, in basis points (BPS), for any of the fees.
     */
    uint16 public constant BPS_DENOMINATOR = 10_000;

    /**
     * @dev The maximum basis points (BPS) limit allowed for the platform fees.
     */
    uint16 public constant MAX_PLATFORM_FEE_BPS = 500;

    /**
     * @dev The maximum basis points (BPS) limit allowed for the artist fees.
     */
    uint16 public constant MAX_ARTIST_FEE_BPS = 1_000;

    /**
     * @dev The maximum basis points (BPS) limit allowed for the affiliate fees.
     */
    uint16 public constant MAX_AFFILIATE_FEE_BPS = 500;

    /**
     * @dev The maximum basis points (BPS) limit allowed for the golden egg fees.
     */
    uint16 public constant MAX_GOLDEN_EGG_FEE_BPS = 500;

    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev How much platform fees have been accrued.
     */
    uint128 public platformFeesAccrued;

    /**
     * @dev The platform fee in basis points.
     */
    uint16 public platformFeeBPS;

    /**
     * @dev Just in case. Won't cost much overhead anyway since it is packed.
     */
    bool internal _reentrancyGuard;

    /**
     * @dev The platform fee address.
     */
    address public platformFeeAddress;

    /**
     * @dev List of approved edition factories.
     */
    address[] internal _approvedEditionFactories;

    /**
     * @dev The data for the sound automated markets.
     * edition => SAMData
     */
    mapping(address => SAMData) internal _samData;

    /**
     * @dev Maps an address to how much affiliate fees have they accrued.
     */
    mapping(address => uint128) public affiliateFeesAccrued;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor() payable {
        _initializeOwner(msg.sender);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISAM
     */
    function create(
        address edition,
        uint96 basePrice,
        uint128 linearPriceSlope,
        uint128 inflectionPrice,
        uint32 inflectionPoint,
        uint32 maxSupply,
        uint32 buyFreezeTime,
        uint16 artistFeeBPS,
        uint16 goldenEggFeeBPS,
        uint16 affiliateFeeBPS,
        address editionBy,
        bytes32 editionSalt
    ) public {
        // We don't use modifiers here in order to prevent stack too deep.
        _requireOnlyEditionOwnerOrAdmin(edition); // `onlyEditionOwnerOrAdmin`.
        _requireOnlyBeforeSAMPhase(edition); // `onlyBeforeSAMPhase`.
        if (maxSupply == 0) revert InvalidMaxSupply();
        if (buyFreezeTime == 0) revert InvalidBuyFreezeTime();
        if (artistFeeBPS > MAX_ARTIST_FEE_BPS) revert InvalidArtistFeeBPS();
        if (goldenEggFeeBPS > MAX_GOLDEN_EGG_FEE_BPS) revert InvalidGoldenEggFeeBPS();
        if (affiliateFeeBPS > MAX_AFFILIATE_FEE_BPS) revert InvalidAffiliateFeeBPS();

        _requireEditionIsApproved(edition, editionBy, editionSalt);

        SAMData storage data = _samData[edition];

        if (data.created) revert SAMAlreadyExists();

        data.basePrice = basePrice;
        data.linearPriceSlope = linearPriceSlope;
        data.inflectionPrice = inflectionPrice;
        data.inflectionPoint = inflectionPoint;
        data.maxSupply = maxSupply;
        data.buyFreezeTime = buyFreezeTime;
        data.artistFeeBPS = artistFeeBPS;
        data.goldenEggFeeBPS = goldenEggFeeBPS;
        data.affiliateFeeBPS = affiliateFeeBPS;
        data.created = true;

        emit Created(
            edition,
            basePrice,
            linearPriceSlope,
            inflectionPrice,
            inflectionPoint,
            maxSupply,
            buyFreezeTime,
            artistFeeBPS,
            goldenEggFeeBPS,
            affiliateFeeBPS
        );
    }

    /**
     * For avoiding stack too deep.
     */
    struct _BuyTemps {
        uint256 fromCurveSupply;
        uint256 fromTokenId;
        uint256 requiredEtherValue;
        uint256 subTotal;
        uint256 platformFee;
        uint256 artistFee;
        uint256 goldenEggFee;
        uint256 affiliateFee;
        uint256 quantity;
        address affiliate;
        bool affiliated;
    }

    /**
     * @inheritdoc ISAM
     */
    function buy(
        address edition,
        address to,
        uint32 quantity,
        address affiliate,
        bytes32[] calldata affiliateProof,
        uint256 attributonId
    ) public payable nonReentrant {
        if (quantity == 0) revert MintZeroQuantity();

        _BuyTemps memory t;
        SAMData storage data = _getSAMData(edition);
        t.quantity = quantity; // Cache the `quantity` to avoid stack too deep.
        t.affiliate = affiliate; // Cache the `affiliate` to avoid stack too deep.
        t.fromCurveSupply = data.supply; // Cache the `data.supply`.

        if (block.timestamp >= data.buyFreezeTime) revert BuyIsFrozen();

        (
            t.requiredEtherValue,
            t.subTotal,
            t.platformFee,
            t.artistFee,
            t.goldenEggFee,
            t.affiliateFee
        ) = _totalBuyPriceAndFees(data, uint32(t.fromCurveSupply), quantity);

        if (msg.value < t.requiredEtherValue) revert Underpaid(msg.value, t.requiredEtherValue);

        unchecked {
            // Check if the purchase won't exceed the supply cap.
            if (t.fromCurveSupply + t.quantity > data.maxSupply) {
                revert ExceedsMaxSupply(uint32(data.maxSupply - t.fromCurveSupply));
            }

            // Check if the affiliate is actually affiliated for edition with the affiliate proof.
            t.affiliated = isAffiliatedWithProof(edition, affiliate, affiliateProof);
            // If affiliated, compute and accrue the affiliate fee.
            if (t.affiliated) {
                // Accrue the affiliate fee.
                if (t.affiliateFee != 0) {
                    affiliateFeesAccrued[affiliate] = SafeCastLib.toUint128(
                        uint256(affiliateFeesAccrued[affiliate]) + t.affiliateFee
                    );
                }
            } else {
                // If the affiliate is not the zero address despite not being
                // affiliated, it might be due to an invalid affiliate proof.
                // Revert to prevent redirection of fees.
                if (affiliate != address(0)) {
                    revert InvalidAffiliate();
                }
                // Otherwise, redirect the affiliate fee to the artist fee instead.
                t.artistFee += t.affiliateFee;
                t.affiliateFee = 0;
            }

            // Accrue the platform fee.
            if (t.platformFee != 0) {
                platformFeesAccrued = SafeCastLib.toUint128(uint256(platformFeesAccrued) + t.platformFee);
            }

            // Accrue the golden egg fee.
            if (t.goldenEggFee != 0) {
                data.goldenEggFeesAccrued = SafeCastLib.toUint112(uint256(data.goldenEggFeesAccrued) + t.goldenEggFee);
            }

            // Add the `subTotal` to the balance.
            data.balance = SafeCastLib.toUint112(uint256(data.balance) + t.subTotal);

            // Add `quantity` to the supply.
            data.supply = SafeCastLib.toUint32(t.fromCurveSupply + t.quantity);

            // Indicate that tokens have already been minted via the bonding curve.
            data.hasMinted = true;

            // Mint the tokens and transfer the artist fee to the edition contract.
            t.fromTokenId = ISoundEditionV1_2(edition).samMint{ value: t.artistFee }(to, quantity);

            // Refund any excess ETH.
            if (msg.value > t.requiredEtherValue) {
                SafeTransferLib.forceSafeTransferETH(msg.sender, msg.value - t.requiredEtherValue);
            }

            emit Bought(
                edition,
                to,
                t.fromTokenId,
                uint32(t.fromCurveSupply),
                uint32(t.quantity),
                uint128(t.requiredEtherValue),
                uint128(t.platformFee),
                uint128(t.artistFee),
                uint128(t.goldenEggFee),
                uint128(t.affiliateFee),
                t.affiliate,
                t.affiliated,
                attributonId
            );
        }
    }

    /**
     * @inheritdoc ISAM
     */
    function sell(
        address edition,
        uint256[] calldata tokenIds,
        uint256 minimumPayout,
        address payoutTo,
        uint256 attributonId
    ) public nonReentrant {
        uint256 quantity = tokenIds.length;
        // To prevent no-op.
        if (quantity == 0) revert BurnZeroQuantity();

        unchecked {
            SAMData storage data = _getSAMData(edition);

            uint256 supply = data.supply;

            // Revert with `InsufficientSupply(available, required)` if `supply < quantity`.
            if (supply < quantity) revert InsufficientSupply(supply, quantity);
            // Will not underflow because of the above check.
            uint256 supplyMinusQuantity = supply - quantity;

            // Compute how much to pay out.
            uint256 payout = _subTotal(data, uint32(supplyMinusQuantity), uint32(quantity));
            // Revert if the payout isn't sufficient.
            if (payout < minimumPayout) revert InsufficientPayout(payout, minimumPayout);

            // Decrease the supply.
            data.supply = uint32(supplyMinusQuantity);

            // Deduct `payout` from `data.balance`.
            uint256 balance = data.balance;
            // Second safety guard. If we actually revert here, something is wrong.
            if (balance < payout) revert("WTF");
            // Will not underflow because of the above check.
            data.balance = uint112(balance - payout);

            // Burn the tokens.
            ISoundEditionV1_2(edition).samBurn(msg.sender, tokenIds);

            // Pay out the ETH.
            SafeTransferLib.forceSafeTransferETH(payoutTo, payout);

            emit Sold(edition, payoutTo, uint32(supply), tokenIds, uint128(payout), attributonId);
        }
    }

    // Bonding curve price parameter setters:
    // --------------------------------------
    // The following functions can only be called before the SAM phase:
    // - Before the mint has concluded on the SoundEdition.
    // - Before `_samData[edition].hasMinted` is set to true.
    //
    // Once any tokens have been minted via SAM,
    // these setters cannot be called.
    //
    // These parameters must be unchangable during the SAM
    // phase to ensure the consistency between the buy and sell prices.

    /**
     * @inheritdoc ISAM
     */
    function setBasePrice(address edition, uint96 basePrice)
        public
        onlyEditionOwnerOrAdmin(edition)
        onlyBeforeSAMPhase(edition)
    {
        SAMData storage data = _getSAMData(edition);
        data.basePrice = basePrice;
        emit BasePriceSet(edition, basePrice);
    }

    /**
     * @inheritdoc ISAM
     */
    function setLinearPriceSlope(address edition, uint128 linearPriceSlope)
        public
        onlyEditionOwnerOrAdmin(edition)
        onlyBeforeSAMPhase(edition)
    {
        SAMData storage data = _getSAMData(edition);
        data.linearPriceSlope = linearPriceSlope;
        emit LinearPriceSlopeSet(edition, linearPriceSlope);
    }

    /**
     * @inheritdoc ISAM
     */
    function setInflectionPrice(address edition, uint128 inflectionPrice)
        public
        onlyEditionOwnerOrAdmin(edition)
        onlyBeforeSAMPhase(edition)
    {
        SAMData storage data = _getSAMData(edition);
        data.inflectionPrice = inflectionPrice;
        emit InflectionPriceSet(edition, inflectionPrice);
    }

    /**
     * @inheritdoc ISAM
     */
    function setInflectionPoint(address edition, uint32 inflectionPoint)
        public
        onlyEditionOwnerOrAdmin(edition)
        onlyBeforeSAMPhase(edition)
    {
        SAMData storage data = _getSAMData(edition);
        data.inflectionPoint = inflectionPoint;
        emit InflectionPointSet(edition, inflectionPoint);
    }

    // Per edition fee BPS setters:
    // ----------------------------
    // To provide flexbility, we allow the artist to adjust the fees
    // even during the SAM phase. As these BPSes cannot exceed hardcoded limits,
    // in the event that am artist account is compromised, the worse case is
    // users having to pay the maximum limits on the fees.
    //
    // Note: The golden egg fee setter is given special treatment:
    // it cannot be called once the mint has concluded on
    // SoundEdition or if any tokens have been minted.

    /**
     * @inheritdoc ISAM
     */
    function setArtistFee(address edition, uint16 bps) public onlyEditionOwnerOrAdmin(edition) {
        SAMData storage data = _getSAMData(edition);
        if (bps > MAX_ARTIST_FEE_BPS) revert InvalidArtistFeeBPS();
        data.artistFeeBPS = bps;
        emit ArtistFeeSet(edition, bps);
    }

    /**
     * @inheritdoc ISAM
     */
    function setGoldenEggFee(address edition, uint16 bps)
        public
        onlyEditionOwnerOrAdmin(edition)
        onlyBeforeSAMPhase(edition)
    {
        SAMData storage data = _getSAMData(edition);
        if (bps > MAX_GOLDEN_EGG_FEE_BPS) revert InvalidGoldenEggFeeBPS();
        data.goldenEggFeeBPS = bps;
        emit GoldenEggFeeSet(edition, bps);
    }

    /**
     * @inheritdoc ISAM
     */
    function setAffiliateFee(address edition, uint16 bps) public onlyEditionOwnerOrAdmin(edition) {
        SAMData storage data = _getSAMData(edition);
        if (bps > MAX_AFFILIATE_FEE_BPS) revert InvalidAffiliateFeeBPS();
        data.affiliateFeeBPS = bps;
        emit AffiliateFeeSet(edition, bps);
    }

    /**
     * @inheritdoc ISAM
     */
    function setAffiliateMerkleRoot(address edition, bytes32 root) public onlyEditionOwnerOrAdmin(edition) {
        // Note that we want to allow adding a root even while the bonding curve
        // is still ongoing, in case the need to prevent spam arises.

        SAMData storage data = _getSAMData(edition);
        data.affiliateMerkleRoot = root;
        emit AffiliateMerkleRootSet(edition, root);
    }

    // Other per edition setters:
    // --------------------------
    // To provide flexbility, we allow the artist to adjust these parameters
    // even during the SAM phase.
    //
    // These functions are unable to inflate the supply during the SAM phase.

    /**
     * @inheritdoc ISAM
     */
    function setMaxSupply(address edition, uint32 maxSupply) public onlyEditionOwnerOrAdmin(edition) {
        SAMData storage data = _getSAMData(edition);
        // Disallow increasing during the SAM phase.
        if (maxSupply > data.maxSupply)
            if (_inSAMPhase(edition)) revert InvalidMaxSupply();
        data.maxSupply = maxSupply;
        emit MaxSupplySet(edition, maxSupply);
    }

    /**
     * @inheritdoc ISAM
     */
    function setBuyFreezeTime(address edition, uint32 buyFreezeTime) public onlyEditionOwnerOrAdmin(edition) {
        SAMData storage data = _getSAMData(edition);
        // Disallow increasing during the SAM phase.
        if (buyFreezeTime > data.buyFreezeTime)
            if (_inSAMPhase(edition)) revert InvalidBuyFreezeTime();
        data.buyFreezeTime = buyFreezeTime;
        emit BuyFreezeTimeSet(edition, buyFreezeTime);
    }

    // Withdrawal functions:
    // ---------------------
    // These functions can be called by anyone.

    /**
     * @inheritdoc ISAM
     */
    function withdrawForAffiliate(address affiliate) public nonReentrant {
        uint128 accrued = affiliateFeesAccrued[affiliate];
        if (accrued != 0) {
            affiliateFeesAccrued[affiliate] = 0;
            SafeTransferLib.forceSafeTransferETH(affiliate, accrued);
            emit AffiliateFeesWithdrawn(affiliate, accrued);
        }
    }

    /**
     * @inheritdoc ISAM
     */
    function withdrawForPlatform() public nonReentrant {
        address to = platformFeeAddress;
        if (to == address(0)) revert PlatformFeeAddressIsZero();
        uint128 accrued = platformFeesAccrued;
        if (accrued != 0) {
            platformFeesAccrued = 0;
            SafeTransferLib.forceSafeTransferETH(to, accrued);
            emit PlatformFeesWithdrawn(accrued);
        }
    }

    /**
     * @inheritdoc ISAM
     */
    function withdrawForGoldenEgg(address edition) public nonReentrant {
        SAMData storage data = _getSAMData(edition);
        uint128 accrued = data.goldenEggFeesAccrued;
        if (accrued != 0) {
            data.goldenEggFeesAccrued = 0;
            address receipient = goldenEggFeeRecipient(edition);
            SafeTransferLib.forceSafeTransferETH(receipient, accrued);
            emit GoldenEggFeesWithdrawn(edition, receipient, accrued);
        }
    }

    // Only onwer setters:
    // -------------------
    // These functions can only be called by the owner of the SAM contract.

    /**
     * @inheritdoc ISAM
     */
    function setPlatformFee(uint16 bps) public onlyOwner {
        if (bps > MAX_PLATFORM_FEE_BPS) revert InvalidPlatformFeeBPS();
        platformFeeBPS = bps;
        emit PlatformFeeSet(bps);
    }

    /**
     * @inheritdoc ISAM
     */
    function setPlatformFeeAddress(address addr) public onlyOwner {
        if (addr == address(0)) revert PlatformFeeAddressIsZero();
        platformFeeAddress = addr;
        emit PlatformFeeAddressSet(addr);
    }

    /**
     * @inheritdoc ISAM
     */
    function setApprovedEditionFactories(address[] calldata factories) public onlyOwner {
        _approvedEditionFactories = factories;
        emit ApprovedEditionFactoriesSet(factories);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISAM
     */
    function samInfo(address edition) external view returns (SAMInfo memory info) {
        SAMData storage data = _getSAMData(edition);
        info.basePrice = data.basePrice;
        info.inflectionPrice = data.inflectionPrice;
        info.linearPriceSlope = data.linearPriceSlope;
        info.inflectionPoint = data.inflectionPoint;
        info.goldenEggFeesAccrued = data.goldenEggFeesAccrued;
        info.supply = data.supply;
        info.balance = data.balance;
        info.maxSupply = data.maxSupply;
        info.buyFreezeTime = data.buyFreezeTime;
        info.artistFeeBPS = data.artistFeeBPS;
        info.affiliateFeeBPS = data.affiliateFeeBPS;
        info.goldenEggFeeBPS = data.goldenEggFeeBPS;
        info.affiliateMerkleRoot = data.affiliateMerkleRoot;
    }

    /**
     * @inheritdoc ISAM
     */
    function totalValue(
        address edition,
        uint32 fromSupply,
        uint32 quantity
    ) public view returns (uint256 total) {
        total = _subTotal(_getSAMData(edition), fromSupply, quantity);
    }

    /**
     * @inheritdoc ISAM
     */
    function totalBuyPriceAndFees(
        address edition,
        uint32 supplyForwardOffset,
        uint32 quantity
    )
        public
        view
        returns (
            uint256 total,
            uint256 platformFee,
            uint256 artistFee,
            uint256 goldenEggFee,
            uint256 affiliateFee
        )
    {
        SAMData storage data = _getSAMData(edition);
        uint256 fromSupply = uint256(data.supply) + uint256(supplyForwardOffset);
        // Reverts if the planned purchase exceeds the supply cap. Just for correctness.
        if (fromSupply + uint256(quantity) > data.maxSupply) {
            revert ExceedsMaxSupply(uint32(data.maxSupply - fromSupply));
        }
        (total, , platformFee, artistFee, goldenEggFee, affiliateFee) = _totalBuyPriceAndFees(
            data,
            SafeCastLib.toUint32(fromSupply),
            quantity
        );
    }

    /**
     * @inheritdoc ISAM
     */
    function totalSellPrice(
        address edition,
        uint32 supplyBackwardOffset,
        uint32 quantity
    ) public view returns (uint256 total) {
        SAMData storage data = _getSAMData(edition);

        // All checked math. Will revert if anything underflows.
        uint256 supply = uint256(data.supply) - uint256(supplyBackwardOffset);
        uint256 supplyMinusQuantity = supply - uint256(quantity);

        total = _subTotal(data, uint32(supplyMinusQuantity), uint32(quantity));
    }

    /**
     * @inheritdoc ISAM
     */
    function goldenEggFeeRecipient(address edition) public view returns (address recipient) {
        // We use assembly because we don't want to revert
        // if the `metadataModule` is not a valid metadata module contract.
        // Plain solidity requires an extra codesize check.
        assembly {
            // Initialize the recipient to the edition by default.
            recipient := edition
            // Store the function selector of `metadataModule()`.
            mstore(0x00, 0x3684d100)

            if iszero(and(eq(returndatasize(), 0x20), staticcall(gas(), edition, 0x1c, 0x04, 0x00, 0x20))) {
                // For better gas estimation, and to require that edition
                // is a contract with the `metadataModule()` function.
                revert(0, 0)
            }

            let metadataModule := mload(0x00)
            // Store the function selector of `getGoldenEggTokenId(address)`.
            mstore(0x00, 0x4baca2b5)
            mstore(0x20, edition)

            let success := staticcall(gas(), metadataModule, 0x1c, 0x24, 0x20, 0x20)
            if iszero(success) {
                // If there is no returndata upon revert,
                // it is likely due to an out-of-gas error.
                if iszero(returndatasize()) {
                    revert(0, 0) // For better gas estimation.
                }
            }

            if and(eq(returndatasize(), 0x20), success) {
                // Store the function selector of `ownerOf(uint256)`.
                mstore(0x00, 0x6352211e)
                // The `goldenEggTokenId` is already in slot 0x20,
                // as the previous staticcall directly writes the output to slot 0x20.

                success := staticcall(gas(), edition, 0x1c, 0x24, 0x00, 0x20)
                if iszero(success) {
                    // If there is no returndata upon revert,
                    // it is likely due to an out-of-gas error.
                    if iszero(returndatasize()) {
                        revert(0, 0) // For better gas estimation.
                    }
                }

                if and(eq(returndatasize(), 0x20), success) {
                    recipient := mload(0x00)
                }
            }
        }
    }

    /**
     * @inheritdoc ISAM
     */
    function goldenEggFeesAccrued(address edition) public view returns (uint128) {
        return _getSAMData(edition).goldenEggFeesAccrued;
    }

    /**
     * @inheritdoc ISAM
     */
    function isAffiliatedWithProof(
        address edition,
        address affiliate,
        bytes32[] calldata affiliateProof
    ) public view returns (bool) {
        bytes32 root = _getSAMData(edition).affiliateMerkleRoot;
        // If the root is empty, then use the default logic.
        if (root == bytes32(0)) {
            return affiliate != address(0);
        }
        // Otherwise, check if the affiliate is in the Merkle tree.
        // The check that that affiliate is not a zero address is to prevent libraries
        // that fill up partial Merkle trees with empty leafs from screwing things up.
        return
            affiliate != address(0) &&
            MerkleProofLib.verifyCalldata(affiliateProof, root, keccak256(abi.encodePacked(affiliate)));
    }

    /**
     * @inheritdoc ISAM
     */
    function isAffiliated(address edition, address affiliate) public view returns (bool) {
        return isAffiliatedWithProof(edition, affiliate, MerkleProofLib.emptyProof());
    }

    /**
     * @inheritdoc ISAM
     */
    function affiliateMerkleRoot(address edition) external view returns (bytes32) {
        return _getSAMData(edition).affiliateMerkleRoot;
    }

    /**
     * @inheritdoc ISAM
     */
    function approvedEditionFactories() external view returns (address[] memory) {
        return _approvedEditionFactories;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public pure override(IERC165) returns (bool) {
        return interfaceId == this.supportsInterface.selector || interfaceId == type(ISAM).interfaceId;
    }

    /**
     * @inheritdoc ISAM
     */
    function moduleInterfaceId() public pure returns (bytes4) {
        return type(ISAM).interfaceId;
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Requires that the caller is the owner or admin of `edition`.
     * @param edition The edition address.
     */
    modifier onlyEditionOwnerOrAdmin(address edition) {
        _requireOnlyEditionOwnerOrAdmin(edition);
        _;
    }

    /**
     * @dev Requires that the caller is the owner or admin of `edition`.
     * @param edition The edition address.
     */
    function _requireOnlyEditionOwnerOrAdmin(address edition) internal view {
        address sender = LibMulticaller.sender();
        if (sender != OwnableRoles(edition).owner())
            if (!OwnableRoles(edition).hasAnyRole(sender, ISoundEditionV1_2(edition).ADMIN_ROLE()))
                revert Unauthorized();
    }

    /**
     * @dev Guards the function from reentrancy.
     */
    modifier nonReentrant() {
        require(_reentrancyGuard == false);
        _reentrancyGuard = true;
        _;
        _reentrancyGuard = false;
    }

    /**
     * @dev Requires that the `edition` is not in SAM phase.
     * @param edition The edition address.
     */
    modifier onlyBeforeSAMPhase(address edition) {
        _requireOnlyBeforeSAMPhase(edition);
        _;
    }

    /**
     * @dev Requires that the `edition` is not in SAM phase.
     * @param edition The edition address.
     */
    function _requireOnlyBeforeSAMPhase(address edition) internal view {
        if (_inSAMPhase(edition)) revert InSAMPhase();
    }

    /**
     * @dev Returns whether the edition is in SAM phase.
     * @param edition The edition address.
     * @return result Whether the edition has any minted via SAM, or has initial mints concluded.
     */
    function _inSAMPhase(address edition) internal view returns (bool result) {
        // As long as one token has been bought on the bonding curve,
        // the initial mints have already concluded. This `hasMinted` check
        // disallows a spoofed `mintConcluded` from changing the curve parameters.
        result = _samData[edition].hasMinted || ISoundEditionV1_2(edition).mintConcluded();
    }

    /**
     * @dev Returns the storage pointer to the SAMData for `edition`.
     *      Reverts if the Sound Automated Market does not exist.
     * @param edition The edition address.
     * @return data Storage pointer to a SAMData.
     */
    function _getSAMData(address edition) internal view returns (SAMData storage data) {
        data = _samData[edition];
        if (!data.created) revert SAMDoesNotExist();
    }

    /**
     * @dev Returns the area under the bonding curve, which is the price before any fees.
     * @param data       Storage pointer to a SAMData.
     * @param fromSupply The starting SAM supply.
     * @param quantity   The number of tokens to be minted.
     * @return subTotal  The area under the bonding curve.
     */
    function _subTotal(
        SAMData storage data,
        uint32 fromSupply,
        uint32 quantity
    ) internal view returns (uint256 subTotal) {
        unchecked {
            subTotal = uint256(data.basePrice) * uint256(quantity);
            subTotal += BondingCurveLib.linearSum(data.linearPriceSlope, fromSupply, quantity);
            subTotal += BondingCurveLib.sigmoid2Sum(data.inflectionPoint, data.inflectionPrice, fromSupply, quantity);
        }
    }

    /**
     * @dev Returns the total buy price and the fee per BPS.
     * @param data       Storage pointer to a SAMData.
     * @param fromSupply The starting SAM supply.
     * @param quantity   The number of tokens to be minted.
     * @return total        The total buy price with fees.
     * @return subTotal     The buy price before fees.
     * @return platformFee  The platform fee.
     * @return artistFee    The artist fee.
     * @return goldenEggFee The golden egg fee.
     * @return affiliateFee The affiliate fee.
     */
    function _totalBuyPriceAndFees(
        SAMData storage data,
        uint32 fromSupply,
        uint32 quantity
    )
        internal
        view
        returns (
            uint256 total,
            uint256 subTotal,
            uint256 platformFee,
            uint256 artistFee,
            uint256 goldenEggFee,
            uint256 affiliateFee
        )
    {
        unchecked {
            subTotal = _subTotal(data, fromSupply, quantity);

            uint256 feePerBPS = FixedPointMathLib.rawDiv(subTotal, BPS_DENOMINATOR);

            platformFee = uint256(platformFeeBPS) * feePerBPS;
            artistFee = uint256(data.artistFeeBPS) * feePerBPS;
            goldenEggFee = uint256(data.goldenEggFeeBPS) * feePerBPS;
            affiliateFee = uint256(data.affiliateFeeBPS) * feePerBPS;

            total = subTotal + platformFee + artistFee + goldenEggFee + affiliateFee;
        }
    }

    /**
     * @dev Reverts if the `edition` is not created by an approved factory.
     * @param edition The edition address.
     * @param by      The address which created the edition via the factory.
     * @param salt    The salt used to create the edition via the factory.
     */
    function _requireEditionIsApproved(
        address edition,
        address by,
        bytes32 salt
    ) internal view virtual {
        uint256 n = _approvedEditionFactories.length;
        unchecked {
            // As long as there is one approved factory that states that it has
            // created the `edition`, we return from the function, instead of reverting.
            for (uint256 i; i != n; ++i) {
                address factory = _approvedEditionFactories[i];
                try ISoundCreatorV1(factory).soundEditionAddress(by, salt) returns (address addr, bool) {
                    if (addr == edition) return;
                } catch {}
            }
        }
        revert UnapprovedEdition();
    }
}
