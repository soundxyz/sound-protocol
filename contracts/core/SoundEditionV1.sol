// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

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

import { IERC721AUpgradeable } from "chiru-labs/ERC721A-Upgradeable/IERC721AUpgradeable.sol";
import { ERC721AUpgradeable, ERC721AStorage } from "chiru-labs/ERC721A-Upgradeable/ERC721AUpgradeable.sol";
import { ERC721AQueryableUpgradeable } from "chiru-labs/ERC721A-Upgradeable/extensions/ERC721AQueryableUpgradeable.sol";
import { ERC721ABurnableUpgradeable } from "chiru-labs/ERC721A-Upgradeable/extensions/ERC721ABurnableUpgradeable.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { IERC2981Upgradeable } from "openzeppelin-upgradeable/interfaces/IERC2981Upgradeable.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

import { ISoundEditionV1 } from "./interfaces/ISoundEditionV1.sol";
import { IMetadataModule } from "./interfaces/IMetadataModule.sol";

/**
 * @title SoundEditionV1
 * @notice The Sound Edition contract - a creator-owned, modifiable implementation of ERC721A.
 */
contract SoundEditionV1 is ISoundEditionV1, ERC721AQueryableUpgradeable, ERC721ABurnableUpgradeable, OwnableRoles {
    // ================================
    // CONSTANTS
    // ================================

    // A role every minter module must have in order to mint new tokens.
    uint256 public constant MINTER_ROLE = _ROLE_1;
    // A role the owner can grant for performing admin actions.
    uint256 public constant ADMIN_ROLE = _ROLE_0;
    // Basis points denominator used in fee calculations.
    uint16 internal constant MAX_BPS = 10_000;
    // The interface ID for EIP-2981 (royaltyInfo)
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    // ================================
    // STORAGE
    // ================================

    // The value for `name` and `symbol` if their combined
    // length is (32 - 2) bytes. We need 2 bytes for their lengths.
    bytes32 private _shortNameAndSymbol;
    // The metadata's base URI.
    string public baseURI;
    // The contract URI used by Opensea https://docs.opensea.io/docs/contract-level-metadata.
    string public contractURI;

    // The destination for ETH withdrawals.
    address public fundingRecipient;
    // The max mintable quantity for the edition.
    uint32 public editionMaxMintable;
    // The token count after which `mintRandomness` gets locked.
    uint32 public mintRandomnessTokenThreshold;
    // The timestamp after which `mintRandomness` gets locked.
    uint32 public mintRandomnessTimeThreshold;

    // Metadata module used for `tokenURI` if it is set.
    IMetadataModule public metadataModule;
    /**
     * Getter for the previous block hash - stored on each mint unless `mintRandomnessTokenThreshold` or
     * `mintRandomnessTimeThreshold` have been surpassed. Used for game mechanics like the Sound Golden Egg.
     */
    bytes9 public mintRandomness;
    // The royalty fee in basis points.
    uint16 public royaltyBPS;
    // Indicates if the `baseURI` is mutable.
    bool public isMetadataFrozen;

    // ================================
    // MODIFIERS
    // ================================

    /**
     * @dev Ensures the royalty basis points is a valid value.
     */
    modifier onlyValidRoyaltyBPS(uint16 royalty) {
        if (royalty > MAX_BPS) revert InvalidRoyaltyBPS();
        _;
    }

    // ================================
    // WRITE FUNCTIONS
    // ================================

    /**
     * @dev Initializes the contract
     * @param owner Owner of contract (artist)
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param metadataModule_ Address of metadata module, address(0x00) if not used
     * @param baseURI_ Base URI
     * @param contractURI_ Contract URI for OpenSea storefront
     * @param fundingRecipient_ Address that receives primary and secondary royalties
     * @param royaltyBPS_ Royalty amount in bps (basis points)
     * @param editionMaxMintable_ The maximum amount of tokens that can be minted for this edition.
     * @param mintRandomnessTokenThreshold_ Token supply after which randomness gets locked
     * @param mintRandomnessTimeThreshold_ Timestamp after which randomness gets locked
     */
    function initialize(
        address owner,
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
    ) public onlyValidRoyaltyBPS(royaltyBPS_) {
        // Prevent double initialization.
        // We can "cheat" here and avoid the initializer modifer to save a SSTORE,
        // since the `_nextTokenId()` is defined to always return 1.
        if (_nextTokenId() != 0) revert Unauthorized();

        if (fundingRecipient_ == address(0)) revert InvalidFundingRecipient();

        _initializeNameAndSymbol(name_, symbol_);
        ERC721AStorage.layout()._currentIndex = _startTokenId();

        _initializeOwner(owner);

        baseURI = baseURI_;
        contractURI = contractURI_;

        fundingRecipient = fundingRecipient_;
        editionMaxMintable = editionMaxMintable_ > 0 ? editionMaxMintable_ : type(uint32).max;
        mintRandomnessTokenThreshold = mintRandomnessTokenThreshold_;
        mintRandomnessTimeThreshold = mintRandomnessTimeThreshold_;

        metadataModule = metadataModule_;
        royaltyBPS = royaltyBPS_;

        emit EditionMaxMintableSet(editionMaxMintable);
    }

    /**
     * @dev Mints `quantity` tokens to addrress `to`
     * Each token will be assigned a token ID that is consecutively increasing.
     * The caller must have the `MINTERROLE`, which can be granted via
     * {grantRole}. Multiple minters, such as different minter contracts,
     * can be authorized simultaneously.
     * @param to Address to mint to
     * @param quantity Number of tokens to mint
     */
    function mint(address to, uint256 quantity) public payable {
        address caller = msg.sender;
        // Only allow calls if caller has minter role, admin role, or is the owner.
        if (!hasAnyRole(caller, MINTER_ROLE | ADMIN_ROLE) && caller != owner()) {
            revert Unauthorized();
        }
        // Check if there are enough tokens to mint.
        if (_totalMinted() + quantity > editionMaxMintable) {
            uint256 available = editionMaxMintable - _totalMinted();
            revert ExceedsEditionAvailableSupply(uint32(available));
        }
        // Mint the tokens.
        _mint(to, quantity);
        // Set randomness
        if (_totalMinted() <= mintRandomnessTokenThreshold && block.timestamp <= mintRandomnessTimeThreshold) {
            mintRandomness = bytes9(blockhash(block.number - 1));
        }
    }

    /// @inheritdoc ISoundEditionV1
    function withdrawETH() external {
        SafeTransferLib.safeTransferETH(fundingRecipient, address(this).balance);
    }

    /// @inheritdoc ISoundEditionV1
    function withdrawERC20(address[] calldata tokens) external {
        for (uint256 i; i < tokens.length; ++i) {
            SafeTransferLib.safeTransfer(tokens[i], fundingRecipient, IERC20(tokens[i]).balanceOf(address(this)));
        }
    }

    /// @inheritdoc ISoundEditionV1
    function setMetadataModule(IMetadataModule metadataModule_) external onlyRolesOrOwner(ADMIN_ROLE) {
        if (isMetadataFrozen) revert MetadataIsFrozen();
        metadataModule = metadataModule_;

        emit MetadataModuleSet(metadataModule_);
    }

    /// @inheritdoc ISoundEditionV1
    function setBaseURI(string memory baseURI_) external onlyRolesOrOwner(ADMIN_ROLE) {
        if (isMetadataFrozen) revert MetadataIsFrozen();
        baseURI = baseURI_;

        emit BaseURISet(baseURI_);
    }

    /// @inheritdoc ISoundEditionV1
    function setContractURI(string memory contractURI_) external onlyRolesOrOwner(ADMIN_ROLE) {
        if (isMetadataFrozen) revert MetadataIsFrozen();
        contractURI = contractURI_;

        emit ContractURISet(contractURI_);
    }

    /// @inheritdoc ISoundEditionV1
    function freezeMetadata() external onlyRolesOrOwner(ADMIN_ROLE) {
        if (isMetadataFrozen) revert MetadataIsFrozen();

        isMetadataFrozen = true;
        emit MetadataFrozen(metadataModule, baseURI, contractURI);
    }

    /// @inheritdoc ISoundEditionV1
    function setFundingRecipient(address fundingRecipient_) external onlyRolesOrOwner(ADMIN_ROLE) {
        if (fundingRecipient_ == address(0)) revert InvalidFundingRecipient();
        fundingRecipient = fundingRecipient_;
        emit FundingRecipientSet(fundingRecipient_);
    }

    /// @inheritdoc ISoundEditionV1
    function setRoyalty(uint16 royaltyBPS_) external onlyRolesOrOwner(ADMIN_ROLE) onlyValidRoyaltyBPS(royaltyBPS_) {
        royaltyBPS = royaltyBPS_;
        emit RoyaltySet(royaltyBPS_);
    }

    /// @inheritdoc ISoundEditionV1
    function reduceEditionMaxMintable(uint32 newMax) external onlyRolesOrOwner(ADMIN_ROLE) {
        if (_totalMinted() == editionMaxMintable) {
            revert MaximumHasAlreadyBeenReached();
        }

        // Only allow reducing below current max.
        if (newMax >= editionMaxMintable) {
            revert InvalidAmount();
        }

        // If attempting to set below current total minted, set it to current total.
        // Otherwise, set it to the provided value.
        if (newMax < _totalMinted()) {
            editionMaxMintable = uint32(_totalMinted());
        } else {
            editionMaxMintable = newMax;
        }

        emit EditionMaxMintableSet(editionMaxMintable);
    }

    /// @inheritdoc ISoundEditionV1
    function setMintRandomnessLock(uint32 mintRandomnessTokenThreshold_) external onlyRolesOrOwner(ADMIN_ROLE) {
        if (mintRandomnessTokenThreshold_ < _totalMinted()) revert InvalidRandomnessLock();

        mintRandomnessTokenThreshold = mintRandomnessTokenThreshold_;
    }

    /// @inheritdoc ISoundEditionV1
    function setRandomnessLockedTimestamp(uint32 mintRandomnessTimeThreshold_) external onlyRolesOrOwner(ADMIN_ROLE) {
        mintRandomnessTimeThreshold = mintRandomnessTimeThreshold_;
    }

    // ================================
    // VIEW FUNCTIONS
    // ================================

    /// @inheritdoc ISoundEditionV1
    function totalMinted() external view returns (uint256) {
        return _totalMinted();
    }

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
        override(ISoundEditionV1, ERC721AUpgradeable, IERC721AUpgradeable)
        returns (bool)
    {
        return
            interfaceId == type(ISoundEditionV1).interfaceId ||
            ERC721AUpgradeable.supportsInterface(interfaceId) ||
            interfaceId == _INTERFACE_ID_ERC2981;
    }

    /// @inheritdoc IERC2981Upgradeable
    function royaltyInfo(
        uint256, // tokenId
        uint256 salePrice
    ) external view override(IERC2981Upgradeable) returns (address fundingRecipient_, uint256 royaltyAmount) {
        fundingRecipient_ = fundingRecipient;
        royaltyAmount = (salePrice * royaltyBPS) / MAX_BPS;
    }

    /// @inheritdoc IERC721AUpgradeable
    function name() public view override(ERC721AUpgradeable, IERC721AUpgradeable) returns (string memory) {
        (string memory name_, ) = _loadNameAndSymbol();
        return name_;
    }

    /// @inheritdoc IERC721AUpgradeable
    function symbol() public view override(ERC721AUpgradeable, IERC721AUpgradeable) returns (string memory) {
        (, string memory symbol_) = _loadNameAndSymbol();
        return symbol_;
    }

    // ================================
    // FALLBACK FUNCTIONS
    // ================================

    /**
     * @dev receive secondary royalties
     */
    receive() external payable {}

    // ================================
    // INTERNAL FUNCTIONS
    // ================================

    /// @inheritdoc ERC721AUpgradeable
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    /**
     * @dev Helper function for initializing the name and symbol,
     * packing them into a single word if possible.
     */
    function _initializeNameAndSymbol(string memory name_, string memory symbol_) internal {
        uint256 nameLength = bytes(name_).length;
        uint256 symbolLength = bytes(symbol_).length;
        uint256 totalLength = nameLength + symbolLength;

        if (totalLength > 30) {
            ERC721AStorage.layout()._name = name_;
            ERC721AStorage.layout()._symbol = symbol_;
            return;
        }

        _shortNameAndSymbol = bytes32(abi.encodePacked(uint8(nameLength), name_, uint8(symbolLength), symbol_));
    }

    /**
     * @dev Helper function for retrieving the name and symbol,
     * unpacking them from a single word in storage if previously packed.
     */
    function _loadNameAndSymbol() internal view returns (string memory name_, string memory symbol_) {
        // Overflow impossible since all bytes are small.
        unchecked {
            bytes32 packed = _shortNameAndSymbol;
            if (packed != bytes32(0)) {
                // Get the lengths.
                uint256 nameLength = uint256(uint8(packed[0]));
                uint256 symbolLength = uint256(uint8(packed[1 + nameLength]));
                // Allocate the bytes.
                bytes memory nameBytes = new bytes(nameLength);
                bytes memory symbolBytes = new bytes(symbolLength);
                // Copy the bytes.
                for (uint256 i; i < nameLength; ++i) {
                    nameBytes[i] = bytes1(packed[1 + i]);
                }
                for (uint256 i; i < symbolLength; ++i) {
                    symbolBytes[i] = bytes1(packed[2 + nameLength + i]);
                }
                // Cast the bytes.
                name_ = string(nameBytes);
                symbol_ = string(symbolBytes);
            } else {
                name_ = ERC721AStorage.layout()._name;
                symbol_ = ERC721AStorage.layout()._symbol;
            }
        }
    }
}
