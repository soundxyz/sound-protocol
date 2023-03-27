// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";

/**
 * @dev Data unique to a Sound Automated Market (i.e. bonding curve mint).
 */
struct SAMInfo {
    uint96 basePrice;
    uint128 linearPriceSlope;
    uint128 inflectionPrice;
    uint32 inflectionPoint;
    uint128 goldenEggFeesAccrued;
    uint128 balance;
    uint32 supply;
    uint32 maxSupply;
    uint32 buyFreezeTime;
    uint16 artistFeeBPS;
    uint16 affiliateFeeBPS;
    uint16 goldenEggFeeBPS;
    bytes32 affiliateMerkleRoot;
}

/**
 * @title ISAM
 * @dev Interface for the Sound Automated Market module.
 * @author Sound.xyz
 */
interface ISAM is IERC165 {
    // =============================================================
    //                            STRUCTS
    // =============================================================

    struct SAMData {
        // The sigmoid inflection price of the bonding curve.
        uint128 inflectionPrice;
        // The price added to the bonding curve price.
        uint96 basePrice;
        // The sigmoid inflection point of the bonding curve.
        uint32 inflectionPoint;
        // The amount of fees accrued by the golden egg.
        uint112 goldenEggFeesAccrued;
        // The balance of the pool for the edition.
        // 112 bits is enough to represent 5,192,296,858,534,828 ETH.
        // At the point of writing, there are 120,479,006 ETH in Ethereum mainnet,
        // and 9,050,469,069 MATIC in Polygon PoS chain.
        uint112 balance;
        // The amount of tokens in the bonding curve.
        uint32 supply;
        // The slope for the additional linear component to the bonding curve price.
        uint128 linearPriceSlope;
        // The supply cap for buying tokens.
        // Note: The supply can go over the cap if the cap is manually decreased.
        uint32 maxSupply;
        // The cutoff time for buying tokens.
        uint32 buyFreezeTime;
        // The fee BPS (basis points) to pay the artist.
        uint16 artistFeeBPS;
        // The fee BPS (basis points) to pay affiliates.
        uint16 affiliateFeeBPS;
        // The fee BPS (basis points) to pay the golden egg holder.
        uint16 goldenEggFeeBPS;
        // Whether a token has already been minted on the bonding curve.
        bool hasMinted;
        // Whether the SAM has been created.
        bool created;
        // The affiliate Merkle root, if any.
        bytes32 affiliateMerkleRoot;
    }

    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when a bonding curve is created.
     * @param edition          The edition address.
     * @param linearPriceSlope The linear price slope of the bonding curve.
     * @param inflectionPrice  The sigmoid inflection price of the bonding curve.
     * @param inflectionPoint  The sigmoid inflection point of the bonding curve.
     * @param maxSupply        The supply cap for buying tokens.
     * @param buyFreezeTime    The cutoff time for buying tokens.
     * @param artistFeeBPS     The fee BPS (basis points) to pay the artist.
     * @param goldenEggFeeBPS  The fee BPS (basis points) to pay the golden egg holder.
     * @param affiliateFeeBPS  The fee BPS (basis points) to pay affiliates.
     */
    event Created(
        address indexed edition,
        uint96 basePrice,
        uint128 linearPriceSlope,
        uint128 inflectionPrice,
        uint32 inflectionPoint,
        uint32 maxSupply,
        uint32 buyFreezeTime,
        uint16 artistFeeBPS,
        uint16 goldenEggFeeBPS,
        uint16 affiliateFeeBPS
    );

    /**
     * @dev Emitted when tokens are bought from the bonding curve.
     * @param edition         The edition address.
     * @param buyer           Address of the buyer.
     * @param fromTokenId     The starting token ID minted for the batch.
     * @param fromCurveSupply The start of the curve supply for the batch.
     * @param quantity        The number of tokens bought.
     * @param totalPayment    The total amount of ETH paid.
     * @param platformFee     The cut paid to the platform.
     * @param artistFee       The cut paid to the artist.
     * @param goldenEggFee    The cut paid to the golden egg.
     * @param affiliateFee    The cut paid to the affiliate.
     * @param affiliate       The affiliate's address.
     * @param affiliated      Whether the affiliate is affiliated.
     * @param attributionId   The attribution ID.
     */
    event Bought(
        address indexed edition,
        address indexed buyer,
        uint256 fromTokenId,
        uint32 fromCurveSupply,
        uint32 quantity,
        uint128 totalPayment,
        uint128 platformFee,
        uint128 artistFee,
        uint128 goldenEggFee,
        uint128 affiliateFee,
        address affiliate,
        bool affiliated,
        uint256 indexed attributionId
    );

    /**
     * @dev Emitted when tokens are sold into the bonding curve.
     * @param edition         The edition address.
     * @param seller          Address of the seller.
     * @param fromCurveSupply The start of the curve supply for the batch.
     * @param tokenIds        The token IDs burned.
     * @param totalPayout     The total amount of ETH paid out.
     * @param attributionId   The attribution ID.
     */
    event Sold(
        address indexed edition,
        address indexed seller,
        uint32 fromCurveSupply,
        uint256[] tokenIds,
        uint128 totalPayout,
        uint256 indexed attributionId
    );

    /**
     * @dev Emitted when the `basePrice` is updated.
     * @param edition   The edition address.
     * @param basePrice The price added to the bonding curve price.
     */
    event BasePriceSet(address indexed edition, uint96 basePrice);

    /**
     * @dev Emitted when the `linearPriceSlope` is updated.
     * @param edition          The edition address.
     * @param linearPriceSlope The linear price slope of the bonding curve.
     */
    event LinearPriceSlopeSet(address indexed edition, uint128 linearPriceSlope);

    /**
     * @dev Emitted when the `inflectionPrice` is updated.
     * @param edition         The edition address.
     * @param inflectionPrice The sigmoid inflection price of the bonding curve.
     */
    event InflectionPriceSet(address indexed edition, uint128 inflectionPrice);

    /**
     * @dev Emitted when the `inflectionPoint` is updated.
     * @param edition         The edition address.
     * @param inflectionPoint The sigmoid inflection point of the bonding curve.
     */
    event InflectionPointSet(address indexed edition, uint32 inflectionPoint);

    /**
     * @dev Emitted when the `artistFeeBPS` is updated.
     * @param edition The edition address.
     * @param bps     The affiliate fee basis points.
     */
    event ArtistFeeSet(address indexed edition, uint16 bps);

    /**
     * @dev Emitted when the `affiliateFeeBPS` is updated.
     * @param edition The edition address.
     * @param bps     The affiliate fee basis points.
     */
    event AffiliateFeeSet(address indexed edition, uint16 bps);

    /**
     * @dev Emitted when the Merkle root for an affiliate allow list is updated.
     * @param edition The edition address.
     * @param root    The Merkle root for the affiliate allow list.
     */
    event AffiliateMerkleRootSet(address indexed edition, bytes32 root);

    /**
     * @dev Emitted when the `goldenEggFeeBPS` is updated.
     * @param edition The edition address.
     * @param bps     The golden egg fee basis points.
     */
    event GoldenEggFeeSet(address indexed edition, uint16 bps);

    /**
     * @dev Emitted when the `maxSupply` updated.
     * @param edition The edition address.
     */
    event MaxSupplySet(address indexed edition, uint32 maxSupply);

    /**
     * @dev Emitted when the `buyFreezeTime` updated.
     * @param edition The edition address.
     */
    event BuyFreezeTimeSet(address indexed edition, uint32 buyFreezeTime);

    /**
     * @dev Emitted when the `platformFeeBPS` is updated.
     * @param bps The platform fee basis points.
     */
    event PlatformFeeSet(uint16 bps);

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
     * @dev Emitted when the accrued fees for the golden egg of `edition` are withdrawn.
     * @param edition    The edition address.
     * @param receipient The receipient.
     * @param accrued    The amount of fees withdrawn.
     */
    event GoldenEggFeesWithdrawn(address indexed edition, address indexed receipient, uint128 accrued);

    /**
     * @dev Emitted when the accrued fees for the platform are withdrawn.
     * @param accrued The amount of fees withdrawn.
     */
    event PlatformFeesWithdrawn(uint128 accrued);

    /**
     * @dev Emitted when the approved factories are set.
     * @param factories The list of approved factories.
     */
    event ApprovedEditionFactoriesSet(address[] factories);

    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * @dev The Ether value paid is below the value required.
     * @param paid     The amount sent to the contract.
     * @param required The amount required.
     */
    error Underpaid(uint256 paid, uint256 required);

    /**
     * @dev The Ether value paid out is below the value required.
     * @param payout   The amount to pau out..
     * @param required The amount required.
     */
    error InsufficientPayout(uint256 payout, uint256 required);

    /**
     * @dev There is not enough tokens in the Sound Automated Market for selling back.
     * @param available The number of tokens in the Sound Automated Market.
     * @param required  The amount of tokens required.
     */
    error InsufficientSupply(uint256 available, uint256 required);

    /**
     * @dev Cannot perform the operation during the SAM phase.
     */
    error InSAMPhase();

    /**
     * @dev The inflection price cannot be zero.
     */
    error InflectionPriceIsZero();

    /**
     * @dev The inflection point cannot be zero.
     */
    error InflectionPointIsZero();

    /**
     * @dev The max supply cannot be increased after the SAM has started.
     *      In the `create` function, the initial max supply cannot be zero.
     */
    error InvalidMaxSupply();

    /**
     * @dev The buy freeze time cannot be increased after the SAM has started.
     *      In the `create` function, the initial buy freeze time cannot be zero.
     */
    error InvalidBuyFreezeTime();

    /**
     * @dev The BPS for the fee cannot exceed the `MAX_PLATFORM_FEE_BPS`.
     */
    error InvalidPlatformFeeBPS();

    /**
     * @dev The BPS for the fee cannot exceed the `MAX_ARTIST_FEE_BPS`.
     */
    error InvalidArtistFeeBPS();

    /**
     * @dev The BPS for the fee cannot exceed the `MAX_AFFILAITE_FEE_BPS`.
     */
    error InvalidAffiliateFeeBPS();

    /**
     * @dev The BPS for the fee cannot exceed the `MAX_GOLDEN_EGG_FEE_BPS`.
     */
    error InvalidGoldenEggFeeBPS();

    /**
     * @dev The `affiliate` provided is invalid for the given `affiliateProof`.
     */
    error InvalidAffiliate();

    /**
     * @dev Cannot buy.
     */
    error BuyIsFrozen();

    /**
     * @dev The purchase cannot exceed the max supply.
     * @param available The number of tokens remaining available for mint.
     */
    error ExceedsMaxSupply(uint32 available);

    /**
     * @dev The platform fee address cannot be zero.
     */
    error PlatformFeeAddressIsZero();

    /**
     * @dev There already is a Sound Automated Market for `edition`.
     */
    error SAMAlreadyExists();

    /**
     * @dev There is no Sound Automated Market for `edition`.
     */
    error SAMDoesNotExist();

    /**
     * @dev Cannot mint zero tokens.
     */
    error MintZeroQuantity();

    /**
     * @dev Cannot burn zero tokens.
     */
    error BurnZeroQuantity();

    /**
     * @dev The bytecode hash of the edition is not approved.
     */
    error UnapprovedEdition();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Creates a Sound Automated Market on `edition`.
     * @param edition          The edition address.
     * @param basePrice        The price added to the bonding curve price.
     * @param linearPriceSlope The linear price slope of the bonding curve.
     * @param inflectionPrice  The sigmoid inflection price of the bonding curve.
     * @param inflectionPoint  The sigmoid inflection point of the bonding curve.
     * @param maxSupply        The supply cap for buying tokens.
     * @param buyFreezeTime    The cutoff time for buying tokens.
     * @param artistFeeBPS     The fee BPS (basis points) to pay the artist.
     * @param goldenEggFeeBPS  The fee BPS (basis points) to pay the golden egg holder.
     * @param affiliateFeeBPS  The fee BPS (basis points) to pay affiliates.
     * @param editionBy        The address which created the edition via the factory.
     * @param editionSalt      The salt used to create the edition via the factory.
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
    ) external;

    /**
     * @dev Mints (buys) tokens for a given edition.
     * @param edition        The edition address.
     * @param to             The address to mint to.
     * @param quantity       Token quantity to mint in song `edition`.
     * @param affiliate      The affiliate address.
     * @param affiliateProof The Merkle proof needed for verifying the affiliate, if any.
     * @param attributionId  The attribution ID.
     */
    function buy(
        address edition,
        address to,
        uint32 quantity,
        address affiliate,
        bytes32[] calldata affiliateProof,
        uint256 attributionId
    ) external payable;

    /**
     * @dev Burns (sell) tokens for a given edition.
     * @param edition       The edition address.
     * @param tokenIds      The token IDs to burn.
     * @param minimumPayout The minimum payout for the transaction to succeed.
     * @param payoutTo      The address to send the payout to.
     * @param attributionId The attribution ID.
     */
    function sell(
        address edition,
        uint256[] calldata tokenIds,
        uint256 minimumPayout,
        address payoutTo,
        uint256 attributionId
    ) external;

    /**
     * @dev Sets the base price for `edition`.
     * This will be added to the bonding curve price.
     *
     * Calling conditions:
     * - The caller must be the edition's owner or admin.
     *
     * @param edition   The edition address.
     * @param basePrice The price added to the bonding curve price.
     */
    function setBasePrice(address edition, uint96 basePrice) external;

    /**
     * @dev Sets the linear price slope for `edition`.
     *
     * Calling conditions:
     * - The caller must be the edition's owner or admin.
     *
     * @param edition          The edition address.
     * @param linearPriceSlope The linear price slope of the bonding curve.
     */
    function setLinearPriceSlope(address edition, uint128 linearPriceSlope) external;

    /**
     * @dev Sets the bonding curve inflection price for `edition`.
     *
     * Calling conditions:
     * - The caller must be the edition's owner or admin.
     *
     * @param edition         The edition address.
     * @param inflectionPrice The sigmoid inflection price of the bonding curve.
     */
    function setInflectionPrice(address edition, uint128 inflectionPrice) external;

    /**
     * @dev Sets the bonding curve inflection point for `edition`.
     *
     * Calling conditions:
     * - The caller must be the edition's owner or admin.
     *
     * @param edition         The edition address.
     * @param inflectionPoint The sigmoid inflection point of the bonding curve.
     */
    function setInflectionPoint(address edition, uint32 inflectionPoint) external;

    /**
     * @dev Sets the artist fee for `edition`.
     *
     * Calling conditions:
     * - The caller must be the edition's owner or admin.
     *
     * @param edition The edition address.
     * @param bps     The artist fee in basis points.
     */
    function setArtistFee(address edition, uint16 bps) external;

    /**
     * @dev Sets the affiliate fee for `edition`.
     *
     * Calling conditions:
     * - The caller must be the edition's owner or admin.
     *
     * @param edition The edition address.
     * @param bps     The affiliate fee in basis points.
     */
    function setAffiliateFee(address edition, uint16 bps) external;

    /**
     * @dev Sets the affiliate Merkle root for (`edition`, `mintId`).
     *
     * Calling conditions:
     * - The caller must be the edition's owner or admin.
     *
     * @param edition The edition address.
     * @param root    The affiliate Merkle root, if any.
     */
    function setAffiliateMerkleRoot(address edition, bytes32 root) external;

    /**
     * @dev Sets the golden egg fee for `edition`.
     *
     * Calling conditions:
     * - The caller must be the edition's owner or admin.
     *
     * @param edition The edition address.
     * @param bps     The golden egg fee in basis points.
     */
    function setGoldenEggFee(address edition, uint16 bps) external;

    /**
     * @dev Sets the supply cap for `edition`.
     *
     * Calling conditions:
     * - The caller must be the edition's owner or admin.
     *
     * @param edition The edition address.
     */
    function setMaxSupply(address edition, uint32 maxSupply) external;

    /**
     * @dev Sets the buy freeze time for `edition`.
     *
     * Calling conditions:
     * - The caller must be the edition's owner or admin.
     *
     * @param edition The edition address.
     */
    function setBuyFreezeTime(address edition, uint32 buyFreezeTime) external;

    /**
     * @dev Withdraws all the accrued fees for `affiliate`.
     * @param affiliate The affiliate address.
     */
    function withdrawForAffiliate(address affiliate) external;

    /**
     * @dev Withdraws all the accrued fees for the platform.
     */
    function withdrawForPlatform() external;

    /**
     * @dev Withdraws all the accrued fees for the golden egg.
     * @param edition The edition address.
     */
    function withdrawForGoldenEgg(address edition) external;

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
     * @dev Sets the platform fee address.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract.
     *
     * @param addr The platform fee address.
     */
    function setPlatformFeeAddress(address addr) external;

    /**
     * @dev Sets the list of approved edition factories.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract.
     *
     * @param factories The list of approved edition factories.
     */
    function setApprovedEditionFactories(address[] calldata factories) external;

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev This is the denominator, in basis points (BPS), for any of the fees.
     * @return The constant value.
     */
    function BPS_DENOMINATOR() external pure returns (uint16);

    /**
     * @dev The maximum basis points (BPS) limit allowed for the platform fees.
     * @return The constant value.
     */
    function MAX_PLATFORM_FEE_BPS() external pure returns (uint16);

    /**
     * @dev The maximum basis points (BPS) limit allowed for the artist fees.
     * @return The constant value.
     */
    function MAX_ARTIST_FEE_BPS() external pure returns (uint16);

    /**
     * @dev The maximum basis points (BPS) limit allowed for the affiliate fees.
     * @return The constant value.
     */
    function MAX_AFFILIATE_FEE_BPS() external pure returns (uint16);

    /**
     * @dev The maximum basis points (BPS) limit allowed for the golden egg fees.
     * @return The constant value.
     */
    function MAX_GOLDEN_EGG_FEE_BPS() external pure returns (uint16);

    /**
     * @dev Returns the platform fee basis points.
     * @return The configured value.
     */
    function platformFeeBPS() external returns (uint16);

    /**
     * @dev Returns the platform fee address.
     * @return The configured value.
     */
    function platformFeeAddress() external returns (address);

    /**
     * @dev Returns the information for the Sound Automated Market for `edition`.
     * @param edition The edition address.
     * @return The latest value.
     */
    function samInfo(address edition) external view returns (SAMInfo memory);

    /**
     * @dev Returns the total value under the bonding curve for `quantity`, from `fromSupply`.
     * @param edition    The edition address.
     * @param fromSupply The starting number of tokens in the bonding curve.
     * @param quantity   The number of tokens.
     * @return The computed value.
     */
    function totalValue(
        address edition,
        uint32 fromSupply,
        uint32 quantity
    ) external view returns (uint256);

    /**
     * @dev Returns the total amount of ETH required to buy from
     *      `supply + supplyForwardOffset` to `supply + supplyForwardOffset + quantity`.
     * @param edition             The edition address.
     * @param supplyForwardOffset The offset added to the current supply.
     * @param quantity            The number of tokens.
     * @return total        The total amount required to be paid, inclusive of all the buy fees.
     * @return platformFee  The platform fee.
     * @return artistFee    The artist fee.
     * @return goldenEggFee The golden egg fee.
     * @return affiliateFee The affiliate fee.
     */
    function totalBuyPriceAndFees(
        address edition,
        uint32 supplyForwardOffset,
        uint32 quantity
    )
        external
        view
        returns (
            uint256 total,
            uint256 platformFee,
            uint256 artistFee,
            uint256 goldenEggFee,
            uint256 affiliateFee
        );

    /**
     * @dev Returns the total amount of ETH required to sell from
     *      `supply - supplyBackwardOffset` to `supply - supplyBackwardOffset - quantity`.
     * @param edition              The edition address.
     * @param supplyBackwardOffset The offset added to the current supply.
     * @param quantity             The number of tokens.
     * @return The computed value.
     */
    function totalSellPrice(
        address edition,
        uint32 supplyBackwardOffset,
        uint32 quantity
    ) external view returns (uint256);

    /**
     * @dev The total fees accrued for the golden egg on `edition`.
     * @param edition The edition address.
     * @return The latest value.
     */
    function goldenEggFeesAccrued(address edition) external view returns (uint128);

    /**
     * @dev The receipient of the golden egg fees on `edition`.
     *      If there is no golden egg winner, the `receipient` will be the `edition`.
     * @param edition The edition address.
     * @return receipient The latest value.
     */
    function goldenEggFeeRecipient(address edition) external view returns (address receipient);

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
     * @dev Whether `affiliate` is affiliated for `edition`.
     * @param edition        The edition's address.
     * @param affiliate      The affiliate's address.
     * @param affiliateProof The Merkle proof needed for verifying the affiliate, if any.
     * @return The computed value.
     */
    function isAffiliatedWithProof(
        address edition,
        address affiliate,
        bytes32[] calldata affiliateProof
    ) external view returns (bool);

    /**
     * @dev Whether `affiliate` is affiliated for `edition`.
     * @param edition   The edition's address.
     * @param affiliate The affiliate's address.
     * @return The computed value.
     */
    function isAffiliated(address edition, address affiliate) external view returns (bool);

    /**
     * @dev Returns the list of approved edition factories.
     * @return The latest values.
     */
    function approvedEditionFactories() external view returns (address[] memory);

    /**
     * @dev Returns the affiliate Merkle root.
     * @param edition The edition's address.
     * @return The latest value.
     */
    function affiliateMerkleRoot(address edition) external view returns (bytes32);

    /**
     * @dev Returns the module's interface ID.
     * @return The constant value.
     */
    function moduleInterfaceId() external pure returns (bytes4);
}
