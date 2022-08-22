// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

/**
 * @title Interface for the base minter functionality, excluding the mint function.
 */
interface IMinterModule {
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
     * @dev Sets the `paused` status for `edition`.
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
     * Calling conditions:
     * - The caller must be the edition's owner or an admin.
     */
    function setTimeRange(
        address edition,
        uint256 mintId,
        uint32 startTime,
        uint32 endTime
    ) external;

    function setAffiliateFee(
        address edition,
        uint256 mintId,
        uint16 affiliateFeeBPS
    ) external;

    function setAffiliateDiscount(
        address edition,
        uint256 mintId,
        uint16 affiliateDiscountBPS
    ) external;

    function setPlatformFee(uint16 platformFeeBPS) external;

    function withdrawForAffiliate(address affiliate) external;

    function withdrawForPlatform(address to) external;

    // ================================
    // VIEW FUNCTIONS
    // ================================

    function MAX_BPS() external pure returns (uint16);

    function affiliateFeesAccrued(address affiliate) external view returns (uint256);

    function platformFeesAccrued() external view returns (uint256);

    function platformFeeBPS() external view returns (uint16);

    function isAffiliated(
        address edition,
        uint256 mintId,
        address affiliate
    ) external view returns (bool);

    function totalPrice(
        address edition,
        uint256 mintId,
        address minter,
        uint32 quantity,
        bool affiliated
    ) external view returns (uint256);

    function maxMintable(address edition, uint256 mintId) external view returns (uint32);

    function maxAllowedPerWallet(address edition, uint256 mintId) external view returns (uint32);
}
