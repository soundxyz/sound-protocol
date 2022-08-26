// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IERC721AUpgradeable } from "chiru-labs/ERC721A-Upgradeable/IERC721AUpgradeable.sol";
import { IERC2981Upgradeable } from "openzeppelin-upgradeable/interfaces/IERC2981Upgradeable.sol";
import { IERC165Upgradeable } from "openzeppelin-upgradeable/interfaces/IERC165Upgradeable.sol";

import { IMetadataModule } from "./IMetadataModule.sol";

/**
 * @title ISoundEditionV1
 * @notice The interface for Sound edition contracts.
 */
interface ISoundEditionV1 is IERC721AUpgradeable, IERC2981Upgradeable {
    // ================================
    // EVENTS
    // ================================

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
     * @param baseURI The base URI of the edition.
     * @param contractURI The contract URI of the edition.
     */
    event MetadataFrozen(IMetadataModule metadataModule, string baseURI, string contractURI);

    /**
     * @dev Emitted when the `fundingRecipient` is set.
     * @param fundingRecipient The address of the funding recipient.
     */
    event FundingRecipientSet(address fundingRecipient);

    /**
     * @dev Emitted when the `royaltyBPS` is set.
     * @param royaltyBPS The new royalty, measured in basis points.
     */
    event RoyaltySet(uint16 royaltyBPS);

    /**
     * @dev Emitted when the edition's maximum mintable token quantity is set.
     * @param newMax The new maximum mintable token quantity.
     */
    event EditionMaxMintableSet(uint32 newMax);

    // ================================
    // ERRORS
    // ================================

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

    // ================================
    // WRITE FUNCTIONS
    // ================================

    /**
     * @dev Initializes the contract
     * @param owner Owner of contract (artist).
     * @param name Name of the token.
     * @param symbol Symbol of the token.
     * @param metadataModule Address of metadata module, address(0x00) if not used.
     * @param baseURI Base URI.
     * @param contractURI Contract URI for OpenSea storefront.
     * @param fundingRecipient Address that receives primary and secondary royalties.
     * @param royaltyBPS Royalty amount in bps (basis points).
     * @param editionMaxMintable The maximum amount of tokens that can be minted for this edition.
     * @param mintRandomnessTokenThreshold Minted token count after which randomness gets locked.
     * @param mintRandomnessTimeThreshold after which randomness gets locked.
     */
    function initialize(
        address owner,
        string memory name,
        string memory symbol,
        IMetadataModule metadataModule,
        string memory baseURI,
        string memory contractURI,
        address fundingRecipient,
        uint16 royaltyBPS,
        uint32 editionMaxMintable,
        uint32 mintRandomnessTokenThreshold,
        uint32 mintRandomnessTimeThreshold
    ) external;

    /**
     * @dev Mints `quantity` tokens to addrress `to`.
     *      Each token will be assigned a token ID that is consecutively increasing.
     *      The caller must have the `MINTERROLE`, which can be granted via
     *      {grantRole}. Multiple minters, such as different minter contracts,
     *      can be authorized simultaneously.
     * @param to Address to mint to
     * @param quantity Number of tokens to mint
     */
    function mint(address to, uint256 quantity) external payable;

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
     * @param metadataModule Address of metadata module.
     */
    function setMetadataModule(IMetadataModule metadataModule) external;

    /**
     * @dev Sets global base URI.
     * @param baseURI The base URI to be set.
     */
    function setBaseURI(string memory baseURI) external;

    /**
     * @dev Sets contract URI.
     * @param contractURI The contract URI to be set.
     */
    function setContractURI(string memory contractURI) external;

    /**
     * @dev Freezes metadata by preventing any more changes to base URI.
     */
    function freezeMetadata() external;

    /**
     * @dev Sets funding recipient address.
     * @param fundingRecipient Address to be set as the new funding recipient.
     */
    function setFundingRecipient(address fundingRecipient) external;

    /**
     * @dev Sets royalty amount in bps (basis points).
     * @param royaltyBPS The new royalty to be set.
     */
    function setRoyalty(uint16 royaltyBPS) external;

    /**
     * @dev Reduces the maximum mintable quantity for the edition.
     * @param newMax The maximum mintable quantity to be set.
     */
    function reduceEditionMaxMintable(uint32 newMax) external;

    /**
     * @dev Sets a minted token count, after which `mintRandomness` gets locked.
     * @param mintRandomnessTokenThreshold The token quantity to be set.
     */
    function setMintRandomnessLock(uint32 mintRandomnessTokenThreshold) external;

    /**
     * @dev Sets the timestamp, after which `mintRandomness` gets locked.
     * @param mintRandomnessTimeThreshold_ The randomness timestamp to be set.
     */
    function setRandomnessLockedTimestamp(uint32 mintRandomnessTimeThreshold_) external;

    // ================================
    // VIEW FUNCTIONS
    // ================================

    /**
     * @dev Getter for minter role flag.
     * @return The minter role flag.
     */
    function MINTER_ROLE() external view returns (uint256);

    /**
     * @dev Getter for admin role flag.
     * @return The admin role flag.
     */
    function ADMIN_ROLE() external view returns (uint256);

    /**
     * @dev Getter for the base token URI for the collection
     */
    function baseURI() external view returns (string memory);

    /**
     * @dev Getter for the total amount of tokens minted for the edition.
     * @return The total amount of tokens minted.
     */
    function totalMinted() external view returns (uint256);

    /**
     * @dev Getter for the token count after which randomness gets locked.
     * @return The token count after which randomness gets locked.
     */
    function mintRandomnessTokenThreshold() external view returns (uint32);

    /**
     * @dev Getter for the timestamp after which randomness gets locked.
     * @return The timestamp after which randomness gets locked.
     */
    function mintRandomnessTimeThreshold() external view returns (uint32);

    /**
     * Getter for the latest block hash, which is stored on each mint unless `randomnessLockedAfterMinted`
     * or `randomnessLockedTimestamp` have been surpassed. Used for game mechanics like the Sound Golden Egg.
     * @return The latest block hash.
     */
    function mintRandomness() external view returns (bytes32);

    /**
     * @dev Informs other contracts which interfaces this contract supports.
     *      Required by https://eips.ethereum.org/EIPS/eip-165
     * @param interfaceId The interface id to check.
     * @return True if the interface is supported, false otherwise.
     */
    function supportsInterface(bytes4 interfaceId)
        external
        view
        override(IERC721AUpgradeable, IERC165Upgradeable)
        returns (bool);
}
