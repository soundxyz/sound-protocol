// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";

/**
 * @title ISuperMinterV2
 * @notice The interface for the generalized minter.
 */
interface ISuperMinterV2 is IERC165 {
    // =============================================================
    //                            STRUCTS
    // =============================================================

    /**
     * @dev A struct containing the arguments to create a mint.
     */
    struct MintCreation {
        // The edition address.
        address edition;
        // The base price per token.
        // For `VERIFY_SIGNATURE`, this will be the minimum limit of the signed price.
        // Will be 0 if the `tier` is `GA_TIER`.
        uint96 price;
        // The start time of the mint.
        uint32 startTime;
        // The end time of the mint.
        uint32 endTime;
        // The maximum number of tokens an account can mint in this mint.
        uint32 maxMintablePerAccount;
        // The maximum number of tokens mintable.
        uint32 maxMintable;
        // The affiliate fee BPS.
        uint16 affiliateFeeBPS;
        // The affiliate Merkle root, if any.
        bytes32 affiliateMerkleRoot;
        // The tier of the mint.
        uint8 tier;
        // The address of the platform.
        address platform;
        // The mode of the mint. Options: `DEFAULT`, `VERIFY_MERKLE`, `VERIFY_SIGNATURE`.
        uint8 mode;
        // The Merkle root hash, required if `mode` is `VERIFY_MERKLE`.
        bytes32 merkleRoot;
    }

    /**
     * @dev A struct containing the arguments for mint-to.
     */
    struct MintTo {
        // The mint ID.
        address edition;
        // The tier of the mint.
        uint8 tier;
        // The edition-tier schedule number.
        uint8 scheduleNum;
        // The address to mint to.
        address to;
        // The number of tokens to mint.
        uint32 quantity;
        // The allowlisted address. Used if `mode` is `VERIFY_MERKLE`.
        address allowlisted;
        // The allowlisted quantity. Used if `mode` is `VERIFY_MERKLE`.
        // A default zero value means no limit.
        uint32 allowlistedQuantity;
        // The allowlist Merkle proof.
        bytes32[] allowlistProof;
        // The signed price. Used if `mode` is `VERIFY_SIGNATURE`.
        uint96 signedPrice;
        // The signed quantity. Used if `mode` is `VERIFY_SIGNATURE`.
        uint32 signedQuantity;
        // The signed claimed ticket. Used if `mode` is `VERIFY_SIGNATURE`.
        uint32 signedClaimTicket;
        // The expiry timestamp for the signature. Used if `mode` is `VERIFY_SIGNATURE`.
        uint32 signedDeadline;
        // The signature by the signer. Used if `mode` is `VERIFY_SIGNATURE`.
        bytes signature;
        // The affiliate address. Optional.
        address affiliate;
        // The Merkle proof for the affiliate.
        bytes32[] affiliateProof;
        // The attribution ID, optional.
        uint256 attributionId;
    }

    /**
     * @dev A struct containing the arguments for platformAirdrop.
     */
    struct PlatformAirdrop {
        // The mint ID.
        address edition;
        // The tier of the mint.
        uint8 tier;
        // The edition-tier schedule number.
        uint8 scheduleNum;
        // The addresses to mint to.
        address[] to;
        // The signed quantity.
        uint32 signedQuantity;
        // The signed claimed ticket. Used if `mode` is `VERIFY_SIGNATURE`.
        uint32 signedClaimTicket;
        // The expiry timestamp for the signature. Used if `mode` is `VERIFY_SIGNATURE`.
        uint32 signedDeadline;
        // The signature by the signer. Used if `mode` is `VERIFY_SIGNATURE`.
        bytes signature;
    }

    /**
     * @dev A struct containing the total prices and fees.
     */
    struct TotalPriceAndFees {
        // The required Ether value.
        // (`subTotal + platformTxFlatFee + artistReward + affiliateReward + platformReward`).
        uint256 total;
        // The total price before any additive fees.
        uint256 subTotal;
        // The price per token.
        uint256 unitPrice;
        // The final artist fee (inclusive of `finalArtistReward`).
        uint256 finalArtistFee;
        // The total affiliate fee (inclusive of `finalAffiliateReward`).
        uint256 finalAffiliateFee;
        // The final platform fee
        // (inclusive of `finalPlatformReward`, `perTxFlat`, sum of `perMintBPS`).
        uint256 finalPlatformFee;
    }

    /**
     * @dev A struct containing the log data for the `Minted` event.
     */
    struct MintedLogData {
        // The number of tokens minted.
        uint32 quantity;
        // The starting token ID minted.
        uint256 fromTokenId;
        // The allowlisted address.
        address allowlisted;
        // The allowlisted quantity.
        uint32 allowlistedQuantity;
        // The signed quantity.
        uint32 signedQuantity;
        // The signed claim ticket.
        uint32 signedClaimTicket;
        // The affiliate address.
        address affiliate;
        // Whether the affiliate address is affiliated.
        bool affiliated;
        // The total price paid, inclusive of all fees.
        uint256 requiredEtherValue;
        // The price per token.
        uint256 unitPrice;
        // The final artist fee (inclusive of `finalArtistReward`).
        uint256 finalArtistFee;
        // The total affiliate fee (inclusive of `finalAffiliateReward`).
        uint256 finalAffiliateFee;
        // The final platform fee
        // (inclusive of `finalPlatformReward`, `perTxFlat`, sum of `perMintBPS`).
        uint256 finalPlatformFee;
    }

    /**
     * @dev A struct to hold the fee configuration for a platform and a tier.
     */
    struct PlatformFeeConfig {
        // The amount of reward to give to the artist per mint.
        uint96 artistMintReward;
        // The amount of reward to give to the affiliate per mint.
        uint96 affiliateMintReward;
        // The amount of reward to give to the platform per mint.
        uint96 platformMintReward;
        // If the price is greater than this, the rewards will become the threshold variants.
        uint96 thresholdPrice;
        // The amount of reward to give to the artist (`unitPrice >= thresholdPrice`).
        uint96 thresholdArtistMintReward;
        // The amount of reward to give to the affiliate (`unitPrice >= thresholdPrice`).
        uint96 thresholdAffiliateMintReward;
        // The amount of reward to give to the platform (`unitPrice >= thresholdPrice`).
        uint96 thresholdPlatformMintReward;
        // The per-transaction flat fee.
        uint96 platformTxFlatFee;
        // The per-token fee BPS.
        uint16 platformMintFeeBPS;
        // Whether the fees are active.
        bool active;
    }

    /**
     * @dev A struct containing the mint information.
     */
    struct MintInfo {
        // The mint ID.
        address edition;
        // The tier of the mint.
        uint8 tier;
        // The edition-tier schedule number.
        uint8 scheduleNum;
        // The platform address.
        address platform;
        // The base price per token.
        // For `VERIFY_SIGNATURE` this will be the minimum limit of the signed price.
        // If the `tier` is `GA_TIER`, and the `mode` is NOT `VERIFY_SIGNATURE`,
        // this value will be the GA price instead.
        uint96 price;
        // The start time of the mint.
        uint32 startTime;
        // The end time of the mint.
        uint32 endTime;
        // The maximum number of tokens an account can mint in this mint.
        uint32 maxMintablePerAccount;
        // The maximum number of tokens mintable.
        uint32 maxMintable;
        // The total number of tokens minted.
        uint32 minted;
        // The affiliate fee BPS.
        uint16 affiliateFeeBPS;
        // The mode of the mint.
        uint8 mode;
        // Whether the mint is paused.
        bool paused;
        // Whether the mint already has mints.
        bool hasMints;
        // The affiliate Merkle root, if any.
        bytes32 affiliateMerkleRoot;
        // The Merkle root hash, required if `mode` is `VERIFY_MERKLE`.
        bytes32 merkleRoot;
        // The signer address, used if `mode` is `VERIFY_SIGNATURE` or `PLATFORM_AIRDROP`.
        address signer;
    }

    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when a new mint is created.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param creation      The mint creation struct.
     */
    event MintCreated(address indexed edition, uint8 tier, uint8 scheduleNum, MintCreation creation);

    /**
     * @dev Emitted when a mint is paused or un-paused.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param paused        Whether the mint is paused.
     */
    event PausedSet(address indexed edition, uint8 tier, uint8 scheduleNum, bool paused);

    /**
     * @dev Emitted when the time range of a mint is updated.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param startTime     The start time.
     * @param endTime       The end time.
     */
    event TimeRangeSet(address indexed edition, uint8 tier, uint8 scheduleNum, uint32 startTime, uint32 endTime);

    /**
     * @dev Emitted when the base per-token price of a mint is updated.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param price         The base per-token price.
     */
    event PriceSet(address indexed edition, uint8 tier, uint8 scheduleNum, uint96 price);

    /**
     * @dev Emitted when the max mintable per account for a mint is updated.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param value         The max mintable per account.
     */
    event MaxMintablePerAccountSet(address indexed edition, uint8 tier, uint8 scheduleNum, uint32 value);

    /**
     * @dev Emitted when the max mintable for a mint is updated.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param value         The max mintable for the mint.
     */
    event MaxMintableSet(address indexed edition, uint8 tier, uint8 scheduleNum, uint32 value);

    /**
     * @dev Emitted when the Merkle root of a mint is updated.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param merkleRoot    The Merkle root of the mint.
     */
    event MerkleRootSet(address indexed edition, uint8 tier, uint8 scheduleNum, bytes32 merkleRoot);

    /**
     * @dev Emitted when the affiliate fee BPS for a mint is updated.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param bps           The affiliate fee BPS.
     */
    event AffiliateFeeSet(address indexed edition, uint8 tier, uint8 scheduleNum, uint16 bps);

    /**
     * @dev Emitted when the affiliate Merkle root for a mint is updated.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param root          The affiliate Merkle root hash.
     */
    event AffiliateMerkleRootSet(address indexed edition, uint8 tier, uint8 scheduleNum, bytes32 root);

    /**
     * @dev Emitted when tokens are minted.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param to            The recipient of the tokens minted.
     * @param data          The mint-to log data.
     * @param attributionId The optional attribution ID.
     */
    event Minted(
        address indexed edition,
        uint8 tier,
        uint8 scheduleNum,
        address indexed to,
        MintedLogData data,
        uint256 indexed attributionId
    );

    /**
     * @dev Emitted when tokens are platform airdropped.
     * @param edition        The address of the Sound Edition.
     * @param tier           The tier.
     * @param scheduleNum    The edition-tier schedule number.
     * @param to             The recipients of the tokens minted.
     * @param signedQuantity The amount of tokens per address.
     * @param fromTokenId    The first token ID minted.
     */
    event PlatformAirdropped(
        address indexed edition,
        uint8 tier,
        uint8 scheduleNum,
        address[] to,
        uint32 signedQuantity,
        uint256 fromTokenId
    );

    /**
     * @dev Emitted when the platform fee configuration for `tier` is updated.
     * @param platform The platform address.
     * @param tier     The tier of the mint.
     * @param config   The platform fee configuration.
     */
    event PlatformFeeConfigSet(address indexed platform, uint8 tier, PlatformFeeConfig config);

    /**
     * @dev Emitted when the default platform fee configuration is updated.
     * @param platform The platform address.
     * @param config   The platform fee configuration.
     */
    event DefaultPlatformFeeConfigSet(address indexed platform, PlatformFeeConfig config);

    /**
     * @dev Emitted when affiliate fees are withdrawn.
     * @param affiliate The recipient of the fees.
     * @param accrued   The amount of Ether accrued and withdrawn.
     */
    event AffiliateFeesWithdrawn(address indexed affiliate, uint256 accrued);

    /**
     * @dev Emitted when platform fees are withdrawn.
     * @param platform  The platform address.
     * @param accrued   The amount of Ether accrued and withdrawn.
     */
    event PlatformFeesWithdrawn(address indexed platform, uint256 accrued);

    /**
     * @dev Emitted when the platform fee recipient address is updated.
     * @param platform  The platform address.
     * @param recipient The platform fee recipient address.
     */
    event PlatformFeeAddressSet(address indexed platform, address recipient);

    /**
     * @dev Emitted when the per-token price for the GA tier is set.
     * @param platform The platform address.
     * @param price    The price per token for the GA tier.
     */
    event GAPriceSet(address indexed platform, uint96 price);

    /**
     * @dev Emitted when the signer for a platform is set.
     * @param platform The platform address.
     * @param signer   The signer for the platform.
     */
    event PlatformSignerSet(address indexed platform, address signer);

    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * @dev Exact payment required.
     * @param paid The amount of Ether paid.
     * @param required The amount of Ether required.
     */
    error WrongPayment(uint256 paid, uint256 required);

    /**
     * @dev The mint is not opened.
     * @param blockTimestamp The current block timestamp.
     * @param startTime      The opening time of the mint.
     * @param endTime        The closing time of the mint.
     */
    error MintNotOpen(uint256 blockTimestamp, uint32 startTime, uint32 endTime);

    /**
     * @dev The mint is paused.
     */
    error MintPaused();

    /**
     * @dev Cannot perform the operation when any mints exist.
     */
    error MintsAlreadyExist();

    /**
     * @dev The time range is invalid.
     */
    error InvalidTimeRange();

    /**
     * @dev The max mintable range is invalid.
     */
    error InvalidMaxMintableRange();

    /**
     * @dev The affiliate fee BPS cannot exceed the limit.
     */
    error InvalidAffiliateFeeBPS();

    /**
     * @dev The affiliate fee BPS cannot exceed the limit.
     */
    error InvalidPlatformFeeBPS();

    /**
     * @dev The affiliate fee BPS cannot exceed the limit.
     */
    error InvalidPlatformFlatFee();

    /**
     * @dev Cannot mint more than the maximum limit per account.
     */
    error ExceedsMaxPerAccount();

    /**
     * @dev Cannot mint more than the maximum supply.
     */
    error ExceedsMintSupply();

    /**
     * @dev Cannot mint more than the signed quantity.
     */
    error ExceedsSignedQuantity();

    /**
     * @dev The signature is invalid.
     */
    error InvalidSignature();

    /**
     * @dev The signature has expired.
     */
    error SignatureExpired();

    /**
     * @dev The signature claim ticket has already been used.
     */
    error SignatureAlreadyUsed();

    /**
     * @dev The Merkle root cannot be empty.
     */
    error MerkleRootIsEmpty();

    /**
     * @dev The Merkle proof is invalid.
     */
    error InvalidMerkleProof();

    /**
     * @dev The caller has not been delegated via delegate cash.
     */
    error CallerNotDelegated();

    /**
     * @dev The max mintable amount per account cannot be zero.
     */
    error MaxMintablePerAccountIsZero();

    /**
     * @dev The max mintable value cannot be zero.
     */
    error MaxMintableIsZero();

    /**
     * @dev The plaform fee address cannot be the zero address.
     */
    error PlatformFeeAddressIsZero();

    /**
     * @dev The mint does not exist.
     */
    error MintDoesNotExist();

    /**
     * @dev The affiliate provided is invalid.
     */
    error InvalidAffiliate();

    /**
     * @dev The mint mode provided is invalid.
     */
    error InvalidMode();

    /**
     * @dev The signed price is too low.
     */
    error SignedPriceTooLow();

    /**
     * @dev The platform fee configuration provided is invalid.
     */
    error InvalidPlatformFeeConfig();

    /**
     * @dev The parameter cannot be configured.
     */
    error NotConfigurable();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Creates a mint.
     * @param c The mint creation struct.
     * @return scheduleNum The mint ID.
     */
    function createEditionMint(MintCreation calldata c) external returns (uint8 scheduleNum);

    /**
     * @dev Performs a mint.
     * @param p The mint-to parameters.
     * @return fromTokenId The first token ID minted.
     */
    function mintTo(MintTo calldata p) external payable returns (uint256 fromTokenId);

    /**
     * @dev Performs a platform airdrop.
     * @param p The platform airdrop parameters.
     * @return fromTokenId The first token ID minted.
     */
    function platformAirdrop(PlatformAirdrop calldata p) external returns (uint256 fromTokenId);

    /**
     * @dev Sets the price of the mint.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param price         The price per token.
     */
    function setPrice(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        uint96 price
    ) external;

    /**
     * @dev Pause or unpase the the mint.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param paused        Whether to pause the mint.
     */
    function setPaused(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        bool paused
    ) external;

    /**
     * @dev Sets the time range for the the mint.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param startTime     The mint start time.
     * @param endTime       The mint end time.
     */
    function setTimeRange(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        uint32 startTime,
        uint32 endTime
    ) external;

    /**
     * @dev Sets the start time for the the mint.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param startTime     The mint start time.
     */
    function setStartTime(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        uint32 startTime
    ) external;

    /**
     * @dev Sets the affiliate fee BPS for the mint.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param bps           The fee BPS.
     */
    function setAffiliateFee(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        uint16 bps
    ) external;

    /**
     * @dev Sets the affiliate Merkle root for the mint.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param root          The affiliate Merkle root.
     */
    function setAffiliateMerkleRoot(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        bytes32 root
    ) external;

    /**
     * @dev Sets the max mintable per account.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param value         The max mintable per account.
     */
    function setMaxMintablePerAccount(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        uint32 value
    ) external;

    /**
     * @dev Sets the max mintable for the mint.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param value         The max mintable for the mint.
     */
    function setMaxMintable(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        uint32 value
    ) external;

    /**
     * @dev Sets the mode for the mint. The mint mode must be `VERIFY_MERKLE`.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param merkleRoot    The Merkle root of the mint.
     */
    function setMerkleRoot(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        bytes32 merkleRoot
    ) external;

    /**
     * @dev Withdraws all accrued fees of the affiliate, to the affiliate.
     * @param affiliate The affiliate address.
     */
    function withdrawForAffiliate(address affiliate) external;

    /**
     * @dev Withdraws all accrued fees of the platform, to the their fee address.
     * @param platform The platform address.
     */
    function withdrawForPlatform(address platform) external;

    /**
     * @dev Allows the caller, as a platform, to set their fee address
     * @param recipient The platform fee address of the caller.
     */
    function setPlatformFeeAddress(address recipient) external;

    /**
     * @dev Allows the caller, as a platform, to set their per-tier fee configuration.
     * @param tier The tier of the mint.
     * @param c    The platform fee configuration struct.
     */
    function setPlatformFeeConfig(uint8 tier, PlatformFeeConfig memory c) external;

    /**
     * @dev Allows the caller, as a platform, to set their default fee configuration.
     * @param c    The platform fee configuration struct.
     */
    function setDefaultPlatformFeeConfig(PlatformFeeConfig memory c) external;

    /**
     * @dev Allows the platform to set the price for the GA tier.
     * @param price The price per token for the GA tier.
     */
    function setGAPrice(uint96 price) external;

    /**
     * @dev Allows the platform to set their signer.
     * @param signer The signer for the platform.
     */
    function setPlatformSigner(address signer) external;

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev Returns the GA tier. Which is 0.
     * @return The constant value.
     */
    function GA_TIER() external pure returns (uint8);

    /**
     * @dev The EIP-712 typehash for signed mints.
     * @return The constant value.
     */
    function MINT_TO_TYPEHASH() external pure returns (bytes32);

    /**
     * @dev The EIP-712 typehash for platform airdrop mints.
     * @return The constant value.
     */
    function PLATFORM_AIRDROP_TYPEHASH() external pure returns (bytes32);

    /**
     * @dev The default mint mode.
     * @return The constant value.
     */
    function DEFAULT() external pure returns (uint8);

    /**
     * @dev The mint mode for Merkle drops.
     * @return The constant value.
     */
    function VERIFY_MERKLE() external pure returns (uint8);

    /**
     * @dev The mint mode for Merkle drops.
     * @return The constant value.
     */
    function VERIFY_SIGNATURE() external pure returns (uint8);

    /**
     * @dev The mint mode for platform airdrop.
     * @return The constant value.
     */
    function PLATFORM_AIRDROP() external pure returns (uint8);

    /**
     * @dev The denominator used in BPS fee calculations.
     * @return The constant value.
     */
    function BPS_DENOMINATOR() external pure returns (uint16);

    /**
     * @dev The maximum affiliate fee BPS.
     * @return The constant value.
     */
    function MAX_AFFILIATE_FEE_BPS() external pure returns (uint16);

    /**
     * @dev The maximum per-mint platform fee BPS.
     * @return The constant value.
     */
    function MAX_PLATFORM_PER_MINT_FEE_BPS() external pure returns (uint16);

    /**
     * @dev The maximum per-mint reward. Applies to artists, affiliates, platform.
     * @return The constant value.
     */
    function MAX_PER_MINT_REWARD() external pure returns (uint96);

    /**
     * @dev The maximum platform per-transaction flat fee.
     * @return The constant value.
     */
    function MAX_PLATFORM_PER_TX_FLAT_FEE() external pure returns (uint96);

    /**
     * @dev Returns the amount of fees accrued by the platform.
     * @param platform The platform address.
     * @return The latest value.
     */
    function platformFeesAccrued(address platform) external view returns (uint256);

    /**
     * @dev Returns the fee recipient for the platform.
     * @param platform The platform address.
     * @return The configured value.
     */
    function platformFeeAddress(address platform) external view returns (address);

    /**
     * @dev Returns the amount of fees accrued by the affiliate.
     * @param affiliate The affiliate address.
     * @return The latest value.
     */
    function affiliateFeesAccrued(address affiliate) external view returns (uint256);

    /**
     * @dev Returns the EIP-712 digest of the mint-to data for signature mints.
     * @param p The mint-to parameters.
     * @return The computed value.
     */
    function computeMintToDigest(MintTo calldata p) external view returns (bytes32);

    /**
     * @dev Returns the EIP-712 digest of the mint-to data for platform airdrops.
     * @param p The platform airdrop parameters.
     * @return The computed value.
     */
    function computePlatformAirdropDigest(PlatformAirdrop calldata p) external view returns (bytes32);

    /**
     * @dev Returns the total price and fees for the mint.
     * @param edition           The address of the Sound Edition.
     * @param tier              The tier.
     * @param scheduleNum       The edition-tier schedule number.
     * @param quantity          How many tokens to mint.
     * @param hasValidAffiliate Whether there is a valid affiliate for the mint.
     * @return A struct containing the total price and fees.
     */
    function totalPriceAndFees(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        uint32 quantity,
        bool hasValidAffiliate
    ) external view returns (TotalPriceAndFees memory);

    /**
     * @dev Returns the total price and fees for the mint.
     * @param edition          The address of the Sound Edition.
     * @param tier             The tier.
     * @param scheduleNum      The edition-tier schedule number.
     * @param quantity         How many tokens to mint.
     * @param signedPrice      The signed price.
     * @param hasValidAffiliate Whether there is a valid affiliate for the mint.
     * @return A struct containing the total price and fees.
     */
    function totalPriceAndFeesWithSignedPrice(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        uint32 quantity,
        uint96 signedPrice,
        bool hasValidAffiliate
    ) external view returns (TotalPriceAndFees memory);

    /**
     * @dev Returns the GA price for the platform.
     * @param platform The platform address.
     * @return The configured value.
     */
    function gaPrice(address platform) external view returns (uint96);

    /**
     * @dev Returns the signer for the platform.
     * @param platform The platform address.
     * @return The configured value.
     */
    function platformSigner(address platform) external view returns (address);

    /**
     * @dev Returns the next mint schedule number for the edition-tier.
     * @param edition The Sound Edition address.
     * @param tier    The tier.
     * @return The next schedule number for the edition-tier.
     */
    function nextScheduleNum(address edition, uint8 tier) external view returns (uint8);

    /**
     * @dev Returns the number of tokens minted by `collector` for the mint.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param collector     The address which tokens are minted to,
     *                      or in the case of `VERIFY_MERKLE`, is the allowlisted address.
     * @return The number of tokens minted.
     */
    function numberMinted(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        address collector
    ) external view returns (uint32);

    /**
     * @dev Returns whether the affiliate is affiliated for the mint
     * @param edition        The address of the Sound Edition.
     * @param tier           The tier.
     * @param scheduleNum    The edition-tier schedule number.
     * @param affiliate      The affiliate address.
     * @param affiliateProof The Merkle proof for the affiliate.
     * @return The result.
     */
    function isAffiliatedWithProof(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        address affiliate,
        bytes32[] calldata affiliateProof
    ) external view returns (bool);

    /**
     * @dev Returns whether the affiliate is affiliated for the mint.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param affiliate     The affiliate address.
     * @return A boolean on whether the affiliate is affiliated for the mint.
     */
    function isAffiliated(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        address affiliate
    ) external view returns (bool);

    /**
     * @dev Returns whether the claim tickets have been used.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @param claimTickets  An array of claim tickets.
     * @return An array of bools, where true means that a ticket has been used.
     */
    function checkClaimTickets(
        address edition,
        uint8 tier,
        uint8 scheduleNum,
        uint32[] calldata claimTickets
    ) external view returns (bool[] memory);

    /**
     * @dev Returns the platform fee configuration for the tier.
     * @param platform The platform address.
     * @param tier     The tier of the mint.
     * @return The platform fee configuration struct.
     */
    function platformFeeConfig(address platform, uint8 tier) external view returns (PlatformFeeConfig memory);

    /**
     * @dev Returns the default platform fee configuration.
     * @param platform The platform address.
     * @return The platform fee configuration struct.
     */
    function defaultPlatformFeeConfig(address platform) external view returns (PlatformFeeConfig memory);

    /**
     * @dev Returns the effective platform fee configuration.
     * @param platform The platform address.
     * @param tier     The tier of the mint.
     * @return The platform fee configuration struct.
     */
    function effectivePlatformFeeConfig(address platform, uint8 tier) external view returns (PlatformFeeConfig memory);

    /**
     * @dev Returns an array of mint information structs pertaining to the mint.
     * @param edition The Sound Edition address.
     * @return An array of mint information structs.
     */
    function mintInfoList(address edition) external view returns (MintInfo[] memory);

    /**
     * @dev Returns information pertaining to the mint.
     * @param edition       The address of the Sound Edition.
     * @param tier          The tier.
     * @param scheduleNum   The edition-tier schedule number.
     * @return The mint info struct.
     */
    function mintInfo(
        address edition,
        uint8 tier,
        uint8 scheduleNum
    ) external view returns (MintInfo memory);

    /**
     * @dev Retuns the EIP-712 name for the contract.
     * @return The constant value.
     */
    function name() external pure returns (string memory);

    /**
     * @dev Retuns the EIP-712 version for the contract.
     * @return The constant value.
     */
    function version() external pure returns (string memory);
}
