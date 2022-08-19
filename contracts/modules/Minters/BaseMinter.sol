// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../interfaces/IBaseMinter.sol";
import "../../interfaces/ISoundEditionV1.sol";
import "openzeppelin-upgradeable/access/IAccessControlUpgradeable.sol";
import "openzeppelin/utils/introspection/IERC165.sol";
import "openzeppelin/access/Ownable.sol";
import "solady/utils/SafeTransferLib.sol";

/**
 * @title Minter Base
 * @dev The `BaseMinter` class maintains a central storage record of edition mint configurations.
 */
abstract contract BaseMinter is IERC165, IBaseMinter, Ownable {
    // ================================
    // CUSTOM ERRORS
    // ================================

    /**
     * The Ether value paid is not the exact value required.
     */
    error WrongEtherValue(uint256 paid, uint256 required);

    /**
     * The number minted has exceeded the max mintable amount.
     */
    error MaxMintableReached(uint32 maxMintable);

    /**
     * The mint is not opened.
     */
    error MintNotOpen(uint256 blockTimestamp, uint32 startTime, uint32 endTime);

    /**
     * The mint is paused.
     */
    error MintPaused();

    /**
     * The `startTime` is not less than the `endTime`.
     */
    error InvalidTimeRange();

    /**
     * Unauthorized caller
     */
    error Unauthorized();

    /**
     * The affiliate fee numerator must not exceed `MAX_BPS`.
     */
    error InvalidAffiliateFeeBPS();

    /**
     * The affiliate discount numerator must not exceed `MAX_BPS`.
     */
    error InvalidAffiliateDiscountBPS();

    /**
     * The platform fee numerator must not exceed `MAX_BPS`.
     */
    error InvalidPlatformFeeBPS();

    // ================================
    // EVENTS
    // ================================

    /**
     * @notice Emitted when the mint configuration for an `edition` is created.
     */
    event MintConfigCreated(
        address indexed edition,
        address indexed creator,
        uint256 mintId,
        uint32 startTime,
        uint32 endTime
    );

    /**
     * @notice Emitted when the `paused` status of `edition` is updated.
     */
    event MintPausedSet(address indexed edition, uint256 mintId, bool paused);

    /**
     * @notice Emitted when the `startTime` and `endTime` are updated.
     */
    event TimeRangeSet(address indexed edition, uint256 indexed mintId, uint32 startTime, uint32 endTime);

    /**
     * @notice Emitted when the `affiliateFeeBPS` is updated.
     */
    event AffiliateFeeSet(address indexed edition, uint256 indexed mintId, uint16 affiliateFeeBPS);

    /**
     * @notice Emitted when the `affiliateDiscountBPS` is updated.
     */
    event AffiliateDiscountSet(address indexed edition, uint256 indexed mintId, uint16 affiliateDiscountBPS);

    /**
     * @notice Emitted when the `platformFeeBPS` is changed.
     */
    event PlatformFeeSet(uint16 platformFeeBPS);

    // ================================
    // CONSTANTS
    // ================================

    /**
     * @dev This is the denominator, in basis points (BPS), for:
     * - platform fees
     * - affiliate fees
     * - affiliate discount
     */
    uint16 public constant MAX_BPS = 10_000;

    // ================================
    // STRUCTS
    // ================================

    struct BaseData {
        uint32 startTime;
        uint32 endTime;
        uint16 affiliateFeeBPS;
        uint16 affiliateDiscountBPS;
        bool mintPaused;
    }

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
    mapping(address => uint256) public affiliateFeesAccrued;

    /**
     * @dev How much platform fees have been accrued.
     */
    uint256 public platformFeesAccrued;

    /**
     * @dev The numerator of the platform fee.
     */
    uint16 public platformFeeBPS;

    // ================================
    // WRITE FUNCTIONS
    // ================================

    /**
     * @dev Sets the `paused` status for `edition`.
     * Calling conditions:
     * - The caller must be the edition's owner or an admin.
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
     * @dev Sets the time range for an edition mint.
     * Calling conditions:
     * - The caller must be the edition's owner or an admin.
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
     * @dev Sets the `affiliateFeeBPS` for (`edition`, `mintId`).
     * Calling conditions:
     * - The caller must be the current controller for (`edition`, `mintId`).
     */
    function setAffiliateFee(
        address edition,
        uint256 mintId,
        uint16 affiliateFeeBPS
    ) public virtual onlyEditionOwnerOrAdmin(edition) onlyValidAffiliateFeeBPS(affiliateFeeBPS) {
        _baseData[edition][mintId].affiliateFeeBPS = affiliateFeeBPS;
        emit AffiliateFeeSet(edition, mintId, affiliateFeeBPS);
    }

    /**
     * @dev Sets the `affiliateDiscountBPS` for (`edition`, `mintId`).
     * Calling conditions:
     * - The caller must be the current controller for (`edition`, `mintId`).
     */
    function setAffiliateDiscount(
        address edition,
        uint256 mintId,
        uint16 affiliateDiscountBPS
    ) public virtual onlyEditionOwnerOrAdmin(edition) onlyValidAffiliateDiscountBPS(affiliateDiscountBPS) {
        _baseData[edition][mintId].affiliateDiscountBPS = affiliateDiscountBPS;
        emit AffiliateDiscountSet(edition, mintId, affiliateDiscountBPS);
    }

    /**
     * @dev Sets the `platformFeeBPS`.
     * Calling conditions:
     * - The caller must be the owner of the contract.
     */
    function setPlatformFee(uint16 platformFeeBPS_) public virtual onlyOwner onlyValidPlatformFeeBPS(platformFeeBPS_) {
        platformFeeBPS = platformFeeBPS_;
        emit PlatformFeeSet(platformFeeBPS_);
    }

    /**
     * @dev Withdraws all the accrued funds for the `affiliate`.
     */
    function withdrawForAffiliate(address affiliate) public {
        uint256 accrued = affiliateFeesAccrued[affiliate];
        affiliateFeesAccrued[affiliate] = 0;
        if (accrued != 0) {
            SafeTransferLib.safeTransferETH(affiliate, accrued);
        }
    }

    /**
     * @dev Withdraws all the accrued funds for the platform.
     */
    function withdrawForPlatform(address to) public onlyOwner {
        uint256 accrued = platformFeesAccrued;
        platformFeesAccrued = 0;
        if (accrued != 0) {
            SafeTransferLib.safeTransferETH(to, accrued);
        }
    }

    // ================================
    // INTERNAL FUNCTIONS
    // ================================

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
     * @dev Mints `quantity` of `edition` to with a required payment of `requiredEtherValue`.
     */
    function _mint(
        address edition,
        uint256 mintId,
        uint32 quantity,
        uint256 requiredEtherValue,
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
        bool isAffiliatedMint = isAffiliated(edition, mintId, affiliate);

        // If it is, apply the affiliated discount.
        if (isAffiliatedMint) {
            requiredEtherValue = affiliatedPrice(edition, mintId, requiredEtherValue, affiliate);
        }

        // Reverts if the payment is not exact.
        // For affiliated mints, the client should compute the discounted price via
        // `affiliatedPrice(edition, mintId, requiredEtherValue, affiliate)`
        if (msg.value != requiredEtherValue) revert WrongEtherValue(msg.value, requiredEtherValue);

        // Compute the platform fee.
        uint256 platformFee = (requiredEtherValue * platformFeeBPS) / MAX_BPS;

        // Deduct the platform fee from the remaining payment.
        uint256 remainingPayment = requiredEtherValue - platformFee;

        // Increment the platform fees accrued.
        platformFeesAccrued += platformFee;

        if (isAffiliatedMint) {
            // Compute the affiliate fee.
            uint256 affiliateFee = (requiredEtherValue * baseData.affiliateFeeBPS) / MAX_BPS;
            // Deduct the affiliate fee from the remaining payment.
            remainingPayment -= affiliateFee;
            // Increment the affiliate fees accrued
            affiliateFeesAccrued[affiliate] += affiliateFee;
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

    // ================================
    // MODIFIERS
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
        if (affiliateFeeBPS > MAX_BPS) revert InvalidAffiliateFeeBPS();
        _;
    }

    /**
     * @dev Restricts the affiliate fee numerator to not excced the `MAX_BPS`.
     */
    modifier onlyValidAffiliateDiscountBPS(uint16 affiliateDiscountBPS) virtual {
        if (affiliateDiscountBPS > MAX_BPS) revert InvalidAffiliateDiscountBPS();
        _;
    }

    /**
     * @dev Restricts the platform fee numerator to not excced the `MAX_BPS`.
     */
    modifier onlyValidPlatformFeeBPS(uint16 platformFeeBPS_) virtual {
        if (platformFeeBPS_ > MAX_BPS) revert InvalidPlatformFeeBPS();
        _;
    }

    // ================================
    // VIEW FUNCTIONS
    // ================================

    /**
     * @dev Returns whether `affiliate` is a valid affiliate for (`edition`, `mintId`).
     * Child contracts may override this function to provide a custom logic.
     */
    function isAffiliated(
        address, /* edition */
        uint256, /* mintId */
        address affiliate
    ) public view virtual returns (bool) {
        return affiliate != address(0);
    }

    /**
     * @dev Returns the discounted price for affiliated purchases.
     */
    function affiliatedPrice(
        address edition,
        uint256 mintId,
        uint256 originalPrice,
        address /* affiliate */
    ) public view virtual returns (uint256) {
        return originalPrice - ((originalPrice * _baseData[edition][mintId].affiliateDiscountBPS) / MAX_BPS);
    }

    /**
     * @dev Returns the next mint ID for `edition`.
     */
    function nextMintId(address edition) public view returns (uint256) {
        return _nextMintIds[edition];
    }

    /**
     * @dev Returns the configuration data for an edition mint.
     */
    function baseMintData(address edition, uint256 mintId) public view returns (BaseData memory) {
        return _baseData[edition][mintId];
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IBaseMinter).interfaceId;
    }
}
