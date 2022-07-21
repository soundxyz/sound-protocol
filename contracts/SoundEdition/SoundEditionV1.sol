// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

import "chiru-labs/ERC721A-Upgradeable/extensions/ERC721AQueryableUpgradeable.sol";
import "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "../modules/Metadata/IMetadataModule.sol";
import "openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";

/*
                 ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                
               ▒███████████████████████████████████████████████████████████               
               ▒███████████████████████████████████████████████████████████               
 ▒▓▓▓▓▓▓▓▓▓▓▓▓▓████████████████▓▓▓▓▓▓▓▓▓▓▓▓▓▓██████████████████████████████▓▒▒▒▒▒▒▒▒▒▒▒▒▒ 
 █████████████████████████████▓              ████████████████████████████████████████████ 
 █████████████████████████████▓              ████████████████████████████████████████████ 
 █████████████████████████████▓               ▒▒▒▒▒▒▒▒▒▒▒▒▒██████████████████████████████ 
 █████████████████████████████▓                            ▒█████████████████████████████ 
 █████████████████████████████▓                             ▒████████████████████████████ 
 █████████████████████████████████████████████████████████▓                              
 ███████████████████████████████████████████████████████████                              
 ███████████████████████████████████████████████████████████▒                             
                              ███████████████████████████████████████████████████████████▒
                              ▓██████████████████████████████████████████████████████████▒
                               ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓███████████████████████████████▒
 █████████████████████████████                             ▒█████████████████████████████▒
 ██████████████████████████████                            ▒█████████████████████████████▒
 ██████████████████████████████▓▒▒▒▒▒▒▒▒▒▒▒▒▒              ▒█████████████████████████████▒
 ████████████████████████████████████████████▒             ▒█████████████████████████████▒
 ████████████████████████████████████████████▒             ▒█████████████████████████████▒
 ▒▒▒▒▒▒▒▒▒▒▒▒▒▒███████████████████████████████▓▓▓▓▓▓▓▓▓▓▓▓▓███████████████▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒ 
               ▓██████████████████████████████████████████████████████████▒               
               ▓██████████████████████████████████████████████████████████                
*/

/// @title SoundEditionV1
/// @author Sound.xyz
contract SoundEditionV1 is ERC721AQueryableUpgradeable, IERC2981Upgradeable, OwnableUpgradeable, AccessControlUpgradeable {
    // ================================
    // CONSTANTS
    // ================================
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // ================================
    // STORAGE
    // ================================

    IMetadataModule public metadataModule;
    string internal baseURI;
    string public contractURI;
    bool public isMetadataFrozen;

    // ================================
    // EVENTS & ERRORS
    // ================================

    event MetadataModuleSet(IMetadataModule _metadataModule);
    event BaseURISet(string baseURI_);
    event ContractURISet(string _contractURI);
    event MetadataFrozen(IMetadataModule _metadataModule, string baseURI_, string _contractURI);

    error MetadataIsFrozen();

    // ================================
    // PUBLIC & EXTERNAL WRITABLE FUNCTIONS
    // ================================

    /// @notice Initializes the contract
    /// @param _owner Owner of contract (artist)
    /// @param _name Name of the token
    /// @param _symbol Symbol of the token
    /// @param _metadataModule Address of metadata module, address(0x00) if not used
    /// @param baseURI_ Base URI
    /// @param _contractURI Contract URI for OpenSea storefront
    function initialize(
        address _owner,
        string memory _name,
        string memory _symbol,
        IMetadataModule _metadataModule,
        string memory baseURI_,
        string memory _contractURI
    ) public initializerERC721A initializer {
        __ERC721A_init(_name, _symbol);
        __ERC721AQueryable_init();
        __Ownable_init();

        metadataModule = _metadataModule;
        baseURI = baseURI_;
        contractURI = _contractURI;

        __AccessControl_init();

        // Set ownership to owner
        transferOwnership(_owner);

        // Give owner the DEFAULT_ADMIN_ROLE
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    function setMetadataModule(IMetadataModule _metadataModule) external onlyOwner {
        if (isMetadataFrozen) revert MetadataIsFrozen();
        metadataModule = _metadataModule;

        emit MetadataModuleSet(_metadataModule);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        if (isMetadataFrozen) revert MetadataIsFrozen();
        baseURI = baseURI_;

        emit BaseURISet(baseURI_);
    }

    function setContractURI(string memory _contractURI) external onlyOwner {
        if (isMetadataFrozen) revert MetadataIsFrozen();
        contractURI = _contractURI;

        emit ContractURISet(_contractURI);
    }

    function freezeMetadata() external onlyOwner {
        if (isMetadataFrozen) revert MetadataIsFrozen();

        isMetadataFrozen = true;
        emit MetadataFrozen(metadataModule, baseURI, contractURI);
    }

    // ================================
    // VIEW FUNCTIONS
    // ================================

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721AUpgradeable, IERC721AUpgradeable)
        returns (string memory)
    {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        if (address(metadataModule) != address(0)) {
            return metadataModule.tokenURI(tokenId);
        }

        string memory baseURI_ = baseURI;
        return bytes(baseURI_).length != 0 ? string.concat(baseURI_, _toString(tokenId)) : "";
    }

    /// @notice Informs other contracts which interfaces this contract supports
    /// @param _interfaceId The interface id to check
    /// @dev https://eips.ethereum.org/EIPS/eip-165
    function supportsInterface(bytes4 _interfaceId)
        public
        view
        override(ERC721AUpgradeable, IERC721AUpgradeable, AccessControlUpgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return
            ERC721AUpgradeable.supportsInterface(_interfaceId) ||
            AccessControlUpgradeable.supportsInterface(_interfaceId);
    }

    /// @notice Get royalty information for token
    /// @param _tokenId token id
    /// @param _salePrice Sale price for the token
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        override
        returns (address fundingRecipient, uint256 royaltyAmount)
    {
        // todo
    }

    /// @notice Mints `_quantity` tokens to addrress `_to`
    /// Each token will be assigned a token ID that is consecutively increasing
    /// @param _to Address to mint to
    /// @param _quantity Number of tokens to mint
    function mint(address _to, uint256 _quantity) public payable onlyRole(MINTER_ROLE) {
        _mint(_to, _quantity);
    }
}
