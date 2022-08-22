// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { IAccessControlUpgradeable } from "openzeppelin-upgradeable/access/IAccessControlUpgradeable.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/**
 * @title Minter Base
 * @dev The `BaseMinter` class maintains a central storage record of edition mint configurations.
 */
abstract contract BaseMinter is IERC165, IMinterModule, Ownable {
    // ================================
    // STRUCTS
    // ================================

    struct BaseData {
        uint32 startTime;
        uint32 endTime;
        uint32 affiliateFeeBPS;
        uint32 affiliateDiscountBPS;
        bool mintPaused;
    }

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
     * @dev Maps an edition to the its next mint ID.
     */
    mapping(address => uint256) private _nextMintIds;

    /**
     * @dev Maps an edition and the mint ID to a mint's configuration.
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

    /**
     * @dev The numerator of the platform fee.
     */
    uint16 private _platformFeeBPS;

    // ================================
    // ACCESS MODIFIERS
    // ================================

    /**
     * @dev Restricts the function to be only callable by the owner or admin of `edition`.
     */
    modifier onlyEditionOwnerOrAdmin(address edition) virtual {
        if (
            !_callerIsEditionOwner(edition) &&
            !IAccessControlUpgradeable(edition).hasRole(ISoundEditionV1(edition).ADMIN_ROLE(), msg.sender)
        ) revert Unauthorized();

        _;
    }

    // ================================
    // WRITE FUNCTIONS
    // ================================

    /**
     * @inheritdoc IMinterModule
     */
    function setEditionMintPaused(
        address edition,
        uint256 mintId,
        bool paused
    ) public virtual onlyEditionOwnerOrAdmin(edition) {
        _baseData[edition][mintId].mintPaused = paused;
        emit MintPausedSet(edition, mintId, paused);
    }

    /**
     * @inheritdoc IMinterModule
     */
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
    function setPlatformFee(uint16 feeBPS) public virtual override onlyOwner onlyValidPlatformFeeBPS(feeBPS) {
        _platformFeeBPS = feeBPS;
        emit PlatformFeeSet(feeBPS);
    }

    /**
     * @inheritdoc IMinterModule
     */
    function withdrawForAffiliate(address affiliate) public override {
        uint256 accrued = _affiliateFeesAccrued[affiliate];
        _affiliateFeesAccrued[affiliate] = 0;
        if (accrued != 0) {
            SafeTransferLib.safeTransferETH(affiliate, accrued);
        }
    }

    /**
     * @inheritdoc IMinterModule
     */
    function withdrawForPlatform(address to) public override onlyOwner {
        uint256 accrued = _platformFeesAccrued;
        if (accrued != 0) {
            _platformFeesAccrued = 0;
            SafeTransferLib.safeTransferETH(to, accrued);
        }
    }

    // ================================
    // VIEW FUNCTIONS
    // ================================

    /**
     * @inheritdoc IMinterModule
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
    function platformFeeBPS() external view returns (uint16) {
        return _platformFeeBPS;
    }

    /**
     * @inheritdoc IMinterModule
     */
    function isAffiliated(
        address,
        uint256,
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
        address,
        uint32 quantity,
        bool affiliated
    ) public view virtual override returns (uint256) {
        uint256 price = _price(edition, mintId);

        if (price == 0) return 0;

        uint256 total = quantity * price;

        if (!affiliated) return total;

        return total - ((total * _baseData[edition][mintId].affiliateDiscountBPS) / _MAX_BPS);
    }

    /**
     * @inheritdoc IMinterModule
     */
    function nextMintId(address edition) public view returns (uint256) {
        return _nextMintIds[edition];
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IMinterModule).interfaceId;
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

    /**
     * @dev Restricts the platform fee numerator to not excced the `MAX_BPS`.
     */
    modifier onlyValidPlatformFeeBPS(uint16 platformFeeBPS_) virtual {
        if (platformFeeBPS_ > _MAX_BPS) revert InvalidPlatformFeeBPS();
        _;
    }

    // ================================
    // INTERNAL FUNCTIONS
    // ================================

    /**
     * @dev Returns the unit price. Intended to be overridden by child contracts.
     */
    function _price(address edition, uint256 mintId) internal view virtual returns (uint256);

    /**
     * @dev Creates an edition mint configuration.
     * Calling conditions:
     * - Must be owner or admin of the edition.
     */
    function _createEditionMint(
        address edition,
        uint32 startTime,
        uint32 endTime
    ) internal onlyValidTimeRange(startTime, endTime) onlyEditionOwnerOrAdmin(edition) returns (uint256 mintId) {
        mintId = _nextMintIds[edition];

        BaseData storage data = _baseData[edition][mintId];
        data.startTime = startTime;
        data.endTime = endTime;

        _nextMintIds[edition] += 1;

        emit MintConfigCreated(edition, msg.sender, mintId, startTime, endTime);
    }

    /**
     * @dev Returns whether the caller is the owner of `edition`.
     */
    function _callerIsEditionOwner(address edition) private returns (bool result) {
        // To avoid defining an interface just to call `owner()`.
        // And Solidity does not have try catch for plain old `call`.
        assembly {
            // Store the 4-byte function selector of `owner()` into scratch space.
            mstore(0x00, 0x8da5cb5b)
            // The `call` must be placed as the last argument of `and`,
            // as the arguments are evaluated right to left.
            result := and(
                and(
                    // Whether the returned address equals `msg.sender`.
                    eq(mload(0x00), caller()),
                    // Whether at least a word has been returned.
                    gt(returndatasize(), 31)
                ),
                call(
                    gas(), // Remaining gas.
                    edition, // The `edition` address.
                    0, // Send 0 Ether.
                    0x1c, // Offset of the selector in the memory.
                    0x04, // Size of the selector (4 bytes).
                    0x00, // Offset of the return data.
                    0x20 // Size of the return data (1 32-byte word).
                )
            )
        }
    }

    /**
     * @dev Sets the time range for an edition mint.
     * Note: If calling from a child contract, the child is responsible for access control.
     */
    function _setTimeRange(
        address edition,
        uint256 mintId,
        uint32 startTime,
        uint32 endTime
    ) internal onlyValidTimeRange(startTime, endTime) {
        _beforeSetTimeRange(edition, mintId, startTime, endTime);

        _baseData[edition][mintId].startTime = startTime;
        _baseData[edition][mintId].endTime = endTime;

        emit TimeRangeSet(edition, mintId, startTime, endTime);
    }

    /**
     * @dev Called at the start of _setTimeRange (for optional validation checks, etc).
     */
    function _beforeSetTimeRange(
        address edition,
        uint256 mintId,
        uint32 startTime,
        uint32 endTime
    ) internal virtual {}

    /**
     * @dev Mints `quantity` of `edition` to `to` with a required payment of `requiredEtherValue`.
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

        // Check if the mint is an affliated mint.
        bool affiliated = isAffiliated(edition, mintId, affiliate);

        uint256 requiredEtherValue = totalPrice(edition, mintId, msg.sender, quantity, affiliated);

        // Reverts if the payment is not exact.
        if (msg.value != requiredEtherValue) revert WrongEtherValue(msg.value, requiredEtherValue);

        uint256 remainingPayment = requiredEtherValue;

        // Compute the platform fee.
        uint256 platformFee = (remainingPayment * _platformFeeBPS) / _MAX_BPS;
        // Deduct the platform fee.
        remainingPayment -= platformFee;

        // Increment the platform fees accrued.
        _platformFeesAccrued += platformFee;

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

    /**
     * @dev Requires that `totalMinted <= maxMintable`.
     */
    function _requireNotSoldOut(uint32 totalMinted, uint32 maxMintable) internal pure {
        if (totalMinted > maxMintable) revert MaxMintableReached(maxMintable);
    }
}
