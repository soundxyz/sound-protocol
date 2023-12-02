// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { Ownable, OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ISoundEditionV2_1 } from "@core/interfaces/ISoundEditionV2_1.sol";
import { ISuperMinterV1_1 } from "@modules/interfaces/ISuperMinterV1_1.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { EIP712 } from "solady/utils/EIP712.sol";
import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { LibZip } from "solady/utils/LibZip.sol";
import { LibMap } from "solady/utils/LibMap.sol";
import { DelegateCashLib } from "@modules/utils/DelegateCashLib.sol";
import { LibOps } from "@core/utils/LibOps.sol";
import { LibMulticaller } from "multicaller/LibMulticaller.sol";

/**
 * @title SuperMinterV1_1
 * @dev The `SuperMinterV1_1` class is a generalized minter.
 */
contract SuperMinterV1_1 is ISuperMinterV1_1, EIP712 {
    using LibBitmap for *;
    using MerkleProofLib for *;
    using LibMap for *;

    // =============================================================
    //                            STRUCTS
    // =============================================================

    /**
     * @dev A struct to hold the mint data in storage.
     */
    struct MintData {
        // The platform address.
        address platform;
        // The price per token.
        uint96 price;
        // The start time of the mint.
        uint32 startTime;
        // The end time of the mint.
        uint32 endTime;
        // The maximum number of tokens an account can mint in this mint.
        uint32 maxMintablePerAccount;
        // The maximum tokens mintable.
        uint32 maxMintable;
        // The total number of tokens minted.
        uint32 minted;
        // The affiliate fee BPS.
        uint16 affiliateFeeBPS;
        // The offset to the next mint data in the linked list.
        uint16 next;
        // The head of the mint data linked list.
        // Only stored in the 0-th mint data per edition.
        uint16 head;
        // The total number of mint data.
        // Only stored in the 0-th mint data per edition.
        uint16 numMintData;
        // The total number of mints for the edition-tier.
        // Only stored in the 0-th mint data per edition-tier.
        uint8 nextScheduleNum;
        // The mode of the mint.
        uint8 mode;
        // The packed boolean flags.
        uint8 flags;
        // The affiliate Merkle root, if any.
        bytes32 affiliateMerkleRoot;
        // The Merkle root hash, required if `mode` is `VERIFY_MERKLE`.
        bytes32 merkleRoot;
        // The signer address, required if `mode` is `VERIFY_SIGNATURE`.
        address signer;
    }

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /**
     * @dev The GA tier. Which is 0.
     */
    uint8 public constant GA_TIER = 0;

    /**
     * @dev For EIP-712 signature digest calculation.
     */
    bytes32 public constant MINT_TO_TYPEHASH =
        // prettier-ignore
        keccak256(
            "MintTo("
                "address edition,"
                "uint8 tier,"
                "uint8 scheduleNum,"
                "address to,"
                "uint32 signedQuantity,"
                "uint32 signedClaimTicket,"
                "uint96 signedPrice,"
                "uint32 signedDeadline,"
                "address affiliate"
            ")"
        );

    /**
     * @dev For EIP-712 signature digest calculation.
     */
    bytes32 public constant DOMAIN_TYPEHASH = _DOMAIN_TYPEHASH;

    /**
     * @dev The default value for options.
     */
    uint8 public constant DEFAULT = 0;

    /**
     * @dev The Merkle drop mint mode.
     */
    uint8 public constant VERIFY_MERKLE = 1;

    /**
     * @dev The Signature mint mint mode.
     */
    uint8 public constant VERIFY_SIGNATURE = 2;

    /**
     * @dev The denominator of all BPS calculations.
     */
    uint16 public constant BPS_DENOMINATOR = LibOps.BPS_DENOMINATOR;

    /**
     * @dev The maximum affiliate fee BPS.
     */
    uint16 public constant MAX_AFFILIATE_FEE_BPS = 1000;

    /**
     * @dev The maximum platform per-mint fee BPS.
     */
    uint16 public constant MAX_PLATFORM_PER_MINT_FEE_BPS = 1000;

    /**
     * @dev The maximum platform per-mint flat fee.
     * Also applies to the maximum per-mint flat fee.
     */
    uint96 public constant MAX_PLATFORM_PER_MINT_FLAT_FEE = 0.1 ether;

    /**
     * @dev The maximum platform per-transaction flat fee.
     */
    uint96 public constant MAX_PLATFORM_PER_TX_FLAT_FEE = 0.1 ether;

    /**
     * @dev The boolean flag on whether the mint has been created.
     */
    uint8 internal constant _MINT_CREATED_FLAG = 1 << 0;

    /**
     * @dev The boolean flag on whether the mint is paused.
     */
    uint8 internal constant _MINT_PAUSED_FLAG = 1 << 1;

    /**
     * @dev The boolean flag on whether the signer is the platform's signer.
     */
    uint8 internal constant _USE_PLATFORM_SIGNER_FLAG = 1 << 2;

    /**
     * @dev The index for the per-platform default fee config.
     *      We use 256, as the tier is uint8, which ranges from 0 to 255.
     */
    uint16 internal constant _DEFAULT_FEE_CONFIG_INDEX = 256;

    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev A mapping of `platform` => `feesAccrued`.
     */
    mapping(address => uint256) public platformFeesAccrued;

    /**
     * @dev A mapping of `platform` => `feeRecipient`.
     */
    mapping(address => address) public platformFeeAddress;

    /**
     * @dev A mapping of `affiliate` => `feesAccrued`.
     */
    mapping(address => uint256) public affiliateFeesAccrued;

    /**
     * @dev A mapping of `platform` => `price`.
     */
    mapping(address => uint96) public gaPrice;

    /**
     * @dev A mapping of `platform` => `platformSigner`.
     */
    mapping(address => address) public platformSigner;

    /**
     * @dev A mapping of `mintId` => `mintData`.
     */
    mapping(uint256 => MintData) internal _mintData;

    /**
     * @dev A mapping of `platformTierId` => `platformFeeConfig`.
     */
    mapping(uint256 => PlatformFeeConfig) internal _platformFeeConfigs;

    /**
     * @dev A mapping of `to` => `mintId` => `numberMinted`.
     */
    mapping(address => LibMap.Uint32Map) internal _numberMinted;

    /**
     * @dev A mapping of `mintId` => `signedClaimedTicket` => `claimed`.
     */
    mapping(uint256 => LibBitmap.Bitmap) internal _claimsBitmaps;

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function createEditionMint(MintCreation memory c) public returns (uint8 scheduleNum) {
        _requireOnlyEditionOwnerOrAdmin(c.edition);

        _validateAffiliateFeeBPS(c.affiliateFeeBPS);

        uint8 mode = c.mode;

        if (mode == DEFAULT) {
            c.signer = address(0);
            c.merkleRoot = bytes32(0);
        } else if (mode == VERIFY_MERKLE) {
            _validateMerkleRoot(c.merkleRoot);
            c.signer = address(0);
        } else if (mode == VERIFY_SIGNATURE) {
            _validateSigner(c.signer);
            c.merkleRoot = bytes32(0);
            c.maxMintablePerAccount = type(uint32).max;
        } else {
            revert InvalidMode();
        }

        // If GA, overwrite any immutable variables as required.
        if (c.tier == GA_TIER) {
            c.endTime = type(uint32).max;
            c.maxMintablePerAccount = type(uint32).max;
            // We allow the `price` to be the minimum price if the `mode` is `VERIFY_SIGNATURE`.
            // Otherwise, the actual default price is the live value of `gaPrice[platform]`,
            // and we'll simply set it to zero to avoid a SLOAD.
            if (mode != VERIFY_SIGNATURE) c.price = 0;
            // Set `maxMintable` to the maximum only if `mode` is `DEFAULT`.
            if (mode == DEFAULT) c.maxMintable = type(uint32).max;
        }

        _validateTimeRange(c.startTime, c.endTime);
        _validateMaxMintablePerAccount(c.maxMintablePerAccount);
        _validateMaxMintable(c.maxMintable);

        unchecked {
            MintData storage tierHead = _mintData[LibOps.packId(c.edition, c.tier, 0)];
            MintData storage editionHead = _mintData[LibOps.packId(c.edition, 0)];

            scheduleNum = tierHead.nextScheduleNum;
            uint256 n = scheduleNum;
            if (++n >= 1 << 8) LibOps.revertOverflow();
            tierHead.nextScheduleNum = uint8(n);

            n = editionHead.numMintData;
            if (++n >= 1 << 16) LibOps.revertOverflow();
            editionHead.numMintData = uint16(n);

            uint256 mintId = LibOps.packId(c.edition, c.tier, scheduleNum);
            bool usePlatformSigner = c.signer == address(1);

            MintData storage d = _mintData[mintId];
            d.platform = c.platform;
            d.price = c.price;
            d.startTime = c.startTime;
            d.endTime = c.endTime;
            d.maxMintablePerAccount = c.maxMintablePerAccount;
            d.maxMintable = c.maxMintable;
            d.affiliateFeeBPS = c.affiliateFeeBPS;
            d.mode = c.mode;
            d.flags = _MINT_CREATED_FLAG | LibOps.toFlag(usePlatformSigner, _USE_PLATFORM_SIGNER_FLAG);
            d.next = editionHead.head;
            editionHead.head = uint16((uint256(c.tier) << 8) | uint256(scheduleNum));

            // Skip writing zeros, to avoid cold SSTOREs.
            if (c.affiliateMerkleRoot != bytes32(0)) d.affiliateMerkleRoot = c.affiliateMerkleRoot;
            if (c.merkleRoot != bytes32(0)) d.merkleRoot = c.merkleRoot;
            if (c.signer != address(0)) {
                if (!usePlatformSigner) d.signer = c.signer; // Only write if it is not the platform signer.
            }

            emit MintCreated(c.edition, c.tier, scheduleNum, c);
        }
    }

    function _computeAndAccrueFees(
        MintTo calldata p,
        MintData storage d,
        TotalPriceAndFees memory f
    ) internal returns (MintedLogData memory l) {
        // The following block can use unchecked math, but we'll leave it as checked math
        // for more safety redundancy. Burns about few hundred gas more.
        //
        // The `finalArtistFee` is whatever that remains after deducting all of the
        // platform fees and affiliate fees from the ETH sent.
        //
        // Fees are accrued in 3 places:
        // - The `finalPlatformFee` is accrued in the `platformFeesAccrued` mapping.
        // - The `finalAffiliateFee` is accrued in the `affiliateFeesAccrued` mapping.
        // - The `finalArtistFee` is accrued in the `SoundEdition`.
        //
        // At the end of this block, the invariant must hold:
        // `l.finalArtistFee + l.finalPlatformFee + l.finalAffiliateFee == f.total`.
        {
            if (msg.value != f.total) revert WrongPayment(msg.value, f.total); // Require exact payment.

            // Deduct the platform fees (both BPS and flat) first.
            // We'll deduct the affiliate fees in the affiliate fees calculation step.
            l.finalArtistFee = f.total - f.platformFee;
            // Initialize to the platform fee.
            l.finalPlatformFee = f.platformFee;
            // Yeah, we know it's left curved.
            l.affiliate = p.to == p.affiliate ? address(0) : p.affiliate;

            /* --------------------- AFFILIATE FEES --------------------- */

            if (l.affiliated = _isAffiliatedWithProof(d, l.affiliate, p.affiliateProof)) {
                // There are two kinds of affiliate fees:
                // - The BPS based affiliateFee, which will be deducted from the artist's fee.
                // - The per-mint flat affiliate incentive fee, which will be be deducted from the platform's fee.

                // Deduct the BPS based affiliate fee from the artist's fee.
                l.finalArtistFee -= f.affiliateFee;
                // Deduct the affiliate incentive from the platform's fee.
                l.finalPlatformFee -= f.affiliateIncentive;
                // Sum up the BPS based affiliate fee and the affiliate incentive.
                l.finalAffiliateFee = f.affiliateFee + f.affiliateIncentive;
                l.finalAffiliateIncentive = f.affiliateIncentive;
                affiliateFeesAccrued[p.affiliate] += l.finalAffiliateFee;
            } else {
                // Proof may be invalid, revert to prevent unintended skipping of affiliate fee.
                if (p.affiliate != address(0)) revert InvalidAffiliate();
            }

            /* -------------------- CHEAP MINT FEES --------------------- */

            if (f.cheapMintIncentive != 0 && f.unitPrice <= f.cheapMintIncentiveThreshold) {
                // Divert the cheap mint incentive from the platform to the artist.
                l.finalPlatformFee -= f.cheapMintIncentive;
                l.finalCheapMintIncentive = f.cheapMintIncentive;
                l.finalArtistFee += l.finalCheapMintIncentive;
            }

            platformFeesAccrued[d.platform] += l.finalPlatformFee; // Accrue the platform fee.
        }
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function mintTo(MintTo calldata p) public payable {
        MintData storage d = _getMintData(LibOps.packId(p.edition, p.tier, p.scheduleNum));

        /* ------------------- CHECKS AND UPDATES ------------------- */

        // Check if the mint is open.
        if (LibOps.or(block.timestamp < d.startTime, block.timestamp > d.endTime))
            revert MintNotOpen(block.timestamp, d.startTime, d.endTime);
        if (_isPaused(d)) revert MintPaused(); // Check if the mint is not paused.

        // Perform the sub workflows depending on the mint mode.
        uint8 mode = d.mode;
        if (mode == VERIFY_MERKLE) _verifyMerkle(d, p);
        else if (mode == VERIFY_SIGNATURE) _verifyAndClaimSignature(d, p);

        _incrementMinted(mode, d, p);

        /* ----------------- COMPUTE AND ACCRUE FEES ---------------- */

        TotalPriceAndFees memory f = _totalPriceAndFees(p.tier, d, p.quantity, p.signedPrice);
        MintedLogData memory l = _computeAndAccrueFees(p, d, f);

        /* ------------------------- MINT --------------------------- */

        ISoundEditionV2_1 edition = ISoundEditionV2_1(p.edition);
        l.quantity = p.quantity;
        l.fromTokenId = edition.mint{ value: l.finalArtistFee }(p.tier, p.to, p.quantity);
        l.allowlisted = p.allowlisted;
        l.allowlistedQuantity = p.allowlistedQuantity;
        l.signedClaimTicket = p.signedClaimTicket;
        l.requiredEtherValue = f.total;
        l.unitPrice = f.unitPrice;

        emit Minted(p.edition, p.tier, p.scheduleNum, p.to, l, p.attributionId);
    }

    // Per edition mint parameter setters:
    // -----------------------------------
    // These functions can only be called by the owner or admin of the edition.

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function setPrice(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        uint96 price
    ) public onlyEditionOwnerOrAdmin(edition) {
        uint256 mintId = LibOps.packId(edition, tier, scheduleNum);
        MintData storage d = _getMintData(mintId);
        // If the tier is GA and the `mode` is `VERIFY_SIGNATURE`, we'll use `gaPrice[platform]`.
        if (tier == GA_TIER && d.mode != VERIFY_SIGNATURE) revert NotConfigurable();
        d.price = price;
        emit PriceSet(edition, tier, scheduleNum, price);
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function setPaused(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        bool paused
    ) public onlyEditionOwnerOrAdmin(edition) {
        uint256 mintId = LibOps.packId(edition, tier, scheduleNum);
        MintData storage d = _getMintData(mintId);
        d.flags = LibOps.setFlagTo(d.flags, _MINT_PAUSED_FLAG, paused);
        emit PausedSet(edition, tier, scheduleNum, paused);
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function setTimeRange(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        uint32 startTime,
        uint32 endTime
    ) public onlyEditionOwnerOrAdmin(edition) {
        uint256 mintId = LibOps.packId(edition, tier, scheduleNum);
        MintData storage d = _getMintData(mintId);
        // For GA tier, `endTime` will always be `type(uint32).max`.
        if (tier == GA_TIER && endTime != type(uint32).max) revert NotConfigurable();
        _validateTimeRange(startTime, endTime);
        d.startTime = startTime;
        d.endTime = endTime;
        emit TimeRangeSet(edition, tier, scheduleNum, startTime, endTime);
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function setStartTime(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        uint32 startTime
    ) public {
        uint256 mintId = LibOps.packId(edition, tier, scheduleNum);
        setTimeRange(edition, tier, scheduleNum, startTime, _mintData[mintId].endTime);
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function setAffiliateFee(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        uint16 bps
    ) public onlyEditionOwnerOrAdmin(edition) {
        uint256 mintId = LibOps.packId(edition, tier, scheduleNum);
        MintData storage d = _getMintData(mintId);
        _validateAffiliateFeeBPS(bps);
        d.affiliateFeeBPS = bps;
        emit AffiliateFeeSet(edition, tier, scheduleNum, bps);
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function setAffiliateMerkleRoot(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        bytes32 root
    ) public onlyEditionOwnerOrAdmin(edition) {
        uint256 mintId = LibOps.packId(edition, tier, scheduleNum);
        MintData storage d = _getMintData(mintId);
        d.affiliateMerkleRoot = root;
        emit AffiliateMerkleRootSet(edition, tier, scheduleNum, root);
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function setMaxMintablePerAccount(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        uint32 value
    ) public onlyEditionOwnerOrAdmin(edition) {
        uint256 mintId = LibOps.packId(edition, tier, scheduleNum);
        MintData storage d = _getMintData(mintId);
        // GA tier will have `type(uint32).max`.
        if (tier == GA_TIER) revert NotConfigurable();
        // Signature mints will have `type(uint32).max`.
        if (d.mode == VERIFY_SIGNATURE) revert NotConfigurable();
        _validateMaxMintablePerAccount(value);
        d.maxMintablePerAccount = value;
        emit MaxMintablePerAccountSet(edition, tier, scheduleNum, value);
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function setMaxMintable(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        uint32 value
    ) public onlyEditionOwnerOrAdmin(edition) {
        uint256 mintId = LibOps.packId(edition, tier, scheduleNum);
        MintData storage d = _getMintData(mintId);
        // We allow edits for GA tier, if the `mode` is not `DEFAULT`.
        if (tier == GA_TIER && d.mode == DEFAULT) revert NotConfigurable();
        _validateMaxMintable(value);
        d.maxMintable = value;
        emit MaxMintableSet(edition, tier, scheduleNum, value);
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function setMerkleRoot(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        bytes32 merkleRoot
    ) public onlyEditionOwnerOrAdmin(edition) {
        uint256 mintId = LibOps.packId(edition, tier, scheduleNum);
        MintData storage d = _getMintData(mintId);
        if (d.mode != VERIFY_MERKLE) revert NotConfigurable();
        _validateMerkleRoot(merkleRoot);
        d.merkleRoot = merkleRoot;
        emit MerkleRootSet(edition, tier, scheduleNum, merkleRoot);
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function setSigner(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        address signer
    ) public onlyEditionOwnerOrAdmin(edition) {
        uint256 mintId = LibOps.packId(edition, tier, scheduleNum);
        MintData storage d = _getMintData(mintId);
        if (d.mode != VERIFY_SIGNATURE) revert NotConfigurable();
        _validateSigner(signer);
        bool usePlatformSigner = signer == address(1);
        d.flags = LibOps.setFlagTo(d.flags, _USE_PLATFORM_SIGNER_FLAG, usePlatformSigner);
        if (!usePlatformSigner) d.signer = signer;
        emit SignerSet(edition, tier, scheduleNum, signer);
    }

    // Withdrawal functions:
    // ---------------------
    // These functions can be called by anyone.

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function withdrawForAffiliate(address affiliate) public {
        uint256 accrued = affiliateFeesAccrued[affiliate];
        if (accrued != 0) {
            affiliateFeesAccrued[affiliate] = 0;
            SafeTransferLib.forceSafeTransferETH(affiliate, accrued);
            emit AffiliateFeesWithdrawn(affiliate, accrued);
        }
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function withdrawForPlatform(address platform) public {
        address recipient = platformFeeAddress[platform];
        _validatePlatformFeeAddress(recipient);
        uint256 accrued = platformFeesAccrued[platform];
        if (accrued != 0) {
            platformFeesAccrued[platform] = 0;
            SafeTransferLib.forceSafeTransferETH(recipient, accrued);
            emit PlatformFeesWithdrawn(platform, accrued);
        }
    }

    // Platform fee functions:
    // -----------------------
    // These functions enable any caller to set their own platform fees.

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function setPlatformFeeAddress(address recipient) public {
        address sender = LibMulticaller.senderOrSigner();
        _validatePlatformFeeAddress(recipient);
        platformFeeAddress[sender] = recipient;
        emit PlatformFeeAddressSet(sender, recipient);
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function setPlatformFeeConfig(uint8 tier, PlatformFeeConfig memory c) public {
        address sender = LibMulticaller.senderOrSigner();
        _validatePlatformFeeConfig(c);
        _platformFeeConfigs[LibOps.packId(sender, tier)] = c;
        emit PlatformFeeConfigSet(sender, tier, c);
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function setDefaultPlatformFeeConfig(PlatformFeeConfig memory c) public {
        address sender = LibMulticaller.senderOrSigner();
        _validatePlatformFeeConfig(c);
        _platformFeeConfigs[LibOps.packId(sender, _DEFAULT_FEE_CONFIG_INDEX)] = c;
        emit DefaultPlatformFeeConfigSet(sender, c);
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function setGAPrice(uint96 price) public {
        address sender = LibMulticaller.senderOrSigner();
        gaPrice[sender] = price;
        emit GAPriceSet(sender, price);
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function setPlatformSigner(address signer) public {
        address sender = LibMulticaller.senderOrSigner();
        platformSigner[sender] = signer;
        emit PlatformSignerSet(sender, signer);
    }

    // Misc functions:
    // ---------------

    /**
     * @dev For calldata compression.
     */
    fallback() external payable {
        LibZip.cdFallback();
    }

    /**
     * @dev For calldata compression.
     */
    receive() external payable {
        LibZip.cdFallback();
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function computeMintToDigest(MintTo calldata p) public view returns (bytes32) {
        // prettier-ignore
        return
            _hashTypedData(keccak256(abi.encode(
                MINT_TO_TYPEHASH,
                p.edition,
                p.tier, 
                p.scheduleNum,
                p.to,
                p.signedQuantity,
                p.signedClaimTicket,
                p.signedPrice,
                p.signedDeadline,
                p.affiliate
            )));
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function totalPriceAndFees(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        uint32 quantity
    ) public view returns (TotalPriceAndFees memory) {
        return totalPriceAndFeesWithSignedPrice(edition, tier, scheduleNum, quantity, 0);
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function totalPriceAndFeesWithSignedPrice(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        uint32 quantity,
        uint96 signedPrice
    ) public view returns (TotalPriceAndFees memory) {
        uint256 mintId = LibOps.packId(edition, tier, scheduleNum);
        return _totalPriceAndFees(tier, _getMintData(mintId), quantity, signedPrice);
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function nextScheduleNum(address edition, uint8 tier) public view returns (uint8) {
        return _mintData[LibOps.packId(edition, tier, 0)].nextScheduleNum;
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function numberMinted(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        address collector
    ) external view returns (uint32) {
        uint256 mintId = LibOps.packId(edition, tier, scheduleNum);
        return _numberMinted[collector].get(mintId);
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function isAffiliatedWithProof(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        address affiliate,
        bytes32[] calldata affiliateProof
    ) public view virtual returns (bool) {
        uint256 mintId = LibOps.packId(edition, tier, scheduleNum);
        return _isAffiliatedWithProof(_getMintData(mintId), affiliate, affiliateProof);
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function isAffiliated(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        address affiliate
    ) public view virtual returns (bool) {
        return isAffiliatedWithProof(edition, tier, scheduleNum, affiliate, MerkleProofLib.emptyProof());
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function checkClaimTickets(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        uint32[] calldata claimTickets
    ) public view returns (bool[] memory claimed) {
        uint256 mintId = LibOps.packId(edition, tier, scheduleNum);
        LibBitmap.Bitmap storage bitmap = _claimsBitmaps[mintId];
        claimed = new bool[](claimTickets.length);
        unchecked {
            for (uint256 i; i != claimTickets.length; i++) {
                claimed[i] = bitmap.get(claimTickets[i]);
            }
        }
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function platformFeeConfig(address platform, uint8 tier) public view returns (PlatformFeeConfig memory) {
        return _platformFeeConfigs[LibOps.packId(platform, tier)];
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function defaultPlatformFeeConfig(address platform) public view returns (PlatformFeeConfig memory) {
        return _platformFeeConfigs[LibOps.packId(platform, _DEFAULT_FEE_CONFIG_INDEX)];
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function effectivePlatformFeeConfig(address platform, uint8 tier) public view returns (PlatformFeeConfig memory) {
        PlatformFeeConfig memory c = _platformFeeConfigs[LibOps.packId(platform, tier)];
        if (!c.active) c = _platformFeeConfigs[LibOps.packId(platform, _DEFAULT_FEE_CONFIG_INDEX)];
        if (!c.active) delete c; // Set all values to zero.
        return c;
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function mintInfoList(address edition) public view returns (MintInfo[] memory a) {
        unchecked {
            MintData storage editionHead = _mintData[LibOps.packId(edition, 0)];
            uint256 n = editionHead.numMintData; // Linked-list length.
            uint16 p = editionHead.head; // Current linked-list pointer.
            a = new MintInfo[](n);
            // Traverse the linked-list and fill the array in reverse.
            // Front: earliest added mint schedule. Back: latest added mint schedule.
            while (n != 0) {
                MintData storage d = _mintData[LibOps.packId(edition, p)];
                a[--n] = mintInfo(edition, uint8(p >> 8), uint8(p));
                p = d.next;
            }
        }
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function mintInfo(
        address edition,
        uint8 tier,
        uint8 scheduleNum
    ) public view returns (MintInfo memory info) {
        uint256 mintId = LibOps.packId(edition, tier, scheduleNum);
        MintData storage d = _getMintData(mintId);
        info.edition = edition;
        info.tier = tier;
        info.scheduleNum = scheduleNum;
        info.platform = d.platform;
        info.price = tier == GA_TIER && d.mode != VERIFY_SIGNATURE ? gaPrice[d.platform] : d.price;
        info.startTime = d.startTime;
        info.endTime = d.endTime;
        info.maxMintablePerAccount = d.maxMintablePerAccount;
        info.maxMintable = d.maxMintable;
        info.minted = d.minted;
        info.affiliateFeeBPS = d.affiliateFeeBPS;
        info.mode = d.mode;
        info.paused = _isPaused(d);
        info.affiliateMerkleRoot = d.affiliateMerkleRoot;
        info.merkleRoot = d.merkleRoot;
        info.signer = _effectiveSigner(d);
        info.usePlatformSigner = _usePlatformSigner(d);
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function name() external pure returns (string memory name_) {
        (name_, ) = _domainNameAndVersion();
    }

    /**
     * @inheritdoc ISuperMinterV1_1
     */
    function version() external pure returns (string memory version_) {
        (, version_) = _domainNameAndVersion();
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            LibOps.or(
                interfaceId == type(ISuperMinterV1_1).interfaceId,
                interfaceId == this.supportsInterface.selector
            );
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    // Validations:
    // ------------

    /**
     * @dev Guards a function to make it callable only by the edition's owner or admin.
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
        address sender = LibMulticaller.senderOrSigner();
        if (sender != OwnableRoles(edition).owner())
            if (!OwnableRoles(edition).hasAnyRole(sender, LibOps.ADMIN_ROLE)) LibOps.revertUnauthorized();
    }

    /**
     * @dev Validates that `startTime <= endTime`.
     * @param startTime  The start time of the mint.
     * @param endTime    The end time of the mint.
     */
    function _validateTimeRange(uint32 startTime, uint32 endTime) internal pure {
        if (startTime > endTime) revert InvalidTimeRange();
    }

    /**
     * @dev Validates that the max mintable amount per account is not zero.
     * @param value The max mintable amount.
     */
    function _validateMaxMintablePerAccount(uint32 value) internal pure {
        if (value == 0) revert MaxMintablePerAccountIsZero();
    }

    /**
     * @dev Validates that the max mintable per schedule.
     * @param value The max mintable amount.
     */
    function _validateMaxMintable(uint32 value) internal pure {
        if (value == 0) revert MaxMintableIsZero();
    }

    /**
     * @dev Validates that the Merkle root is not empty.
     * @param merkleRoot The Merkle root.
     */
    function _validateMerkleRoot(bytes32 merkleRoot) internal pure {
        if (merkleRoot == bytes32(0)) revert MerkleRootIsEmpty();
    }

    /**
     * @dev Validates that the signer is not the zero address.
     * @param signer The signer.
     */
    function _validateSigner(address signer) internal pure {
        if (signer == address(0)) revert SignerIsZeroAddress();
    }

    /**
     * @dev Validates that the affiliate fee BPS does not exceed the max threshold.
     * @param bps The affiliate fee BPS.
     */
    function _validateAffiliateFeeBPS(uint16 bps) internal pure {
        if (bps > MAX_AFFILIATE_FEE_BPS) revert InvalidAffiliateFeeBPS();
    }

    /**
     * @dev Validates the platform fee configuration.
     * @param c The platform fee configuration.
     */
    function _validatePlatformFeeConfig(PlatformFeeConfig memory c) internal pure {
        unchecked {
            uint256 incentiveSum;
            incentiveSum += uint256(c.affiliateIncentive);
            incentiveSum += uint256(c.cheapMintIncentive);
            if (
                LibOps.or(
                    c.perTxFlat > MAX_PLATFORM_PER_TX_FLAT_FEE,
                    c.perMintFlat > MAX_PLATFORM_PER_MINT_FLAT_FEE,
                    c.perMintBPS > MAX_PLATFORM_PER_MINT_FEE_BPS,
                    incentiveSum > c.perMintFlat
                )
            ) revert InvalidPlatformFeeConfig();
        }
    }

    /**
     * @dev Validates that the platform fee address is not the zero address.
     * @param a The platform fee address.
     */
    function _validatePlatformFeeAddress(address a) internal pure {
        if (a == address(0)) revert PlatformFeeAddressIsZero();
    }

    // EIP-712:
    // --------

    /**
     * @dev Override for EIP-712.
     * @return name_    The EIP-712 name.
     * @return version_ The EIP-712 version.
     */
    function _domainNameAndVersion()
        internal
        pure
        virtual
        override
        returns (string memory name_, string memory version_)
    {
        name_ = "SuperMinter";
        version_ = "1_1";
    }

    // Minting:
    // --------

    /**
     * @dev Increments the number minted in the mint and the number minted by the collector.
     * @param mode The mint mode.
     * @param d    The mint data storage pointer.
     * @param p    The mint-to parameters.
     */
    function _incrementMinted(
        uint8 mode,
        MintData storage d,
        MintTo calldata p
    ) internal {
        unchecked {
            // Increment the number minted in the mint.
            uint256 n = uint256(d.minted) + uint256(p.quantity); // The next `minted`.
            if (n > d.maxMintable) revert ExceedsMintSupply();
            d.minted = uint32(n);

            // Increment the number minted by the collector.
            uint256 mintId = LibOps.packId(p.edition, p.tier, p.scheduleNum);
            if (mode == VERIFY_MERKLE) {
                LibMap.Uint32Map storage m = _numberMinted[p.allowlisted];
                n = uint256(m.get(mintId)) + uint256(p.quantity);
                // Check that `n` does not exceed either the default limit,
                // or the limit in the Merkle leaf if a non-zero value is provided.
                if (LibOps.or(n > d.maxMintablePerAccount, n > p.allowlistedQuantity)) revert ExceedsMaxPerAccount();
                m.set(mintId, uint32(n));
            } else {
                LibMap.Uint32Map storage m = _numberMinted[p.to];
                n = uint256(m.get(mintId)) + uint256(p.quantity);
                if (n > d.maxMintablePerAccount) revert ExceedsMaxPerAccount();
                m.set(mintId, uint32(n));
            }
        }
    }

    /**
     * @dev Verify the signature, and mark the signed claim ticket as claimed.
     * @param d The mint data storage pointer.
     * @param p The mint-to parameters.
     */
    function _verifyAndClaimSignature(MintData storage d, MintTo calldata p) internal {
        if (p.quantity > p.signedQuantity) revert ExceedsSignedQuantity();
        address signer = _effectiveSigner(d);
        if (!SignatureCheckerLib.isValidSignatureNowCalldata(signer, computeMintToDigest(p), p.signature))
            revert InvalidSignature();
        if (block.timestamp > p.signedDeadline) revert SignatureExpired();
        uint256 mintId = LibOps.packId(p.edition, p.tier, p.scheduleNum);
        if (!_claimsBitmaps[mintId].toggle(p.signedClaimTicket)) revert SignatureAlreadyUsed();
    }

    /**
     * @dev Verify the Merkle proof.
     * @param d The mint data storage pointer.
     * @param p The mint-to parameters.
     */
    function _verifyMerkle(MintData storage d, MintTo calldata p) internal view {
        uint32 allowlistedQuantity = p.allowlistedQuantity;
        address allowlisted = p.allowlisted;
        // Revert if `allowlisted` is the zero address to prevent libraries
        // that fill up partial Merkle trees with empty leafs from screwing things up.
        if (allowlisted == address(0)) revert InvalidMerkleProof();
        // If `allowlistedQuantity` is the max limit, we've got to check two cases for backwards compatibility.
        if (allowlistedQuantity == type(uint32).max) {
            // Revert if neither `keccak256(abi.encodePacked(allowlisted))` nor
            // `keccak256(abi.encodePacked(allowlisted, uint32(0)))` are in the Merkle tree.
            if (
                !p.allowlistProof.verifyCalldata(d.merkleRoot, _leaf(allowlisted)) &&
                !p.allowlistProof.verifyCalldata(d.merkleRoot, _leaf(allowlisted, type(uint32).max))
            ) revert InvalidMerkleProof();
        } else {
            // Revert if `keccak256(abi.encodePacked(allowlisted, uint32(allowlistedQuantity)))`
            // is not in the Merkle tree.
            if (!p.allowlistProof.verifyCalldata(d.merkleRoot, _leaf(allowlisted, allowlistedQuantity)))
                revert InvalidMerkleProof();
        }
        // To mint, either the sender or `to` must be equal to `allowlisted`,
        address sender = LibMulticaller.senderOrSigner();
        if (!LibOps.or(sender == allowlisted, p.to == allowlisted)) {
            // or the sender must be a delegate of `allowlisted`.
            if (!DelegateCashLib.checkDelegateForAll(sender, allowlisted)) revert CallerNotDelegated();
        }
    }

    /**
     * @dev Returns the total price and fees for the mint.
     * @param tier        The tier.
     * @param d           The mint data storage pointer.
     * @param quantity    How many tokens to mint.
     * @param signedPrice The signed price. Only for `VERIFY_SIGNATURE`.
     * @return f A struct containing the total price and fees.
     */
    function _totalPriceAndFees(
        uint8 tier,
        MintData storage d,
        uint32 quantity,
        uint96 signedPrice
    ) internal view returns (TotalPriceAndFees memory f) {
        // All flat prices are stored as uint96s in storage.
        // The quantity is a uint32. Multiplications between a uint96 and uint32 won't overflow.
        unchecked {
            PlatformFeeConfig memory c = effectivePlatformFeeConfig(d.platform, tier);
            // The actual unit price per token.
            uint256 unitPrice;
            // For signature mints, even if it is GA tier, we will use the signed price.
            if (d.mode == VERIFY_SIGNATURE) {
                if (signedPrice < d.price) revert SignedPriceTooLow(); // Enforce the price floor.
                unitPrice = signedPrice;
            } else if (tier == GA_TIER) {
                unitPrice = gaPrice[d.platform]; // Else if GA tier, use `gaPrice[platform]`.
            } else {
                unitPrice = d.price; // Else, use the `price`.
            }
            f.unitPrice = unitPrice;
            // The artist will receive the remaining after all BPS fees are deducted from sub total.
            // The minter will have to pay the sub total plus any flat fees.
            f.subTotal = unitPrice * uint256(quantity);
            assert(quantity == 0 || uint(f.subTotal) / uint(quantity) == uint(unitPrice));
            // Sum the total flat fees for mints, and the transaction flat fee.
            f.platformTxFlatFee = c.perTxFlat;
            f.platformMintFlatFee = c.perMintFlat * uint256(quantity);
            assert(quantity == 0 || uint(f.platformMintFlatFee) / uint(quantity) == uint(c.perMintFlat));
            f.platformFlatFee = f.platformMintFlatFee + f.platformTxFlatFee;
            assert(uint(f.platformFlatFee) >= uint(f.platformMintFlatFee));
            // BPS fees are to be deducted from the sub total.
            f.platformMintBPSFee = LibOps.rawMulDiv(f.subTotal, c.perMintBPS, BPS_DENOMINATOR);
            // The platform fee includes BPS fees deducted from sub total,
            // and flat fees added to sub total.
            f.platformFee = f.platformMintBPSFee + f.platformFlatFee;
            assert(uint(f.platformFee) >= uint(f.platformMintBPSFee));
            // Affiliate fee is to be deducted from the sub total.
            // Will be conditionally set to zero during mint if not affiliated.
            f.affiliateFee = LibOps.rawMulDiv(f.subTotal, d.affiliateFeeBPS, BPS_DENOMINATOR);
            // Calculate the incentives. These may be redirected away from the `platformFee`.
            f.affiliateIncentive = c.affiliateIncentive * uint256(quantity);
            f.cheapMintIncentive = c.cheapMintIncentive * uint256(quantity);
            assert(quantity == 0 || uint(f.affiliateIncentive) / uint(quantity) == uint(c.affiliateIncentive));
            assert(quantity == 0 || uint(f.cheapMintIncentive) / uint(quantity) == uint(c.cheapMintIncentive));
            f.cheapMintIncentiveThreshold = c.cheapMintIncentiveThreshold;
            // The total is the final value which the minter has to pay. It includes all fees.
            f.total = f.subTotal + f.platformFlatFee;
            assert(uint(f.total) >= uint(f.subTotal));
        }
    }

    /**
     * @dev Returns whether the affiliate is affiliated for the mint
     * @param d              The mint data storage pointer.
     * @param affiliate      The affiliate address.
     * @param affiliateProof The Merkle proof for the affiliate.
     * @return The result.
     */
    function _isAffiliatedWithProof(
        MintData storage d,
        address affiliate,
        bytes32[] calldata affiliateProof
    ) internal view virtual returns (bool) {
        bytes32 root = d.affiliateMerkleRoot;
        // If the root is empty, then use the default logic.
        if (root == bytes32(0)) return affiliate != address(0);
        // Otherwise, check if the affiliate is in the Merkle tree.
        // The check that that affiliate is not a zero address is to prevent libraries
        // that fill up partial Merkle trees with empty leafs from screwing things up.
        return LibOps.and(affiliate != address(0), affiliateProof.verifyCalldata(root, _leaf(affiliate)));
    }

    // Utilities:
    // ----------

    /**
     * @dev Equivalent to `keccak256(abi.encodePacked(allowlisted))`.
     * @param allowlisted The allowlisted address.
     * @return result The leaf in the Merkle tree.
     */
    function _leaf(address allowlisted) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x00, allowlisted)
            result := keccak256(0x0c, 0x14)
        }
    }

    /**
     * @dev Equivalent to `keccak256(abi.encodePacked(allowlisted, allowlistedQuantity))`.
     * @param allowlisted         The allowlisted address.
     * @param allowlistedQuantity Number of mints allowlisted.
     * @return result The leaf in the Merkle tree.
     */
    function _leaf(address allowlisted, uint32 allowlistedQuantity) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x04, allowlistedQuantity)
            mstore(0x00, allowlisted)
            result := keccak256(0x0c, 0x18)
        }
    }

    /**
     * @dev Retrieves the mint data from storage, reverting if the mint does not exist.
     * @param mintId The mint ID.
     * @return d The storage pointer to the mint data.
     */
    function _getMintData(uint256 mintId) internal view returns (MintData storage d) {
        d = _mintData[mintId];
        if (d.flags & _MINT_CREATED_FLAG == 0) revert MintDoesNotExist();
    }

    /**
     * @dev Returns whether the mint is paused.
     * @param d The storage pointer to the mint data.
     * @return Whether the mint is paused.
     */
    function _isPaused(MintData storage d) internal view returns (bool) {
        return d.flags & _MINT_PAUSED_FLAG != 0;
    }

    /**
     * @dev Returns the effective signer.
     * @param d The storage pointer to the mint data.
     * @return The effective signer.
     */
    function _effectiveSigner(MintData storage d) internal view returns (address) {
        return _usePlatformSigner(d) ? platformSigner[d.platform] : d.signer;
    }

    /**
     * @dev Returns whether the platform signer is to be used instead.
     * @param d The storage pointer to the mint data.
     * @return Whether the platform signer is to be used instead.
     */
    function _usePlatformSigner(MintData storage d) internal view returns (bool) {
        return d.flags & _USE_PLATFORM_SIGNER_FLAG != 0;
    }
}
