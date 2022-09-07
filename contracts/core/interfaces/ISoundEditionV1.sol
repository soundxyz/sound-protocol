// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IERC721AUpgradeable } from "chiru-labs/ERC721A-Upgradeable/IERC721AUpgradeable.sol";
import { IERC2981Upgradeable } from "openzeppelin-upgradeable/interfaces/IERC2981Upgradeable.sol";
import { IERC165Upgradeable } from "openzeppelin-upgradeable/utils/introspection/IERC165Upgradeable.sol";

import { IMetadataModule } from "./IMetadataModule.sol";

/**
 * @title ISoundEditionV1
 * @notice The interface for Sound edition contracts.
 */
interface ISoundEditionV1 is IERC721AUpgradeable, IERC2981Upgradeable {
    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when the metadata module is set.
     * @param metadataModule the address of the metadata module.
     */
    event MetadataModuleSet(IMetadataModule metadataModule);

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
    event MetadataFrozen(IMetadataModule metadataModule, string baseURI, string contractURI);

    /**
     * @dev Emitted when the `fundingRecipient` is set.
     * @param fundingRecipient The address of the funding recipient.
     */
    event FundingRecipientSet(address fundingRecipient);

    /**
     * @dev Emitted when the `royaltyBPS` is set.
     * @param bps The new royalty, measured in basis points.
     */
    event RoyaltySet(uint16 bps);

    /**
     * @dev Emitted when the edition's maximum mintable token quantity is set.
     * @param newMax The new maximum mintable token quantity.
     */
    event EditionMaxMintableSet(uint32 newMax);

    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * @dev The edition's metadata is frozen (e.g.: `baseURI` can no longer be changed).
     */
    error MetadataIsFrozen();

    /**
     * @dev The given `royaltyBPS` is invalid.
     */
    error InvalidRoyaltyBPS();

    /**
     * @dev The given `randomnessLockedAfterMinted` value is invalid.
     */
    error InvalidRandomnessLock();

    /**
     * @dev The requested quantity exceeds the edition's remaining mintable token quantity.
     * @param available The number of tokens remaining available for mint.
     */
    error ExceedsEditionAvailableSupply(uint32 available);

    /**
     * @dev The given amount is invalid.
     */
    error InvalidAmount();

    /**
     * @dev The given `fundingRecipient` address is invalid.
     */
    error InvalidFundingRecipient();

    /**
     * @dev The `editionMaxMintable` has already been reached.
     */
    error MaximumHasAlreadyBeenReached();

    /**
     * @dev The mint `quantity` cannot exceed `ADDRESS_BATCH_MINT_LIMIT` tokens.
     */
    error ExceedsAddressBatchMintLimit();

    /**
     * @dev The mint randomness has already been revealed.
     */
    error MintRandomnessAlreadyRevealed();

    /**
     * @dev No addresses to airdrop.
     */
    error NoAddressesToAirdrop();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Initializes the contract.
     * @param name_                         Name of the collection.
     * @param symbol_                       Symbol of the collection.
     * @param metadataModule_               Address of metadata module, address(0x00) if not used.
     * @param baseURI_                      Base URI.
     * @param contractURI_                  Contract URI for OpenSea storefront.
     * @param fundingRecipient_             Address that receives primary and secondary royalties.
     * @param royaltyBPS_                   Royalty amount in bps (basis points).
     * @param editionMaxMintable_           The maximum amount of tokens mintable for this edition.
     * @param mintRandomnessTokenThreshold_ Token supply after which randomness gets locked.
     * @param mintRandomnessTimeThreshold_  Timestamp after which randomness gets locked.
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        IMetadataModule metadataModule_,
        string memory baseURI_,
        string memory contractURI_,
        address fundingRecipient_,
        uint16 royaltyBPS_,
        uint32 editionMaxMintable_,
        uint32 mintRandomnessTokenThreshold_,
        uint32 mintRandomnessTimeThreshold_
    ) external;

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
     * @param to       Address to mint to.
     * @param quantity Number of tokens to mint.
     * @return fromTokenId The first token ID minted.
     */
    function mint(address to, uint256 quantity) external payable returns (uint256 fromTokenId);

    /**
     * @dev Mints `quantity` tokens to each of the addresses in `to`.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the
     *   `ADMIN_ROLE`, which can be granted via {grantRole}.
     *
     * @param to       Address to mint to.
     * @param quantity Number of tokens to mint.
     * @return fromTokenId The first token ID minted.
     */
    function airdrop(address[] calldata to, uint256 quantity) external returns (uint256 fromTokenId);

    /**
     * @dev Withdraws collected ETH royalties to the fundingRecipient
     */
    function withdrawETH() external;

    /**
     * @dev Withdraws collected ERC20 royalties to the fundingRecipient
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
    function setMetadataModule(IMetadataModule metadataModule) external;

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
     * @dev Sets funding recipient address.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param fundingRecipient Address to be set as the new funding recipient.
     */
    function setFundingRecipient(address fundingRecipient) external;

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
     * @dev Reduces the maximum mintable quantity for the edition.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param newMax The maximum mintable quantity to be set.
     */
    function reduceEditionMaxMintable(uint32 newMax) external;

    /**
     * @dev Sets a minted token count, after which `mintRandomness` gets locked.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param mintRandomnessTokenThreshold The token quantity to be set.
     */
    function setMintRandomnessTokenThreshold(uint32 mintRandomnessTokenThreshold) external;

    /**
     * @dev Sets the timestamp, after which `mintRandomness` gets locked.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param mintRandomnessTimeThreshold_ The randomness timestamp to be set.
     */
    function setRandomnessTimeThreshold(uint32 mintRandomnessTimeThreshold_) external;

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev Returns the minter role flag.
     * @return The constant value.
     */
    function MINTER_ROLE() external view returns (uint256);

    /**
     * @dev Returns the admin role flag.
     * @return The constant value.
     */
    function ADMIN_ROLE() external view returns (uint256);

    /**
     * @dev Returns the maximum limit for the mint or airdrop `quantity`.
     *      Prevents the first-time transfer costs for tokens near the end of large mint batches
     *      via ERC721A from becoming too expensive due to the need to scan many storage slots.
     *      See: https://chiru-labs.github.io/ERC721A/#/tips?id=batch-size
     * @return The constant value.
     */
    function ADDRESS_BATCH_MINT_LIMIT() external pure returns (uint256);

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
     * @dev Returns the maximum amount of tokens mintable for this edition.
     * @return The configured value.
     */
    function editionMaxMintable() external view returns (uint32);

    /**
     * @dev Returns the token count after which `mintRandomness` gets locked.
     *      See {mintRandomnessRevealed} for the reveal condition.
     * @return The configured value.
     */
    function mintRandomnessTokenThreshold() external view returns (uint32);

    /**
     * @dev Returns the timestamp after which `mintRandomness` gets locked.
     *      See {mintRandomnessRevealed} for the reveal condition.
     * @return The configured value.
     */
    function mintRandomnessTimeThreshold() external view returns (uint32);

    /**
     * @dev Returns the address of the metadata module.
     * @return The configured value.
     */
    function metadataModule() external view returns (IMetadataModule);

    /**
     * @dev Returns the randomness based on latest block hash, which is stored upon each mint.
     *      unless {mintRandomnessRevealed} is true.
     *      Used for game mechanics like the Sound Golden Egg.
     *      Returns 0 before revealed.
     *      WARNING: The mint randomness should NOT be used for any reward of significant monetary
     *      value, due to it being computed via a purely on-chain psuedorandom mechanism.
     * @return The latest value.
     */
    function mintRandomness() external view returns (uint256);

    /**
     * @dev Returns whether the `mintRandomness` has been locked and revealed.
     * @return The latest value.
     */
    function mintRandomnessRevealed() external view returns (bool);

    /**
     * @dev Returns the royalty basis points.
     * @return The configured value.
     */
    function royaltyBPS() external view returns (uint16);

    /**
     * @dev Returns whether the metadata module is frozen.
     * @return The configured value.
     */
    function isMetadataFrozen() external view returns (bool);

    /**
     * @dev Returns the next token ID to be minted.
     * @return The latest value.
     */
    function nextTokenId() external view returns (uint256);

    /**
     * @dev Returns the total amount of tokens minted.
     * @return The latest value.
     */
    function totalMinted() external view returns (uint256);

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
