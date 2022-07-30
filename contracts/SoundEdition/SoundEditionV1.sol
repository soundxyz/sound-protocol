// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

import "chiru-labs/ERC721A-Upgradeable/extensions/ERC721AQueryableUpgradeable.sol";
import "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import "./ISoundEditionV1.sol";
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
contract SoundEditionV1 is ISoundEditionV1, ERC721AQueryableUpgradeable, OwnableUpgradeable, AccessControlUpgradeable {
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

    /// @inheritdoc ISoundEditionV1
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

    /// @inheritdoc IERC721AUpgradeable
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

    /// @inheritdoc ISoundEditionV1
    function supportsInterface(bytes4 _interfaceId)
        public
        view
        override(ISoundEditionV1, ERC721AUpgradeable, IERC721AUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return
            ERC721AUpgradeable.supportsInterface(_interfaceId) ||
            AccessControlUpgradeable.supportsInterface(_interfaceId);
    }

    /// @inheritdoc IERC2981Upgradeable
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        override(IERC2981Upgradeable)
        returns (address fundingRecipient, uint256 royaltyAmount)
    {
        // todo
    }

    /// @inheritdoc ISoundEditionV1
    function mint(address _to, uint256 _quantity) public payable onlyRole(MINTER_ROLE) {
        _mint(_to, _quantity);
    }
}
