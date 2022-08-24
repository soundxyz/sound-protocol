// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";

/**
 * @title Interface for the base minter functionality, excluding the mint function.
 */
interface IMinterModule is IERC165 {
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
    event AffiliateFeeSet(address indexed edition, uint256 indexed mintId, uint16 feeBPS);

    /**
     * @notice Emitted when the `affiliateDiscountBPS` is updated.
     */
    event AffiliateDiscountSet(address indexed edition, uint256 indexed mintId, uint16 discountBPS);

    /**
     * @notice Emitted when the `platformFeeBPS` is changed.
     */
    event PlatformFeeSet(uint16 feeBPS);

    // ================================
    // ERRORS
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
    // WRITE FUNCTIONS
    // ================================

    /**
     * @dev Sets the paused status for (`edition`, `mintId`).
     * Calling conditions:
     * - The caller must be the edition's owner or an admin.
     */
    function setEditionMintPaused(
        address edition,
        uint256 mintId,
        bool paused
    ) external;

    /**
     * @dev Sets the time range for (`edition`, `mintId`).
     * Calling conditions:
     * - The caller must be the edition's owner or an admin.
     */
    function setTimeRange(
        address edition,
        uint256 mintId,
        uint32 startTime,
        uint32 endTime
    ) external;

    /**
     * @dev Sets the affiliate fee for (`edition`, `mintId`).
     * Calling conditions:
     * - The caller must be the edition's owner or an admin.
     */
    function setAffiliateFee(
        address edition,
        uint256 mintId,
        uint16 affiliateFeeBPS
    ) external;

    /**
     * @dev Sets the affiliate discount for (`edition`, `mintId`).
     * Calling conditions:
     * - The caller must be the edition's owner or an admin.
     */
    function setAffiliateDiscount(
        address edition,
        uint256 mintId,
        uint16 affiliateDiscountBPS
    ) external;

    /**
     * @dev Sets the platform fee.
     * Calling conditions:
     * - The caller must be owner of the contract.
     */
    function setPlatformFee(uint16 bps) external;

    /**
     * @dev Withdraws all the accrued fees for `affiliate`.
     */
    function withdrawForAffiliate(address affiliate) external;

    /**
     * @dev Withdraws all the accrued fees for the platform.
     * Calling conditions:
     * - The caller must be the the owner of the contract.
     */
    function withdrawForPlatform(address to) external;

    // ================================
    // VIEW FUNCTIONS
    // ================================

    /**
     * @dev Returns the maximum basis points (BPS).
     */
    function MAX_BPS() external pure returns (uint16);

    /**
     * @dev Returns the total fees accrued for `affiliate`.
     */
    function affiliateFeesAccrued(address affiliate) external view returns (uint256);

    /**
     * @dev Returns the total fees accrued for the platform.
     */
    function platformFeesAccrued() external view returns (uint256);

    /**
     * @dev Returns the number of basis points for the platform fees.
     */
    function platformFeeBPS() external view returns (uint16);

    /**
     * @dev Returns whether `affiliate` is affiliated for (`edition`, `mintId`).
     */
    function isAffiliated(
        address edition,
        uint256 mintId,
        address affiliate
    ) external view returns (bool);

    /**
     * @dev Returns the total price for `quantity` tokens for (`edition`, `mintId`).
     */
    function totalPrice(
        address edition,
        uint256 mintId,
        address minter,
        uint32 quantity,
        uint256 price_,
        bool affiliated
    ) external view returns (uint256);

    /**
     * @dev Returns the next mint ID for `edition`.
     * A mint ID is assigned sequentially for each unique edition address,
     * starting from (0, 1, 2, ...)
     */
    function nextMintId(address edition) external view returns (uint256);

    /**
     * @dev Returns the total number of tokens that can be minted for (`edition`, `mintId`).
     */
    function maxMintable(address edition, uint256 mintId) external view returns (uint32);

    /**
     * @dev Returns the maximum tokens mintable per wallet for (`edition`, `mintId`).
     */
    function maxMintablePerAccount(address edition, uint256 mintId) external view returns (uint32);

    /**
     * @dev Returns the base mint data for (`edition`, `mintId`).
     */
    function baseMintData(address edition, uint256 mintId) external view returns (BaseData memory);

    /**
     * @dev Returns the base unit price of a single token.
     */
    function price(address edition, uint256 mintId) external view returns (uint256);
}
