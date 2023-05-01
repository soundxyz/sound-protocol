// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";

/**
 * @title IMinterModuleV2
 * @notice The interface for Sound protocol minter modules.
 */
interface IMinterModuleV2 is IERC165 {
    // =============================================================
    //                            STRUCTS
    // =============================================================

    struct BaseData {
        // Auxillary variable for storing the price.
        // May or may not be used.
        uint96 price;
        // Auxillary variable for storing the max amount mintable by an account.
        // May or may not be used.
        uint32 maxMintablePerAccount;
        // The start unix timestamp of the mint.
        uint32 startTime;
        // The end unix timestamp of the mint.
        uint32 endTime;
        // The affiliate fee in basis points.
        uint16 affiliateFeeBPS;
        // Whether the mint is paused.
        bool mintPaused;
        // Whether the mint has been created.
        bool created;
        // The Merkle root of the affiliate allow list, if any.
        bytes32 affiliateMerkleRoot;
    }

    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when the mint instance for an `edition` is created.
     * @param edition The edition address.
     * @param mintId The mint ID, a global incrementing identifier used within the minter
     * @param startTime The start time of the mint.
     * @param endTime The end time of the mint.
     * @param affiliateFeeBPS The affiliate fee in basis points.
     */
    event MintConfigCreated(
        address indexed edition,
        address indexed creator,
        uint128 mintId,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS
    );

    /**
     * @dev Emitted when the `paused` status of `edition` is updated.
     * @param edition The edition address.
     * @param mintId  The mint ID, to distinguish between multiple mints for the same edition.
     * @param paused  The new paused status.
     */
    event MintPausedSet(address indexed edition, uint128 mintId, bool paused);

    /**
     * @dev Emitted when the `paused` status of `edition` is updated.
     * @param edition   The edition address.
     * @param mintId    The mint ID, to distinguish between multiple mints for the same edition.
     * @param startTime The start time of the mint.
     * @param endTime   The end time of the mint.
     */
    event TimeRangeSet(address indexed edition, uint128 mintId, uint32 startTime, uint32 endTime);

    /**
     * @notice Emitted when the `affiliateFeeBPS` is updated.
     * @param edition The edition address.
     * @param mintId  The mint ID, to distinguish between multiple mints for the same edition.
     * @param bps     The affiliate fee basis points.
     */
    event AffiliateFeeSet(address indexed edition, uint128 mintId, uint16 bps);

    /**
     * @dev Emitted when the Merkle root for an affiliate allow list is set.
     * @param edition The edition address.
     * @param mintId  The mint ID, to distinguish between multiple mints for the same edition.
     * @param root    The Merkle root for the affiliate allow list.
     */
    event AffiliateMerkleRootSet(address indexed edition, uint128 mintId, bytes32 root);

    /**
     * @notice Emitted when a mint happens.
     * @param edition            The edition address.
     * @param mintId             The mint ID, to distinguish between multiple mints for
     *                           the same edition.
     * @param buyer              The buyer address.
     * @param fromTokenId        The first token ID of the batch.
     * @param quantity           The size of the batch.
     * @param requiredEtherValue Total amount of Ether required for payment.
     * @param platformFee        The cut paid to the platform.
     * @param affiliateFee       The cut paid to the affiliate.
     * @param affiliate          The affiliate's address.
     * @param affiliated         Whether the affiliate is affiliated.
     * @param attributionId      The attribution ID.
     */
    event Minted(
        address indexed edition,
        uint128 mintId,
        address indexed buyer,
        uint32 fromTokenId,
        uint32 quantity,
        uint128 requiredEtherValue,
        uint128 platformFee,
        uint128 affiliateFee,
        address affiliate,
        bool affiliated,
        uint256 indexed attributionId
    );

    /**
     * @dev Emitted when the `platformFeeBPS` is updated.
     * @param bps The platform fee basis points.
     */
    event PlatformFeeSet(uint16 bps);

    /**
     * @dev Emitted when the `platformFlatFee` is updated.
     * @param flatFee The amount of platform flat fee per token.
     */
    event PlatformFlatFeeSet(uint96 flatFee);

    /**
     * @dev Emitted when the `platformFeeAddress` is updated.
     * @param addr The platform fee address.
     */
    event PlatformFeeAddressSet(address addr);

    /**
     * @dev Emitted when the accrued fees for `affiliate` are withdrawn.
     * @param affiliate The affiliate address.
     * @param accrued   The amount of fees withdrawn.
     */
    event AffiliateFeesWithdrawn(address indexed affiliate, uint256 accrued);

    /**
     * @dev Emitted when the accrued fees for the platform are withdrawn.
     * @param accrued The amount of fees withdrawn.
     */
    event PlatformFeesWithdrawn(uint128 accrued);

    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * @dev The Ether value paid is below the value required.
     * @param paid The amount sent to the contract.
     * @param required The amount required to mint.
     */
    error Underpaid(uint256 paid, uint256 required);

    /**
     * @dev The Ether value paid is not exact.
     * @param paid The amount sent to the contract.
     * @param required The amount required to mint.
     */
    error WrongPayment(uint256 paid, uint256 required);

    /**
     * @dev The number minted has exceeded the max mintable amount.
     * @param available The number of tokens remaining available for mint.
     */
    error ExceedsAvailableSupply(uint32 available);

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
     * @dev The affiliate fee BPS must not exceed `MAX_AFFILIATE_FEE_BPS`.
     */
    error InvalidAffiliateFeeBPS();

    /**
     * @dev The platform fee BPS must not exceed `MAX_PLATFORM_FEE_BPS`.
     */
    error InvalidPlatformFeeBPS();

    /**
     * @dev The platform flat fee must not exceed `MAX_PLATFORM_FLAT_FEE`.
     */
    error InvalidPlatformFlatFee();

    /**
     * @dev The platform fee address cannot be zero.
     */
    error PlatformFeeAddressIsZero();

    /**
     * @dev The mint does not exist.
     */
    error MintDoesNotExist();

    /**
     * @dev The `affiliate` provided is invalid for the given `affiliateProof`.
     */
    error InvalidAffiliate();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Sets the paused status for (`edition`, `mintId`).
     *
     * Calling conditions:
     * - The caller must be the edition's owner or admin.
     */
    function setEditionMintPaused(
        address edition,
        uint128 mintId,
        bool paused
    ) external;

    /**
     * @dev Sets the time range for an edition mint.
     *
     * Calling conditions:
     * - The caller must be the edition's owner or admin.
     *
     * @param edition The edition address.
     * @param mintId The mint ID, a global incrementing identifier used within the minter
     * @param startTime The start time of the mint.
     * @param endTime The end time of the mint.
     */
    function setTimeRange(
        address edition,
        uint128 mintId,
        uint32 startTime,
        uint32 endTime
    ) external;

    /**
     * @dev Sets the affiliate fee for (`edition`, `mintId`).
     *
     * Calling conditions:
     * - The caller must be the edition's owner or admin.
     *
     * @param edition         The edition address.
     * @param mintId          The mint ID, a global incrementing identifier used within the minter
     * @param affiliateFeeBPS The affiliate fee in basis points.
     */
    function setAffiliateFee(
        address edition,
        uint128 mintId,
        uint16 affiliateFeeBPS
    ) external;

    /**
     * @dev Sets the affiliate Merkle root for (`edition`, `mintId`).
     *
     * Calling conditions:
     * - The caller must be the edition's owner or admin.
     *
     * @param edition The edition address.
     * @param mintId  The mint ID, a global incrementing identifier used within the minter
     * @param root    The affiliate Merkle root, if any.
     */
    function setAffiliateMerkleRoot(
        address edition,
        uint128 mintId,
        bytes32 root
    ) external;

    /**
     * @dev Sets the platform fee bps.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract.
     *
     * @param bps The platform fee in basis points.
     */
    function setPlatformFee(uint16 bps) external;

    /**
     * @dev Sets the platform flat fee.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract.
     *
     * @param flatFee The platform flat fee.
     */
    function setPlatformFlatFee(uint96 flatFee) external;

    /**
     * @dev Sets the platform fee address.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract.
     *
     * @param addr The platform fee address.
     */
    function setPlatformFeeAddress(address addr) external;

    /**
     * @dev Withdraws all the accrued fees for `affiliate`.
     */
    function withdrawForAffiliate(address affiliate) external;

    /**
     * @dev Withdraws all the accrued fees for the platform.
     */
    function withdrawForPlatform() external;

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev This is the denominator, in basis points (BPS), for any of the fees.
     * @return The constant value.
     */
    function BPS_DENOMINATOR() external pure returns (uint16);

    /**
     * @dev The maximum basis points (BPS) limit allowed for the affiliate fees.
     * @return The constant value.
     */
    function MAX_AFFILIATE_FEE_BPS() external pure returns (uint16);

    /**
     * @dev The maximum basis points (BPS) limit allowed for the platform fees.
     * @return The constant value.
     */
    function MAX_PLATFORM_FEE_BPS() external pure returns (uint16);

    /**
     * @dev The maximum value for platform flat fee per NFT.
     * @return The constant value.
     */
    function MAX_PLATFORM_FLAT_FEE() external pure returns (uint96);

    /**
     * @dev The total fees accrued for `affiliate`.
     * @param affiliate The affiliate's address.
     * @return The latest value.
     */
    function affiliateFeesAccrued(address affiliate) external view returns (uint128);

    /**
     * @dev The total fees accrued for the platform.
     * @return The latest value.
     */
    function platformFeesAccrued() external view returns (uint128);

    /**
     * @dev Whether `affiliate` is affiliated for (`edition`, `mintId`).
     * @param edition        The edition's address.
     * @param mintId         The mint ID.
     * @param affiliate      The affiliate's address.
     * @param affiliateProof The Merkle proof needed for verifying the affiliate, if any.
     * @return The computed value.
     */
    function isAffiliatedWithProof(
        address edition,
        uint128 mintId,
        address affiliate,
        bytes32[] calldata affiliateProof
    ) external view returns (bool);

    /**
     * @dev Whether `affiliate` is affiliated for (`edition`, `mintId`).
     * @param edition   The edition's address.
     * @param mintId    The mint ID.
     * @param affiliate The affiliate's address.
     * @return The computed value.
     */
    function isAffiliated(
        address edition,
        uint128 mintId,
        address affiliate
    ) external view returns (bool);

    /**
     * @dev Returns the affiliate Merkle root.
     * @param edition The edition's address.
     * @param mintId  The mint ID.
     * @return The latest value.
     */
    function affiliateMerkleRoot(address edition, uint128 mintId) external view returns (bytes32);

    /**
     * @dev The total price for `quantity` tokens for (`edition`, `mintId`).
     *      This does NOT include any additional platform flat fees.
     * @param edition   The edition's address.
     * @param mintId    The mint ID.
     * @param to        The address to mint to.
     * @param quantity  The number of tokens to mint.
     * @return The computed value.
     */
    function totalPrice(
        address edition,
        uint128 mintId,
        address to,
        uint32 quantity
    ) external view returns (uint128);

    /**
     * @dev Returns the platform fee basis points.
     * @return The configured value.
     */
    function platformFeeBPS() external returns (uint16);

    /**
     * @dev Returns the platform flat fee.
     * @return The configured value.
     */
    function platformFlatFee() external returns (uint96);

    /**
     * @dev Returns the platform fee address.
     * @return The configured value.
     */
    function platformFeeAddress() external returns (address);

    /**
     * @dev The next mint ID.
     *      A mint ID is assigned sequentially starting from (0, 1, 2, ...),
     *      and is shared amongst all editions connected to the minter contract.
     * @return The latest value.
     */
    function nextMintId() external view returns (uint128);

    /**
     * @dev The interface ID of the minter.
     * @return The constant value.
     */
    function moduleInterfaceId() external view returns (bytes4);
}
