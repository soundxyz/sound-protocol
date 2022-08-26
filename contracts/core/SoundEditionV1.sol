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
import { OwnableUpgradeable } from "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { AccessControlUpgradeable } from "openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import { AccessControlEnumerableUpgradeable } from "openzeppelin-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { Clone } from "clones-with-immutable-args/Clone.sol";

import { ISoundEditionV1 } from "./interfaces/ISoundEditionV1.sol";
import { IMetadataModule } from "./interfaces/IMetadataModule.sol";

/**
 * @title SoundEditionV1
 * @notice The Sound Edition contract - a creator-owned, modifiable implementation of ERC721A.
 */
contract SoundEditionV1 is
    ISoundEditionV1,
    Clone,
    ERC721AQueryableUpgradeable,
    ERC721ABurnableUpgradeable,
    OwnableUpgradeable,
    AccessControlEnumerableUpgradeable
{
    // ================================
    // CONSTANTS
    // ================================

    // A role every minter module must have in order to mint new tokens.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    // A role the owner can grant for performing admin actions.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    // Basis points denominator used in fee calculations.
    uint16 internal constant MAX_BPS = 10_000;
    // The interface ID for EIP-2981 (royaltyInfo)
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    // ================================
    // STORAGE
    // ================================

    // The metadata's base URI.
    string public baseURI;
    // The contract URI used by Opensea https://docs.opensea.io/docs/contract-level-metadata.
    string public contractURI;
    // Indicates if the `baseURI` is mutable.
    bool public isMetadataFrozen;
    // The destination for ETH withdrawals.
    address public fundingRecipient;
    // The royalty fee in basis points.
    uint16 public royaltyBPS;
    // The max mintable quantity for the edition.
    uint32 public editionMaxMintable;
    // The token count after which `mintRandomness` gets locked.
    uint32 public mintRandomnessTokenThreshold;
    // The timestamp after which `mintRandomness` gets locked.
    uint32 public mintRandomnessTimeThreshold;
    /**
     * Getter for the previous block hash - stored on each mint unless `mintRandomnessTokenThreshold` or
     * `mintRandomnessTimeThreshold` have been surpassed. Used for game mechanics like the Sound Golden Egg.
     */
    bytes32 public mintRandomness;

    // ================================
    // MODIFIERS
    // ================================

    /**
     * @dev Guards a function against any calls made by an address that isn't the owner or an admin.
     */
    modifier onlyOwnerOrAdmin() {
        if (_msgSender() != owner() && !hasRole(ADMIN_ROLE, _msgSender())) revert Unauthorized();
        _;
    }

    /**
     * @dev Ensures the royalty basis points is a valid value.
     */
    modifier onlyValidRoyaltyBPS(uint16 royalty) {
        if (royalty > MAX_BPS) revert InvalidRoyaltyBPS();
        _;
    }

    // ================================
    // IMMUTABLE ARG FUNCTIONS
    // ================================

    function name() public pure override(ERC721AUpgradeable, IERC721AUpgradeable) returns (string memory) {
        return string(abi.encodePacked(_getArgUint256(0)));
    }

    function symbol() public pure override(ERC721AUpgradeable, IERC721AUpgradeable) returns (string memory) {
        return string(abi.encodePacked(_getArgUint256(0x20)));
    }

    function metadataModule() public pure returns (IMetadataModule) {
        return IMetadataModule(_getArgAddress(0x40));
    }

    // ================================
    // WRITE FUNCTIONS
    // ================================

    /// @inheritdoc ISoundEditionV1
    function initialize(
        address owner,
        string memory baseURI_,
        string memory contractURI_,
        address fundingRecipient_,
        uint16 royaltyBPS_,
        uint32 editionMaxMintable_,
        uint32 mintRandomnessTokenThreshold_,
        uint32 mintRandomnessTimeThreshold_
    ) public initializerERC721A initializer onlyValidRoyaltyBPS(royaltyBPS_) {
        ERC721AStorage.layout()._currentIndex = 1;
        __ERC721AQueryable_init();
        __Ownable_init();

        baseURI = baseURI_;
        contractURI = contractURI_;

        if (fundingRecipient_ == address(0)) revert InvalidFundingRecipient();
        fundingRecipient = fundingRecipient_;

        royaltyBPS = royaltyBPS_;
        editionMaxMintable = editionMaxMintable_ > 0 ? editionMaxMintable_ : type(uint32).max;
        mintRandomnessTokenThreshold = mintRandomnessTokenThreshold_;
        mintRandomnessTimeThreshold = mintRandomnessTimeThreshold_;

        __AccessControl_init();

        // Set ownership to owner
        transferOwnership(owner);

        // Give owner the DEFAULT_ADMIN_ROLE
        _grantRole(DEFAULT_ADMIN_ROLE, owner);

        emit EditionMaxMintableSet(editionMaxMintable);
    }

    /// @inheritdoc ISoundEditionV1
    function mint(address to, uint256 quantity) public payable {
        address caller = _msgSender();
        // Only allow calls if caller has minter role, admin role, or is the owner.
        if (!hasRole(MINTER_ROLE, caller) && !hasRole(ADMIN_ROLE, caller) && caller != owner()) {
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
            mintRandomness = blockhash(block.number - 1);
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

    /// @inheritdoc ISoundEditionV1
    function freezeMetadata() external onlyOwnerOrAdmin {
        if (isMetadataFrozen) revert MetadataIsFrozen();

        isMetadataFrozen = true;
        emit MetadataFrozen(metadataModule(), baseURI, contractURI);
    }

    /// @inheritdoc ISoundEditionV1
    function setFundingRecipient(address fundingRecipient_) external onlyOwnerOrAdmin {
        if (fundingRecipient_ == address(0)) revert InvalidFundingRecipient();
        fundingRecipient = fundingRecipient_;
        emit FundingRecipientSet(fundingRecipient_);
    }

    /// @inheritdoc ISoundEditionV1
    function setRoyalty(uint16 royaltyBPS_) external onlyOwnerOrAdmin onlyValidRoyaltyBPS(royaltyBPS_) {
        royaltyBPS = royaltyBPS_;
        emit RoyaltySet(royaltyBPS_);
    }

    /// @inheritdoc ISoundEditionV1
    function reduceEditionMaxMintable(uint32 newMax) external onlyOwnerOrAdmin {
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
    function setMintRandomnessLock(uint32 mintRandomnessTokenThreshold_) external onlyOwnerOrAdmin {
        if (mintRandomnessTokenThreshold_ < _totalMinted()) revert InvalidRandomnessLock();

        mintRandomnessTokenThreshold = mintRandomnessTokenThreshold_;
    }

    /// @inheritdoc ISoundEditionV1
    function setRandomnessLockedTimestamp(uint32 mintRandomnessTimeThreshold_) external onlyOwnerOrAdmin {
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

        if (address(metadataModule()) != address(0)) {
            return metadataModule().tokenURI(tokenId);
        }

        string memory baseURI_ = baseURI;
        return bytes(baseURI_).length != 0 ? string.concat(baseURI_, _toString(tokenId)) : "";
    }

    /// @inheritdoc ISoundEditionV1
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ISoundEditionV1, ERC721AUpgradeable, IERC721AUpgradeable, AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return
            ERC721AUpgradeable.supportsInterface(interfaceId) ||
            AccessControlEnumerableUpgradeable.supportsInterface(interfaceId) ||
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

    /// @inheritdoc ISoundEditionV1
    function getMembersOfRole(bytes32 role) external view returns (address[] memory members) {
        uint256 count = getRoleMemberCount(role);

        members = new address[](count);

        for (uint256 i = 0; i < count; i++) {
            members[i] = getRoleMember(role, i);
        }
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
}
