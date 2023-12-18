// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IERC721AUpgradeable } from "chiru-labs/ERC721A-Upgradeable/IERC721AUpgradeable.sol";
import { IERC2981Upgradeable } from "openzeppelin-upgradeable/interfaces/IERC2981Upgradeable.sol";
import { IERC165Upgradeable } from "openzeppelin-upgradeable/utils/introspection/IERC165Upgradeable.sol";

import { IMetadataModule } from "./IMetadataModule.sol";

/**
 * @title ISoundEditionV2_1
 * @notice The interface for Sound edition contracts.
 */
interface ISoundEditionV2_1 is IERC721AUpgradeable, IERC2981Upgradeable {
    // =============================================================
    //                            STRUCTS
    // =============================================================

    /**
     * @dev The information pertaining to a tier.
     */
    struct TierInfo {
        // The tier.
        uint8 tier;
        // The current max mintable amount.
        uint32 maxMintable;
        // The lower bound of the maximum number of tokens that can be minted for the tier.
        uint32 maxMintableLower;
        // The upper bound of the maximum number of tokens that can be minted for the tier.
        uint32 maxMintableUpper;
        // The timestamp (in seconds since unix epoch) after which the
        // max amount of tokens mintable for the tier will drop from
        // `maxMintableUpper` to `maxMintableLower`.
        uint32 cutoffTime;
        // The total number of tokens minted for the tier.
        uint32 minted;
        // The mint randomness for the tier.
        uint256 mintRandomness;
        // Whether the tier mints have concluded.
        bool mintConcluded;
        // Whether the tier has mint randomness enabled.
        bool mintRandomnessEnabled;
        // Whether the tier is frozen.
        bool isFrozen;
    }

    /**
     * @dev A struct containing the arguments for creating a tier.
     */
    struct TierCreation {
        // The tier.
        uint8 tier;
        // The lower bound of the maximum number of tokens that can be minted for the tier.
        uint32 maxMintableLower;
        // The upper bound of the maximum number of tokens that can be minted for the tier.
        uint32 maxMintableUpper;
        // The timestamp (in seconds since unix epoch) after which the
        // max amount of tokens mintable for the tier will drop from
        // `maxMintableUpper` to `maxMintableLower`.
        uint32 cutoffTime;
        // Whether the tier has mint randomness enabled.
        bool mintRandomnessEnabled;
        // Whether the tier is frozen.
        bool isFrozen;
    }

    /**
     * @dev The information pertaining to this edition.
     */
    struct EditionInfo {
        // Base URI for the metadata.
        string baseURI;
        // Contract URI for OpenSea storefront.
        string contractURI;
        // Name of the collection.
        string name;
        // Symbol of the collection.
        string symbol;
        // Address that receives primary and secondary royalties.
        address fundingRecipient;
        // Address of the metadata module. Optional.
        address metadataModule;
        // Whether the metadata is frozen.
        bool isMetadataFrozen;
        // Whether the ability to create tiers is frozen.
        bool isCreateTierFrozen;
        // The royalty BPS (basis points).
        uint16 royaltyBPS;
        // Next token ID to be minted.
        uint256 nextTokenId;
        // Total number of tokens burned.
        uint256 totalBurned;
        // Total number of tokens minted.
        uint256 totalMinted;
        // Total number of tokens currently in existence.
        uint256 totalSupply;
        // An array of tier info. From lowest (0-indexed) to highest.
        TierInfo[] tierInfo;
    }

    /**
     * @dev A struct containing the arguments for initialization.
     */
    struct EditionInitialization {
        // Name of the collection.
        string name;
        // Symbol of the collection.
        string symbol;
        // Address of the metadata module. Optional.
        address metadataModule;
        // Base URI for the metadata.
        string baseURI;
        // Contract URI for OpenSea storefront.
        string contractURI;
        // Address that receives primary and secondary royalties.
        address fundingRecipient;
        // The royalty BPS (basis points).
        uint16 royaltyBPS;
        // Whether the metadata is frozen.
        bool isMetadataFrozen;
        // Whether the ability to create tiers is frozen.
        bool isCreateTierFrozen;
        // An array of tier creation structs. From lowest (0-indexed) to highest.
        TierCreation[] tierCreations;
    }

    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when the metadata module is set.
     * @param metadataModule the address of the metadata module.
     */
    event MetadataModuleSet(address metadataModule);

    /**
     * @dev Emitted when the `baseURI` is set.
     * @param baseURI the base URI of the edition.
     */
    event BaseURISet(string baseURI);

    /**
     * @dev Emitted when the `contractURI` is set.
     * @param contractURI The contract URI of the edition.
     */
    event ContractURISet(string contractURI);

    /**
     * @dev Emitted when the metadata is frozen (e.g.: `baseURI` can no longer be changed).
     * @param metadataModule The address of the metadata module.
     * @param baseURI        The base URI of the edition.
     * @param contractURI    The contract URI of the edition.
     */
    event MetadataFrozen(address metadataModule, string baseURI, string contractURI);

    /**
     * @dev Emitted when the ability to create tier is removed.
     */
    event CreateTierFrozen();

    /**
     * @dev Emitted when the `fundingRecipient` is set.
     * @param recipient The address of the funding recipient.
     */
    event FundingRecipientSet(address recipient);

    /**
     * @dev Emitted when the `royaltyBPS` is set.
     * @param bps The new royalty, measured in basis points.
     */
    event RoyaltySet(uint16 bps);

    /**
     * @dev Emitted when the tier's maximum mintable token quantity range is set.
     * @param tier  The tier.
     * @param lower The lower limit of the maximum number of tokens that can be minted.
     * @param upper The upper limit of the maximum number of tokens that can be minted.
     */
    event MaxMintableRangeSet(uint8 tier, uint32 lower, uint32 upper);

    /**
     * @dev Emitted when the tier's cutoff time set.
     * @param tier    The tier.
     * @param cutoff The timestamp.
     */
    event CutoffTimeSet(uint8 tier, uint32 cutoff);

    /**
     * @dev Emitted when the `mintRandomnessEnabled` for the tier is set.
     * @param tier    The tier.
     * @param enabled The boolean value.
     */
    event MintRandomnessEnabledSet(uint8 tier, bool enabled);

    /**
     * @dev Emitted upon initialization.
     * @param init The initialization data.
     */
    event SoundEditionInitialized(EditionInitialization init);

    /**
     * @dev Emitted when a tier is created.
     * @param creation The tier creation data.
     */
    event TierCreated(TierCreation creation);

    /**
     * @dev Emitted when a tier is frozen.
     * @param tier The tier.
     */
    event TierFrozen(uint8 tier);

    /**
     * @dev Emitted upon ETH withdrawal.
     * @param recipient The recipient of the withdrawal.
     * @param amount    The amount withdrawn.
     * @param caller    The account that initiated the withdrawal.
     */
    event ETHWithdrawn(address recipient, uint256 amount, address caller);

    /**
     * @dev Emitted upon ERC20 withdrawal.
     * @param recipient The recipient of the withdrawal.
     * @param tokens    The addresses of the ERC20 tokens.
     * @param amounts   The amount of each token withdrawn.
     * @param caller    The account that initiated the withdrawal.
     */
    event ERC20Withdrawn(address recipient, address[] tokens, uint256[] amounts, address caller);

    /**
     * @dev Emitted upon a mint.
     * @param tier                 The tier.
     * @param to                   The address to mint to.
     * @param quantity             The number of minted.
     * @param fromTokenId          The first token ID minted.
     * @param fromTierTokenIdIndex The first token index in the tier.
     */
    event Minted(uint8 tier, address to, uint256 quantity, uint256 fromTokenId, uint32 fromTierTokenIdIndex);

    /**
     * @dev Emitted upon an airdrop.
     * @param tier                 The tier.
     * @param to                   The recipients of the airdrop.
     * @param quantity             The number of tokens airdropped to each address in `to`.
     * @param fromTokenId          The first token ID minted to the first address in `to`.
     * @param fromTierTokenIdIndex The first token index in the tier.
     */
    event Airdropped(uint8 tier, address[] to, uint256 quantity, uint256 fromTokenId, uint32 fromTierTokenIdIndex);

    /**
     * @dev EIP-4906 event to signal marketplaces to refresh the metadata.
     * @param fromTokenId The starting token ID.
     * @param toTokenId   The ending token ID.
     */
    event BatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId);

    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * @dev The edition's metadata is frozen (e.g.: `baseURI` can no longer be changed).
     */
    error MetadataIsFrozen();

    /**
     * @dev The ability to create tiers is frozen.
     */
    error CreateTierIsFrozen();

    /**
     * @dev The given `royaltyBPS` is invalid.
     */
    error InvalidRoyaltyBPS();

    /**
     * @dev A minimum of one tier must be provided to initialize a Sound Edition.
     */
    error ZeroTiersProvided();

    /**
     * @dev The requested quantity exceeds the edition's remaining mintable token quantity.
     */
    error ExceedsAvailableSupply();

    /**
     * @dev The given `fundingRecipient` address is invalid.
     */
    error InvalidFundingRecipient();

    /**
     * @dev The `maxMintableLower` must not be greater than `maxMintableUpper`.
     */
    error InvalidMaxMintableRange();

    /**
     * @dev The mint has already concluded.
     */
    error MintHasConcluded();

    /**
     * @dev The mint has not concluded.
     */
    error MintNotConcluded();

    /**
     * @dev Cannot perform the operation after a token has been minted.
     */
    error MintsAlreadyExist();

    /**
     * @dev Cannot perform the operation after a token has been minted in the tier.
     */
    error TierMintsAlreadyExist();

    /**
     * @dev The token IDs must be in strictly ascending order.
     */
    error TokenIdsNotStrictlyAscending();

    /**
     * @dev The tier does not exist.
     */
    error TierDoesNotExist();

    /**
     * @dev The tier already exists.
     */
    error TierAlreadyExists();

    /**
     * @dev The tier is frozen.
     */
    error TierIsFrozen();

    /**
     * @dev One of more of the tokens do not have the correct token tier.
     */
    error InvalidTokenTier();

    /**
     * @dev Please wait for a while before you burn.
     */
    error CannotBurnImmediately();

    /**
     * @dev The token for the tier query doesn't exist.
     */
    error TierQueryForNonexistentToken();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Initializes the contract.
     * @param init The initialization struct.
     */
    function initialize(EditionInitialization calldata init) external;

    /**
     * @dev Mints `quantity` tokens to addrress `to`
     *      Each token will be assigned a token ID that is consecutively increasing.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have either the
     *   `ADMIN_ROLE`, `MINTER_ROLE`, which can be granted via {grantRole}.
     *   Multiple minters, such as different minter contracts,
     *   can be authorized simultaneously.
     *
     * @param tier     The tier.
     * @param to       Address to mint to.
     * @param quantity Number of tokens to mint.
     * @return fromTokenId The first token ID minted.
     */
    function mint(
        uint8 tier,
        address to,
        uint256 quantity
    ) external payable returns (uint256 fromTokenId);

    /**
     * @dev Mints `quantity` tokens to each of the addresses in `to`.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the
     *   `ADMIN_ROLE`, which can be granted via {grantRole}.
     *
     * @param tier         The tier.
     * @param to           Address to mint to.
     * @param quantity     Number of tokens to mint.
     * @return fromTokenId The first token ID minted.
     */
    function airdrop(
        uint8 tier,
        address[] calldata to,
        uint256 quantity
    ) external payable returns (uint256 fromTokenId);

    /**
     * @dev Withdraws collected ETH royalties to the fundingRecipient.
     */
    function withdrawETH() external;

    /**
     * @dev Withdraws collected ERC20 royalties to the fundingRecipient.
     * @param tokens array of ERC20 tokens to withdraw
     */
    function withdrawERC20(address[] calldata tokens) external;

    /**
     * @dev Sets metadata module.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param metadataModule Address of metadata module.
     */
    function setMetadataModule(address metadataModule) external;

    /**
     * @dev Sets global base URI.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param baseURI The base URI to be set.
     */
    function setBaseURI(string memory baseURI) external;

    /**
     * @dev Sets contract URI.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param contractURI The contract URI to be set.
     */
    function setContractURI(string memory contractURI) external;

    /**
     * @dev Freezes metadata by preventing any more changes to base URI.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     */
    function freezeMetadata() external;

    /**
     * @dev Freezes the max tier by preventing any more tiers from being added,
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     */
    function freezeCreateTier() external;

    /**
     * @dev Sets funding recipient address.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param fundingRecipient Address to be set as the new funding recipient.
     */
    function setFundingRecipient(address fundingRecipient) external;

    /**
     * @dev Creates a new split wallet via the SplitMain contract, then sets it as the `fundingRecipient`.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param splitMain The address of the SplitMain contract.
     * @param splitData The calldata to forward to the SplitMain contract to create a split.
     * @return split The address of the new split contract.
     */
    function createSplit(address splitMain, bytes calldata splitData) external returns (address split);

    /**
     * @dev Sets royalty amount in bps (basis points).
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param bps The new royalty basis points to be set.
     */
    function setRoyalty(uint16 bps) external;

    /**
     * @dev Freezes the tier.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param tier  The tier.
     */
    function freezeTier(uint8 tier) external;

    /**
     * @dev Sets the edition max mintable range.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param tier  The tier.
     * @param lower The lower limit of the maximum number of tokens that can be minted.
     * @param upper The upper limit of the maximum number of tokens that can be minted.
     */
    function setMaxMintableRange(
        uint8 tier,
        uint32 lower,
        uint32 upper
    ) external;

    /**
     * @dev Sets the timestamp after which, the `editionMaxMintable` drops
     *      from `editionMaxMintableUpper` to `editionMaxMintableLower.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param tier       The tier.
     * @param cutoffTime The timestamp.
     */
    function setCutoffTime(uint8 tier, uint32 cutoffTime) external;

    /**
     * @dev Sets whether the `mintRandomness` is enabled.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param tier    The tier.
     * @param enabled The boolean value.
     */
    function setMintRandomnessEnabled(uint8 tier, bool enabled) external;

    /**
     * @dev Adds a new tier.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param creation The tier creation data.
     */
    function createTier(TierCreation calldata creation) external;

    /**
     * @dev Emits an event to signal to marketplaces to refresh all the metadata.
     */
    function emitAllMetadataUpdate() external;

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev Returns the edition info.
     * @return info The latest value.
     */
    function editionInfo() external view returns (EditionInfo memory info);

    /**
     * @dev Returns the tier info.
     * @param tier The tier.
     * @return info The latest value.
     */
    function tierInfo(uint8 tier) external view returns (TierInfo memory info);

    /**
     * @dev Returns the GA tier, which is 0.
     * @return The constant value.
     */
    function GA_TIER() external pure returns (uint8);

    /**
     * @dev Basis points denominator used in fee calculations.
     * @return The constant value.
     */
    function BPS_DENOMINATOR() external pure returns (uint16);

    /**
     * @dev Returns the minter role flag.
     *      Note: This constant will always be 2 for past and future sound protocol contracts.
     * @return The constant value.
     */
    function MINTER_ROLE() external view returns (uint256);

    /**
     * @dev Returns the admin role flag.
     *      Note: This constant will always be 1 for past and future sound protocol contracts.
     * @return The constant value.
     */
    function ADMIN_ROLE() external view returns (uint256);

    /**
     * @dev Returns the tier of the `tokenId`.
     * @param tokenId The token ID.
     * @return The latest value.
     */
    function tokenTier(uint256 tokenId) external view returns (uint8);

    /**
     * @dev Returns the tier of the `tokenId`.
     *      Note: Will NOT revert if any `tokenId` does not exist.
     *      If the token has not been minted, the tier will be zero.
     *      If the token is burned, the tier will be the tier before it was burned.
     * @param tokenId The token ID.
     * @return The latest value.
     */
    function explicitTokenTier(uint256 tokenId) external view returns (uint8);

    /**
     * @dev Returns the tiers of the `tokenIds`.
     *      Note: Will NOT revert if any `tokenId` does not exist.
     *      If the token has not been minted, the tier will be zero.
     *      If the token is burned, the tier will be the tier before it was burned.
     * @param tokenIds The token IDs.
     * @return The latest values.
     */
    function tokenTiers(uint256[] calldata tokenIds) external view returns (uint8[] memory);

    /**
     * @dev Returns an array of all the token IDs in the tier.
     * @param tier The tier.
     * @return tokenIds The array of token IDs in the tier.
     */
    function tierTokenIds(uint8 tier) external view returns (uint256[] memory tokenIds);

    /**
     * @dev Returns an array of all the token IDs in the tier, within the range [start, stop).
     * @param tier  The tier.
     * @param start The start of the range. Inclusive.
     * @param stop  The end of the range. Exclusive.
     * @return tokenIds The array of token IDs in the tier.
     */
    function tierTokenIdsIn(
        uint8 tier,
        uint256 start,
        uint256 stop
    ) external view returns (uint256[] memory tokenIds);

    /**
     * @dev Returns the index of `tokenId` in it's tier token ID array.
     * @param tokenId The token ID to find.
     * @return The index of `tokenId`. If not found, returns `type(uint256).max`.
     */
    function tierTokenIdIndex(uint256 tokenId) external view returns (uint256);

    /**
     * @dev Returns the maximum amount of tokens mintable for the tier.
     * @param tier The tier.
     * @return The configured value.
     */
    function maxMintable(uint8 tier) external view returns (uint32);

    /**
     * @dev Returns the upper bound for the maximum tokens that can be minted for the tier.
     * @param tier The tier.
     * @return The configured value.
     */
    function maxMintableUpper(uint8 tier) external view returns (uint32);

    /**
     * @dev Returns the lower bound for the maximum tokens that can be minted for the tier.
     * @param tier The tier.
     * @return The configured value.
     */
    function maxMintableLower(uint8 tier) external view returns (uint32);

    /**
     * @dev Returns the timestamp after which `maxMintable` drops from
     *      `maxMintableUpper` to `maxMintableLower`.
     * @param tier The tier.
     * @return The configured value.
     */
    function cutoffTime(uint8 tier) external view returns (uint32);

    /**
     * @dev Returns the number of tokens minted for the tier.
     * @param tier The tier.
     * @return The latest value.
     */
    function tierMinted(uint8 tier) external view returns (uint32);

    /**
     * @dev Returns the mint randomness for the tier.
     * @param tier The tier.
     * @return The latest value.
     */
    function mintRandomness(uint8 tier) external view returns (uint256);

    /**
     * @dev Returns the one-of-one token ID for the tier.
     * @param tier The tier.
     * @return The latest value.
     */
    function mintRandomnessOneOfOne(uint8 tier) external view returns (uint32);

    /**
     * @dev Returns whether the `mintRandomness` has been enabled.
     * @return The configured value.
     */
    function mintRandomnessEnabled(uint8 tier) external view returns (bool);

    /**
     * @dev Returns whether the mint has been concluded for the tier.
     * @param tier The tier.
     * @return The latest value.
     */
    function mintConcluded(uint8 tier) external view returns (bool);

    /**
     * @dev Returns the base token URI for the collection.
     * @return The configured value.
     */
    function baseURI() external view returns (string memory);

    /**
     * @dev Returns the contract URI to be used by Opensea.
     *      See: https://docs.opensea.io/docs/contract-level-metadata
     * @return The configured value.
     */
    function contractURI() external view returns (string memory);

    /**
     * @dev Returns the address of the funding recipient.
     * @return The configured value.
     */
    function fundingRecipient() external view returns (address);

    /**
     * @dev Returns the address of the metadata module.
     * @return The configured value.
     */
    function metadataModule() external view returns (address);

    /**
     * @dev Returns the royalty basis points.
     * @return The configured value.
     */
    function royaltyBPS() external view returns (uint16);

    /**
     * @dev Returns whether the tier is frozen.
     * @return The configured value.
     */
    function isFrozen(uint8 tier) external view returns (bool);

    /**
     * @dev Returns whether the metadata module is frozen.
     * @return The configured value.
     */
    function isMetadataFrozen() external view returns (bool);

    /**
     * @dev Returns whether the ability to create tiers is frozen.
     * @return The configured value.
     */
    function isCreateTierFrozen() external view returns (bool);

    /**
     * @dev Returns the next token ID to be minted.
     * @return The latest value.
     */
    function nextTokenId() external view returns (uint256);

    /**
     * @dev Returns the number of tokens minted by `owner`.
     * @param owner Address to query for number minted.
     * @return The latest value.
     */
    function numberMinted(address owner) external view returns (uint256);

    /**
     * @dev Returns the number of tokens burned by `owner`.
     * @param owner Address to query for number burned.
     * @return The latest value.
     */
    function numberBurned(address owner) external view returns (uint256);

    /**
     * @dev Returns the total amount of tokens minted.
     * @return The latest value.
     */
    function totalMinted() external view returns (uint256);

    /**
     * @dev Returns the total amount of tokens burned.
     * @return The latest value.
     */
    function totalBurned() external view returns (uint256);

    /**
     * @dev Returns the token URI of `tokenId`, but without reverting if
     *      the token does not exist.
     * @return The latest value.
     */
    function explicitTokenURI(uint256 tokenId) external view returns (string memory);

    /**
     * @dev Informs other contracts which interfaces this contract supports.
     *      Required by https://eips.ethereum.org/EIPS/eip-165
     * @param interfaceId The interface id to check.
     * @return Whether the `interfaceId` is supported.
     */
    function supportsInterface(bytes4 interfaceId)
        external
        view
        override(IERC721AUpgradeable, IERC165Upgradeable)
        returns (bool);
}
