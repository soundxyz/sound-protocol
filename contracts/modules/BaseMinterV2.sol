// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { Ownable, OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ISoundEditionV1_2 } from "@core/interfaces/ISoundEditionV1_2.sol";
import { IMinterModuleV2 } from "@core/interfaces/IMinterModuleV2.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";
import { LibMulticaller } from "multicaller/LibMulticaller.sol";

/**
 * @title Minter Base
 * @dev The `BaseMinterV2` class maintains a central storage record of edition mint instances.
 */
abstract contract BaseMinterV2 is IMinterModuleV2, Ownable {
    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /**
     * @dev This is the denominator, in basis points (BPS), for any of the fees.
     */
    uint16 public constant BPS_DENOMINATOR = 10_000;

    /**
     * @dev The maximum basis points (BPS) limit allowed for the affiliate fees.
     */
    uint16 public constant MAX_AFFILIATE_FEE_BPS = 1000;

    /**
     * @dev The maximum basis points (BPS) limit allowed for the platform fees.
     */
    uint16 public constant MAX_PLATFORM_FEE_BPS = 1000;

    /**
     * @dev The maximum platform flat fee per NFT.
     */
    uint96 public constant MAX_PLATFORM_FLAT_FEE = 0.1 ether;

    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev The platform fee address.
     */
    address public platformFeeAddress;

    /**
     * @dev The next mint ID. Shared amongst all editions connected.
     */
    uint96 private _nextMintId;

    /**
     * @dev How much platform fees have been accrued.
     */
    uint128 public platformFeesAccrued;

    /**
     * @dev The amount of platform flat fees per token.
     */
    uint96 public platformFlatFee;

    /**
     * @dev The platform fee in basis points.
     */
    uint16 public platformFeeBPS;

    /**
     * @dev Maps an edition and the mint ID to a mint instance.
     */
    mapping(address => mapping(uint256 => BaseData)) private _baseData;

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

    // Per edition mint parameter setters:
    // -----------------------------------
    // These functions can only be called by the owner or admin of the edition.

    /**
     * @inheritdoc IMinterModuleV2
     */
    function setEditionMintPaused(
        address edition,
        uint128 mintId,
        bool paused
    ) public virtual onlyEditionOwnerOrAdmin(edition) {
        _getBaseData(edition, mintId).mintPaused = paused;
        emit MintPausedSet(edition, mintId, paused);
    }

    /**
     * @inheritdoc IMinterModuleV2
     */
    function setTimeRange(
        address edition,
        uint128 mintId,
        uint32 startTime,
        uint32 endTime
    ) public virtual onlyEditionOwnerOrAdmin(edition) {
        if (startTime >= endTime) revert InvalidTimeRange();
        BaseData storage baseData = _getBaseData(edition, mintId);
        baseData.startTime = startTime;
        baseData.endTime = endTime;
        emit TimeRangeSet(edition, mintId, startTime, endTime);
    }

    /**
     * @inheritdoc IMinterModuleV2
     */
    function setAffiliateFee(
        address edition,
        uint128 mintId,
        uint16 bps
    ) public virtual override onlyEditionOwnerOrAdmin(edition) {
        if (bps > MAX_AFFILIATE_FEE_BPS) revert InvalidAffiliateFeeBPS();
        _getBaseData(edition, mintId).affiliateFeeBPS = bps;
        emit AffiliateFeeSet(edition, mintId, bps);
    }

    /**
     * @inheritdoc IMinterModuleV2
     */
    function setAffiliateMerkleRoot(
        address edition,
        uint128 mintId,
        bytes32 root
    ) public virtual override onlyEditionOwnerOrAdmin(edition) {
        _getBaseData(edition, mintId).affiliateMerkleRoot = root;
        emit AffiliateMerkleRootSet(edition, mintId, root);
    }

    // Withdrawal functions:
    // ---------------------
    // These functions can be called by anyone.

    /**
     * @inheritdoc IMinterModuleV2
     */
    function withdrawForAffiliate(address affiliate) public override {
        uint128 accrued = affiliateFeesAccrued[affiliate];
        if (accrued != 0) {
            affiliateFeesAccrued[affiliate] = 0;
            SafeTransferLib.forceSafeTransferETH(affiliate, accrued);
            emit AffiliateFeesWithdrawn(affiliate, accrued);
        }
    }

    /**
     * @inheritdoc IMinterModuleV2
     */
    function withdrawForPlatform() public override {
        address to = platformFeeAddress;
        if (to == address(0)) revert PlatformFeeAddressIsZero();
        uint128 accrued = platformFeesAccrued;
        if (accrued != 0) {
            platformFeesAccrued = 0;
            SafeTransferLib.forceSafeTransferETH(to, accrued);
            emit PlatformFeesWithdrawn(accrued);
        }
    }

    // Only owner setters:
    // -------------------
    // These functions can only be called by the owner of the minter contract.

    /**
     * @inheritdoc IMinterModuleV2
     */
    function setPlatformFee(uint16 bps) public onlyOwner {
        if (bps > MAX_PLATFORM_FEE_BPS) revert InvalidPlatformFeeBPS();
        platformFeeBPS = bps;
        emit PlatformFeeSet(bps);
    }

    /**
     * @inheritdoc IMinterModuleV2
     */
    function setPlatformFlatFee(uint96 flatFee) public onlyOwner {
        if (flatFee > MAX_PLATFORM_FLAT_FEE) revert InvalidPlatformFlatFee();
        platformFlatFee = flatFee;
        emit PlatformFlatFeeSet(flatFee);
    }

    /**
     * @inheritdoc IMinterModuleV2
     */
    function setPlatformFeeAddress(address addr) public onlyOwner {
        if (addr == address(0)) revert PlatformFeeAddressIsZero();
        platformFeeAddress = addr;
        emit PlatformFeeAddressSet(addr);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IMinterModuleV2
     */
    function nextMintId() external view returns (uint128) {
        return _nextMintId;
    }

    /**
     * @inheritdoc IMinterModuleV2
     */
    function isAffiliatedWithProof(
        address edition,
        uint128 mintId,
        address affiliate,
        bytes32[] calldata affiliateProof
    ) public view virtual override returns (bool) {
        bytes32 root = _getBaseData(edition, mintId).affiliateMerkleRoot;
        // If the root is empty, then use the default logic.
        if (root == bytes32(0)) {
            return affiliate != address(0);
        }
        // Otherwise, check if the affiliate is in the Merkle tree.
        // The check that that affiliate is not a zero address is to prevent libraries
        // that fill up partial Merkle trees with empty leafs from screwing things up.
        return
            affiliate != address(0) &&
            MerkleProofLib.verifyCalldata(affiliateProof, root, _keccak256EncodePacked(affiliate));
    }

    /**
     * @inheritdoc IMinterModuleV2
     */
    function isAffiliated(
        address edition,
        uint128 mintId,
        address affiliate
    ) public view virtual override returns (bool) {
        return isAffiliatedWithProof(edition, mintId, affiliate, MerkleProofLib.emptyProof());
    }

    /**
     * @inheritdoc IMinterModuleV2
     */
    function affiliateMerkleRoot(address edition, uint128 mintId) external view returns (bytes32) {
        return _getBaseData(edition, mintId).affiliateMerkleRoot;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IMinterModuleV2).interfaceId || interfaceId == this.supportsInterface.selector;
    }

    /**
     * @inheritdoc IMinterModuleV2
     */
    function totalPrice(
        address edition,
        uint128 mintId,
        address, /* to */
        uint32 quantity
    ) public view virtual override returns (uint128) {
        unchecked {
            // Will not overflow, as `price` is 96 bits, and `quantity` is 32 bits. 96 + 32 = 128.
            return uint128(uint256(_getBaseData(edition, mintId).price) * uint256(quantity));
        }
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
     * @dev If overriden to return true, the amount of ETH paid must be exact.
     * @return The constant value.
     */
    function _useExactPayment() internal view virtual returns (bool) {
        return true;
    }

    /**
     * @dev Creates an edition mint instance.
     * @param edition The edition address.
     * @param startTime The start time of the mint.
     * @param endTime The end time of the mint.
     * @param affiliateFeeBPS The affiliate fee in basis points.
     * @return mintId The ID for the mint instance.
     * Calling conditions:
     * - Must be owner or admin of the edition.
     */
    function _createEditionMint(
        address edition,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS
    ) internal onlyEditionOwnerOrAdmin(edition) returns (uint128 mintId) {
        if (startTime >= endTime) revert InvalidTimeRange();
        if (affiliateFeeBPS > MAX_AFFILIATE_FEE_BPS) revert InvalidAffiliateFeeBPS();

        mintId = _nextMintId;

        BaseData storage data = _getBaseDataUnchecked(edition, mintId);
        data.startTime = startTime;
        data.endTime = endTime;
        data.affiliateFeeBPS = affiliateFeeBPS;
        data.created = true;

        unchecked {
            _nextMintId = SafeCastLib.toUint96(mintId + 1);
        }

        emit MintConfigCreated(edition, msg.sender, mintId, startTime, endTime, affiliateFeeBPS);
    }

    /**
     * For avoiding stack too deep.
     */
    struct _MintTemps {
        bool affiliated;
        uint256 affiliateFee;
        uint256 remainingPayment;
        uint256 platformFlatFee;
        uint256 platformFee;
        uint256 totalPrice;
        uint256 requiredEtherValue;
    }

    /**
     * @dev Mints `quantity` of `edition` to `to` with a required payment of `requiredEtherValue`.
     * Note: this function should be called at the end of a function due to it refunding any
     * excess ether paid, to adhere to the checks-effects-interactions pattern.
     * Otherwise, a reentrancy guard must be used.
     * @param edition        The edition address.
     * @param mintId         The ID for the mint instance.
     * @param to             The address to mint to.
     * @param quantity       The quantity of tokens to mint.
     * @param affiliate      The affiliate (referral) address.
     * @param affiliateProof The Merkle proof needed for verifying the affiliate, if any.
     * @param attributionId  The attribution ID.
     */
    function _mintTo(
        address edition,
        uint128 mintId,
        address to,
        uint32 quantity,
        address affiliate,
        bytes32[] calldata affiliateProof,
        uint256 attributionId
    ) internal {
        BaseData storage baseData = _getBaseData(edition, mintId);
        _MintTemps memory t;

        /* --------------------- GENERAL CHECKS --------------------- */
        {
            uint32 startTime = baseData.startTime;
            uint32 endTime = baseData.endTime;
            if (block.timestamp < startTime) revert MintNotOpen(block.timestamp, startTime, endTime);
            if (block.timestamp > endTime) revert MintNotOpen(block.timestamp, startTime, endTime);
            if (baseData.mintPaused) revert MintPaused();
        }

        /* ----------- AFFILIATE AND PLATFORM FEES LOGIC ------------ */

        unchecked {
            t.platformFlatFee = uint256(quantity) * uint256(platformFlatFee);
            t.totalPrice = totalPrice(edition, mintId, to, quantity);
            t.requiredEtherValue = t.totalPrice + t.platformFlatFee;

            // Reverts if the payment is not exact, or not enough.
            if (_useExactPayment()) {
                if (msg.value != t.requiredEtherValue) revert WrongPayment(msg.value, t.requiredEtherValue);
            } else {
                if (msg.value < t.requiredEtherValue) revert Underpaid(msg.value, t.requiredEtherValue);
            }

            // Compute the platform fee.
            t.platformFee = (t.totalPrice * uint256(platformFeeBPS)) / uint256(BPS_DENOMINATOR) + t.platformFlatFee;
            // Increment the platform fees accrued.
            platformFeesAccrued = SafeCastLib.toUint128(uint256(platformFeesAccrued) + t.platformFee);
            // Deduct the platform fee.
            // Won't underflow as `platformFee <= requiredEtherValue`;
            t.remainingPayment = t.requiredEtherValue - t.platformFee;
        }

        // Check if the mint is an affiliated mint.
        t.affiliated = isAffiliatedWithProof(edition, mintId, affiliate, affiliateProof);
        unchecked {
            if (t.affiliated) {
                // Compute the affiliate fee.
                t.affiliateFee = (t.totalPrice * uint256(baseData.affiliateFeeBPS)) / uint256(BPS_DENOMINATOR);
                // Deduct the affiliate fee from the remaining payment.
                // Won't underflow as `affiliateFee <= remainingPayment`.
                t.remainingPayment -= t.affiliateFee;
                // Increment the affiliate fees accrued.
                affiliateFeesAccrued[affiliate] = SafeCastLib.toUint128(
                    uint256(affiliateFeesAccrued[affiliate]) + t.affiliateFee
                );
            } else {
                // If the affiliate is not the zero address despite not being
                // affiliated, it might be due to an invalid affiliate proof.
                // Revert to prevent unintended skipping of affiliate payment.
                if (affiliate != address(0)) {
                    revert InvalidAffiliate();
                }
            }
        }

        /* ------------------------- MINT --------------------------- */

        // Emit the event.
        emit Minted(
            edition,
            mintId,
            to,
            // Need to put this call here to avoid stack-too-deep error (it returns `fromTokenId`).
            uint32(ISoundEditionV1_2(edition).mint{ value: t.remainingPayment }(to, quantity)),
            quantity,
            uint128(t.requiredEtherValue),
            uint128(t.platformFee),
            uint128(t.affiliateFee),
            affiliate,
            t.affiliated,
            attributionId
        );

        /* ------------------------- REFUND ------------------------- */

        unchecked {
            if (!_useExactPayment()) {
                // Note: We do this at the end to avoid creating a reentrancy vector.
                // Refund the user any ETH they spent over the current total price of the NFTs.
                if (msg.value > t.requiredEtherValue) {
                    SafeTransferLib.forceSafeTransferETH(msg.sender, msg.value - t.requiredEtherValue);
                }
            }
        }
    }

    /**
     * @dev Increments `totalMinted` with `quantity`, reverting if `totalMinted + quantity > maxMintable`.
     * @param totalMinted The current total number of minted tokens.
     * @param maxMintable The maximum number of mintable tokens.
     * @return `totalMinted` + `quantity`.
     */
    function _incrementTotalMinted(
        uint32 totalMinted,
        uint32 quantity,
        uint32 maxMintable
    ) internal pure returns (uint32) {
        unchecked {
            // Won't overflow as both are 32 bits.
            uint256 sum = uint256(totalMinted) + uint256(quantity);
            if (sum > maxMintable) {
                // Note that the `maxMintable` may vary and drop over time
                // and cause `totalMinted` to be greater than `maxMintable`.
                // The `zeroFloorSub` is equivalent to `max(0, x - y)`.
                uint32 available = uint32(FixedPointMathLib.zeroFloorSub(maxMintable, totalMinted));
                revert ExceedsAvailableSupply(available);
            }
            return uint32(sum);
        }
    }

    /**
     * @dev Returns the storage pointer to the BaseData for (`edition`, `mintId`).
     * @param edition The edition address.
     * @param mintId  The mint ID.
     * @return data Storage pointer to a BaseData.
     */
    function _getBaseDataUnchecked(address edition, uint128 mintId) internal view returns (BaseData storage data) {
        data = _baseData[edition][mintId];
    }

    /**
     * @dev Returns the storage pointer to the BaseData for (`edition`, `mintId`).
     *      Reverts if the mint does not exist.
     * @param edition The edition address.
     * @param mintId  The mint ID.
     * @return data Storage pointer to a BaseData.
     */
    function _getBaseData(address edition, uint128 mintId) internal view returns (BaseData storage data) {
        data = _getBaseDataUnchecked(edition, mintId);
        if (!data.created) revert MintDoesNotExist();
    }

    /**
     * @dev Casts the storage pointer to the BaseData to a bytes32.
     * @param data Storage pointer to a BaseData.
     * @return result The casted value of the slot.
     */
    function _baseDataSlot(BaseData storage data) internal pure returns (bytes32 result) {
        assembly {
            result := data.slot
        }
    }

    /**
     * @dev Equivalent to `keccak256(abi.encodePacked(addr))`.
     * @param addr The address to hash.
     * @return result The hash of the address.
     */
    function _keccak256EncodePacked(address addr) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, addr)
            result := keccak256(0x0c, 0x14)
        }
    }
}
