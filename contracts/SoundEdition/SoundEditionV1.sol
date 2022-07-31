// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

import "chiru-labs/ERC721A-Upgradeable/extensions/ERC721AQueryableUpgradeable.sol";
import "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import "./ISoundEditionV1.sol";
import "../modules/Metadata/IMetadataModule.sol";
import "openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";

import "forge-std/Test.sol";

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

    // ================================
    // STORAGE
    // ================================

    IMetadataModule public metadataModule;
    string internal baseURI;
    string public contractURI;
    bool public isMetadataFrozen;

    // Recovery address
    address public guardian;

    // ================================
    // EVENTS & ERRORS
    // ================================

    event MetadataModuleSet(IMetadataModule metadataModule);
    event BaseURISet(string baseURI);
    event ContractURISet(string contractURI);
    event MetadataFrozen(IMetadataModule metadataModule, string baseURI, string contractURI);
    event GuardianSet(address indexed guardian);

    error MetadataIsFrozen();
    error GuardianAlreadySet();
    error Unauthorized();

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
        string memory contractURI_
    ) public initializerERC721A initializer {
        __ERC721A_init(name, symbol);
        __ERC721AQueryable_init();
        __Ownable_init();

        metadataModule = metadataModule_;
        baseURI = baseURI_;
        contractURI = contractURI_;

        __AccessControl_init();

        // Set ownership to owner
        transferOwnership(owner);

        // Give owner the DEFAULT_ADMIN_ROLE
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
    }

    /// @inheritdoc ISoundEditionV1
    function setMetadataModule(IMetadataModule metadataModule_) external onlyOwner {
        if (isMetadataFrozen) revert MetadataIsFrozen();
        metadataModule = metadataModule_;

        emit MetadataModuleSet(metadataModule_);
    }

    /// @inheritdoc ISoundEditionV1
    function setBaseURI(string memory baseURI_) external onlyOwner {
        if (isMetadataFrozen) revert MetadataIsFrozen();
        baseURI = baseURI_;

        emit BaseURISet(baseURI_);
    }

    /// @inheritdoc ISoundEditionV1
    function setContractURI(string memory contractURI_) external onlyOwner {
        if (isMetadataFrozen) revert MetadataIsFrozen();
        contractURI = contractURI_;

        emit ContractURISet(contractURI_);
    }

    /// @inheritdoc ISoundEditionV1
    function freezeMetadata() external onlyOwner {
        if (isMetadataFrozen) revert MetadataIsFrozen();

        isMetadataFrozen = true;
        emit MetadataFrozen(metadataModule, baseURI, contractURI);
    }

    /*  
        Authenticity:
        - If edition creation is permissionless, a fraudster pretending to be a sound.xyz artist can deploy an edition
            and post the editions for sale on secondary markets. Opensea has been grappling with this for awhile and 
            has a lot of systems in place to mitigate it. 
        - We can only guarantee the legitimacy of artist and edition addresses on sound.xyz. 
        - Signature verification is not required. We can serve these lists from our API for any third parties. 
       
        Edition ownership recovery in the event of lost or compromised artist wallet:
        - If an artist builds a big collector base & their wallet is lost or stolen, it could severely damage their income.
        - Currently, the Sound multisig fulfills the guardian role for ownership recovery.
        - For edition creation to become permissionless while still protecting artists from wallet loss or theft, artists need to be
          able to choose their own guardian. 
        - A single guardian address is still weak security because the guardian wallet could be compromised.
        - Recommended solution:
          - In the near term, inform artists of the risks and encourage them to set up a multisig as the guardian address. In the long term,
            build the UI to make it possible to do all from sound.xyz rather than sending artists to gnosis. 
    */

    /// @notice Enables owner to set a guardian for ownership recovery.
    /// @param newGuardian Address of guardian.
    function setGuardian(address newGuardian) public onlyOwner {
        //  Owner can only set a guardian if one isn't already set.
        if (guardian != address(0)) revert GuardianAlreadySet();

        guardian = newGuardian;

        emit GuardianSet(newGuardian);
    }

    /// @notice Enables current guardian to relinquish the guardianship role.
    function relinquishGuardianship() external onlyGuardian {
        guardian = address(0);

        emit GuardianSet(address(0));
    }

    /// @notice Enables the guardian to transfer ownership of the contract to a new address.
    /// @param newOwner The new owner of this contract.
    function recoverOwnership(address newOwner) external onlyGuardian {
        transferOwnership(newOwner);
    }

    // ================================
    // MODIFIERS
    // ================================

    modifier onlyGuardian() {
        if (msg.sender != guardian) revert Unauthorized();
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

    /// @inheritdoc ISoundEditionV1
    function mint(address to, uint256 quantity) public payable onlyRole(MINTER_ROLE) {
        _mint(to, quantity);
    }
}
