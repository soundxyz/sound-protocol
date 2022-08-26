// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/**
 * @title Minter Base
 * @dev The `BaseMinter` class maintains a central storage record of edition mint instances.
 */
abstract contract BaseMinter is IMinterModule {
    // ================================
    // CONSTANTS
    // ================================

    /**
     * @dev This is the denominator, in basis points (BPS), for:
     * - platform fees
     * - affiliate fees
     * - affiliate discount
     */
    uint16 private constant _MAX_BPS = 10_000;

    // ================================
    // STORAGE
    // ================================

    /**
     * @dev The next mint ID. Shared amongst all editions connected.
     */
    uint256 private _nextMintId;

    /**
     * @dev Maps an edition and the mint ID to a mint instance.
     */
    mapping(address => mapping(uint256 => BaseData)) private _baseData;

    /**
     * @dev Maps an address to how much affiliate fees have they accrued.
     */
    mapping(address => uint256) private _affiliateFeesAccrued;

    /**
     * @dev How much platform fees have been accrued.
     */
    uint256 private _platformFeesAccrued;

    ISoundFeeRegistry public immutable feeRegistry;

    // ================================
    // ACCESS MODIFIERS
    // ================================

    /**
     * @dev Restricts the function to be only callable by the owner or admin of `edition`.
     * @param edition The edition address.
     */
    modifier onlyEditionOwnerOrAdmin(address edition) virtual {
        if (
            msg.sender != OwnableRoles(edition).owner() &&
            !OwnableRoles(edition).hasAnyRole(msg.sender, ISoundEditionV1(edition).ADMIN_ROLE())
        ) revert Unauthorized();

        _;
    }

    // ================================
    // WRITE FUNCTIONS
    // ================================

    constructor(ISoundFeeRegistry feeRegistry_) {
        if (address(feeRegistry_) == address(0)) revert FeeRegistryIsZeroAddress();
        feeRegistry = feeRegistry_;
    }

    /// @inheritdoc IMinterModule
    function setEditionMintPaused(
        address edition,
        uint256 mintId,
        bool paused
    ) public virtual onlyEditionOwnerOrAdmin(edition) {
        _baseData[edition][mintId].mintPaused = paused;
        emit MintPausedSet(edition, mintId, paused);
    }

    /// @inheritdoc IMinterModule
    function setTimeRange(
        address edition,
        uint256 mintId,
        uint32 startTime,
        uint32 endTime
    ) public virtual onlyEditionOwnerOrAdmin(edition) {
        _setTimeRange(edition, mintId, startTime, endTime);
    }

    /**
     * @inheritdoc IMinterModule
     */
    function setAffiliateFee(
        address edition,
        uint256 mintId,
        uint16 feeBPS
    ) public virtual override onlyEditionOwnerOrAdmin(edition) onlyValidAffiliateFeeBPS(feeBPS) {
        _baseData[edition][mintId].affiliateFeeBPS = feeBPS;
        emit AffiliateFeeSet(edition, mintId, feeBPS);
    }

    /**
     * @inheritdoc IMinterModule
     */
    function setAffiliateDiscount(
        address edition,
        uint256 mintId,
        uint16 discountBPS
    ) public virtual override onlyEditionOwnerOrAdmin(edition) onlyValidAffiliateDiscountBPS(discountBPS) {
        _baseData[edition][mintId].affiliateDiscountBPS = discountBPS;
        emit AffiliateDiscountSet(edition, mintId, discountBPS);
    }

    /**
     * @inheritdoc IMinterModule
     */
    function withdrawForAffiliate(address affiliate) public override {
        uint256 accrued = _affiliateFeesAccrued[affiliate];
        if (accrued != 0) {
            _affiliateFeesAccrued[affiliate] = 0;
            SafeTransferLib.safeTransferETH(affiliate, accrued);
        }
    }

    /**
     * @inheritdoc IMinterModule
     */
    function withdrawForPlatform() public override {
        uint256 accrued = _platformFeesAccrued;
        if (accrued != 0) {
            _platformFeesAccrued = 0;
            SafeTransferLib.safeTransferETH(feeRegistry.soundFeeAddress(), accrued);
        }
    }

    // ================================
    // VIEW FUNCTIONS
    // ================================

    /**
     * @dev Getter for the max basis points.
     */
    function MAX_BPS() external pure returns (uint16) {
        return _MAX_BPS;
    }

    /**
     * @inheritdoc IMinterModule
     */
    function affiliateFeesAccrued(address affiliate) external view returns (uint256) {
        return _affiliateFeesAccrued[affiliate];
    }

    /**
     * @inheritdoc IMinterModule
     */
    function platformFeesAccrued() external view returns (uint256) {
        return _platformFeesAccrued;
    }

    /**
     * @inheritdoc IMinterModule
     */
    function isAffiliated(
        address, /* edition */
        uint256, /* mintId */
        address affiliate
    ) public view virtual override returns (bool) {
        return affiliate != address(0);
    }

    /**
     * @inheritdoc IMinterModule
     */
    function totalPrice(
        address edition,
        uint256 mintId,
        address minter,
        uint32 quantity,
        bool affiliated
    ) public view virtual override returns (uint256) {
        uint256 total = _baseTotalPrice(edition, mintId, minter, quantity);

        if (total == 0) return 0;

        if (!affiliated) return total;

        return total - ((total * _baseData[edition][mintId].affiliateDiscountBPS) / _MAX_BPS);
    }

    /**
     * @inheritdoc IMinterModule
     */
    function nextMintId() public view returns (uint256) {
        return _nextMintId;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IMinterModule).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /**
     * @dev Returns the base mint data.
     */
    function baseMintData(address edition, uint256 mintId) public view returns (BaseData memory) {
        return _baseData[edition][mintId];
    }

    // ================================
    // VALIDATION MODIFIERS
    // ================================

    /**
     * @dev Restricts the start time to be less than the end time.
     * @param startTime The start time of the mint.
     * @param endTime The end time of the mint.
     */
    modifier onlyValidTimeRange(uint32 startTime, uint32 endTime) virtual {
        if (startTime >= endTime) revert InvalidTimeRange();
        _;
    }

    /**
     * @dev Restricts the affiliate fee numerator to not excced the `MAX_BPS`.
     */
    modifier onlyValidAffiliateFeeBPS(uint16 affiliateFeeBPS) virtual {
        if (affiliateFeeBPS > _MAX_BPS) revert InvalidAffiliateFeeBPS();
        _;
    }

    /**
     * @dev Restricts the affiliate fee numerator to not excced the `MAX_BPS`.
     */
    modifier onlyValidAffiliateDiscountBPS(uint16 affiliateDiscountBPS) virtual {
        if (affiliateDiscountBPS > _MAX_BPS) revert InvalidAffiliateDiscountBPS();
        _;
    }

    // ================================
    // INTERNAL FUNCTIONS
    // ================================

    /**
     * @dev Returns the total price before any affiliate discount.
     * This is a mandatory hook to override.
     */
    function _baseTotalPrice(
        address edition,
        uint256 mintId,
        address minter,
        uint32 quantity
    ) internal view virtual returns (uint256);

    /**
     * @dev Creates an edition mint instance.
     * @param edition The edition address.
     * @param startTime The start time of the mint.
     * @param endTime The end time of the mint.
     * @return mintId The ID for the mint instance.
     * Calling conditions:
     * - Must be owner or admin of the edition.
     */
    function _createEditionMint(
        address edition,
        uint32 startTime,
        uint32 endTime
    ) internal onlyValidTimeRange(startTime, endTime) onlyEditionOwnerOrAdmin(edition) returns (uint256 mintId) {
        mintId = _nextMintId;

        BaseData storage data = _baseData[edition][mintId];
        data.startTime = startTime;
        data.endTime = endTime;

        _nextMintId = mintId + 1;

        emit MintConfigCreated(edition, msg.sender, mintId, startTime, endTime);
    }

    /**
     * @dev Sets the time range for an edition mint.
     * Note: If calling from a child contract, the child is responsible for access control.
     * @param edition The edition address.
     * @param mintId The ID for the mint instance.
     * @param startTime The start time of the mint.
     * @param endTime The end time of the mint.
     */
    function _setTimeRange(
        address edition,
        uint256 mintId,
        uint32 startTime,
        uint32 endTime
    ) internal onlyValidTimeRange(startTime, endTime) {
        _baseData[edition][mintId].startTime = startTime;
        _baseData[edition][mintId].endTime = endTime;

        emit TimeRangeSet(edition, mintId, startTime, endTime);
    }

    /**
     * @dev Mints `quantity` of `edition` to `to` with a required payment of `requiredEtherValue`.
     * @param edition The edition address.
     * @param mintId The ID for the mint instance.
     * @param quantity The quantity of tokens to mint.
     * @param affiliate The affiliate (referral) address.
     */
    function _mint(
        address edition,
        uint256 mintId,
        uint32 quantity,
        address affiliate
    ) internal {
        BaseData storage baseData = _baseData[edition][mintId];

        /* --------------------- GENERAL CHECKS --------------------- */

        uint32 startTime = baseData.startTime;
        uint32 endTime = baseData.endTime;
        if (block.timestamp < startTime) revert MintNotOpen(block.timestamp, startTime, endTime);
        if (block.timestamp > endTime) revert MintNotOpen(block.timestamp, startTime, endTime);
        if (baseData.mintPaused) revert MintPaused();

        /* ----------- AFFILIATE AND PLATFORM FEES LOGIC ------------ */

        // Check if the mint is an affiliated mint.
        bool affiliated = isAffiliated(edition, mintId, affiliate);

        uint256 requiredEtherValue = totalPrice(edition, mintId, msg.sender, quantity, affiliated);

        // Reverts if the payment is not exact.
        if (msg.value != requiredEtherValue) revert WrongEtherValue(msg.value, requiredEtherValue);

        uint256 remainingPayment = _deductPlatformFee(requiredEtherValue);

        if (affiliated) {
            // Compute the affiliate fee.
            uint256 affiliateFee = (remainingPayment * baseData.affiliateFeeBPS) / _MAX_BPS;
            // Deduct the affiliate fee from the remaining payment.
            remainingPayment -= affiliateFee;
            // Increment the affiliate fees accrued
            _affiliateFeesAccrued[affiliate] += affiliateFee;
        }

        /* ------------------------- MINT --------------------------- */

        ISoundEditionV1(edition).mint{ value: remainingPayment }(msg.sender, quantity);
    }

    function _deductPlatformFee(uint256 requiredEtherValue) internal returns (uint256 remainingPayment) {
        // Compute the platform fee.
        uint256 platformFee = (requiredEtherValue * feeRegistry.platformFeeBPS()) / _MAX_BPS;
        // Increment the platform fees accrued.
        _platformFeesAccrued += platformFee;
        // Deduct the platform fee.
        remainingPayment = requiredEtherValue - platformFee;
    }

    /**
     * @dev Throws error if `totalMinted > maxMintable`.
     * @param totalMinted The current total number of minted tokens.
     * @param maxMintable The maximum number of mintable tokens.
     */
    function _requireNotSoldOut(uint32 totalMinted, uint32 maxMintable) internal pure {
        if (totalMinted > maxMintable) revert MaxMintableReached(maxMintable);
    }
}
