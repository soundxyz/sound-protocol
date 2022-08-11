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

/**
 * @title SoundEditionV1
 * @author Sound.xyz
 */
contract SoundEditionV1 is ISoundEditionV1, ERC721AQueryableUpgradeable, OwnableUpgradeable, AccessControlUpgradeable {
    // ================================
    // CONSTANTS
    // ================================
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // ================================
    // STORAGE
    // ================================

    uint32 public maxSupply;
    IMetadataModule public metadataModule;
    string internal baseURI;
    string public contractURI;
    bool public isMetadataFrozen;
    uint32 public masterMaxMintable;

    // ================================
    // EVENTS
    // ================================

    event MetadataModuleSet(IMetadataModule metadataModule);
    event BaseURISet(string baseURI);
    event ContractURISet(string contractURI);
    event MetadataFrozen(IMetadataModule metadataModule, string baseURI, string contractURI);
    event MasterMaxMintableSet(uint32 masterMaxMintable);

    // ================================
    // ERRORS
    // ================================

    error MetadataIsFrozen();
    error Unauthorized();
    error MaxSupplyReached();
    error InvalidAmount();

    // ================================
    // PUBLIC & EXTERNAL WRITABLE FUNCTIONS
    // ================================

    /// @inheritdoc ISoundEditionV1
    function initialize(
        address owner,
        string memory name,
        string memory symbol,
        IMetadataModule metadataModule_,
        string memory baseURI_,
        string memory contractURI_,
        uint32 masterMaxMintable_
    ) public initializerERC721A initializer {
        __ERC721A_init(name, symbol);
        __ERC721AQueryable_init();
        __Ownable_init();

        metadataModule = metadataModule_;
        baseURI = baseURI_;
        contractURI = contractURI_;
        masterMaxMintable = masterMaxMintable_ > 0 ? masterMaxMintable_ : type(uint32).max;

        __AccessControl_init();

        // Set ownership to owner
        transferOwnership(owner);

        // Give owner the DEFAULT_ADMIN_ROLE
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
    }

    /// @inheritdoc ISoundEditionV1
    function setMetadataModule(IMetadataModule metadataModule_) external onlyOwnerOrAdmin {
        if (isMetadataFrozen) revert MetadataIsFrozen();
        metadataModule = metadataModule_;

        emit MetadataModuleSet(metadataModule_);
    }

    function setBaseURI(string memory baseURI_) external onlyOwnerOrAdmin {
        if (isMetadataFrozen) revert MetadataIsFrozen();
        baseURI = baseURI_;

        emit BaseURISet(baseURI_);
    }

    /// @inheritdoc ISoundEditionV1
    function setContractURI(string memory contractURI_) external onlyOwnerOrAdmin {
        if (isMetadataFrozen) revert MetadataIsFrozen();
        contractURI = contractURI_;

        emit ContractURISet(contractURI_);
    }

    function freezeMetadata() external onlyOwnerOrAdmin {
        if (isMetadataFrozen) revert MetadataIsFrozen();

        isMetadataFrozen = true;
        emit MetadataFrozen(metadataModule, baseURI, contractURI);
    }

    /// @inheritdoc ISoundEditionV1
    function mint(address to, uint256 quantity) public payable {
        address caller = _msgSender();
        // Only allow calls if caller has minter role, admin role, or is the owner.
        if (!hasRole(MINTER_ROLE, caller) && !hasRole(ADMIN_ROLE, caller) && caller != owner()) revert Unauthorized();
        // Check if max supply has been reached.
        if (_totalMinted() + quantity > masterMaxMintable) revert MaxSupplyReached();

        _mint(to, quantity);
    }

    /// @inheritdoc ISoundEditionV1
    function setMaxMintable(uint32 newMaxMintable) public onlyOwnerOrAdmin {
        if (newMaxMintable > masterMaxMintable) revert InvalidAmount();

        masterMaxMintable = newMaxMintable;

        emit MasterMaxMintableSet(newMaxMintable);
    }

    // ================================
    // MODIFIERS
    // ================================

    modifier onlyOwnerOrAdmin() {
        if (_msgSender() != owner() && !hasRole(ADMIN_ROLE, _msgSender())) revert Unauthorized();
        _;
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
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ISoundEditionV1, ERC721AUpgradeable, IERC721AUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return
            ERC721AUpgradeable.supportsInterface(interfaceId) ||
            AccessControlUpgradeable.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC2981Upgradeable
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override(IERC2981Upgradeable)
        returns (address fundingRecipient, uint256 royaltyAmount)
    {
        // todo
    }
}
