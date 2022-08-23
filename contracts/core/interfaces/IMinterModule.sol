// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";

/**
 * @title IMinterModule
 * @notice The interface for Sound minter modules.
 */
interface IMinterModule is IERC165 {
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
    // EVENTS
    // ================================

    /**
     * @dev Emitted when the mint configuration for an `edition` is created.
     * @param edition The edition address.
     * @param mintId The mint ID, to distinguish beteen multiple mints for the same edition.
     * @param startTime The start time of the mint.
     * @param endTime The end time of the mint.
     */
    event MintConfigCreated(
        address indexed edition,
        address indexed creator,
        uint256 mintId,
        uint32 startTime,
        uint32 endTime
    );

    /**
     * @dev Emitted when the `paused` status of `edition` is updated.
     * @param edition The edition address.
     * @param mintId The mint ID, to distinguish beteen multiple mints for the same edition.
     * @param paused The new paused status.
     */
    event MintPausedSet(address indexed edition, uint256 mintId, bool paused);

    /**
     * @dev Emitted when the `paused` status of `edition` is updated.
     * @param edition The edition address.
     * @param mintId The mint ID, to distinguish beteen multiple mints for the same edition.
     * @param startTime The start time of the mint.
     * @param endTime The end time of the mint.
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
     * @dev The Ether value paid is not the exact value required.
     * @param paid The amount sent to the contract.
     * @param required The amount required to mint.
     */
    error WrongEtherValue(uint256 paid, uint256 required);

    /**
     * @dev The number minted has exceeded the max mintable amount.
     * @param maxMintable The total maximum mintable number of tokens.
     */
    error MaxMintableReached(uint32 maxMintable);

    /**
     * @dev The mint is not opened.
     * @param blockTimestamp The current block timestamp.
     * @param startTime The start time of the mint.
     * @param endTime The end time of the mint.
     */
    error MintNotOpen(uint256 blockTimestamp, uint32 startTime, uint32 endTime);

    /**
     * @dev The mint is paused.
     */
    error MintPaused();

    /**
     * @dev The `startTime` is not less than the `endTime`.
     */
    error InvalidTimeRange();

    /**
     * @dev Unauthorized caller
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
     * @dev Sets the time range for an edition mint.
     * @param edition The edition address.
     * @param mintId The mint ID, to distinguish beteen multiple mints for the same edition.
     * @param startTime The start time of the mint.
     * @param endTime The end time of the mint.
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
        bool affiliated
    ) external view returns (uint256);

    /**
     * @dev Returns the next mint ID for `edition`.
     * A mint ID is assigned sequentially for each unique edition address,
     * starting from (0, 1, 2, ...)
     */
    function nextMintId(address edition) external view returns (uint256);

    /**
     * @dev Returns the total maximum mintable number of tokens.
     * @param edition The edition address.
     * @param mintId The mint ID, to distinguish beteen multiple mints for the same edition.
     */
    function maxMintable(address edition, uint256 mintId) external view returns (uint32);

    /**
     * @dev Returns the maximum mintable number of tokens per account.
     * @param edition The edition address.
     * @param mintId The mint ID, to distinguish beteen multiple mints for the same edition.
     */
    function maxMintablePerAccount(address edition, uint256 mintId) external view returns (uint32);

    /**
     * @dev Returns the base mint data for (`edition`, `mintId`).
     */
    function baseMintData(address edition, uint256 mintId) external view returns (BaseData memory);

}
