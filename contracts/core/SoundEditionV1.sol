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
    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /**
     * @dev A role every minter module must have in order to mint new tokens.
     */
    uint256 public constant MINTER_ROLE = _ROLE_1;

    /**
     * @dev A role the owner can grant for performing admin actions.
     */
    uint256 public constant ADMIN_ROLE = _ROLE_0;

    /**
     * @dev The maximum limit for the mint or airdrop `quantity`.
     *      Prevents the first-time transfer costs for tokens near the end of large mint batches
     *      via ERC721A from becoming too expensive due to the need to scan many storage slots.
     *      See: https://chiru-labs.github.io/ERC721A/#/tips?id=batch-size
     */
    uint256 public constant ADDRESS_BATCH_MINT_LIMIT = 255;

    /**
     * @dev Basis points denominator used in fee calculations.
     */
    uint16 internal constant _MAX_BPS = 10_000;

    /**
     * @dev The interface ID for EIP-2981 (royaltyInfo)
     */
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev The value for `name` and `symbol` if their combined
     *      length is (32 - 2) bytes. We need 2 bytes for their lengths.
     */
    bytes32 private _shortNameAndSymbol;

    /**
     * @dev The metadata's base URI.
     */
    string public baseURI;

    /**
     * @dev The contract URI to be used by Opensea.
     *      See: https://docs.opensea.io/docs/contract-level-metadata
     */
    string public contractURI;

    /**
     * @dev The destination for ETH withdrawals.
     */
    address public fundingRecipient;

    /**
     * @dev The max mintable quantity for the edition.
     */
    uint32 public editionMaxMintable;

    /**
     * @dev The token count after which `mintRandomness` gets locked.
     */
    uint32 public mintRandomnessTokenThreshold;

    /**
     * @dev The timestamp after which `mintRandomness` gets locked.
     */
    uint32 public mintRandomnessTimeThreshold;

    /**
     * @dev Metadata module used for `tokenURI` if it is set.
     */
    IMetadataModule public metadataModule;

    /**
     * @dev The randomness based on latest block hash, which is stored upon each mint
     *      unless `randomnessLockedAfterMinted` or `randomnessLockedTimestamp` have been surpassed.
     *      Used for game mechanics like the Sound Golden Egg.
     */
    bytes9 private _mintRandomness;

    /**
     * @dev The royalty fee in basis points.
     */
    uint16 public royaltyBPS;

    /**
     * @dev Indicates if the `baseURI` is mutable.
     */
    bool public isMetadataFrozen;

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundEditionV1
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
    ) public onlyValidRoyaltyBPS(royaltyBPS_) {
        // Prevent double initialization.
        // We can "cheat" here and avoid the initializer modifer to save a SSTORE,
        // since the `_nextTokenId()` is defined to always return 1.
        if (_nextTokenId() != 0) revert Unauthorized();

        if (fundingRecipient_ == address(0)) revert InvalidFundingRecipient();

        _initializeNameAndSymbol(name_, symbol_);
        ERC721AStorage.layout()._currentIndex = _startTokenId();

        _initializeOwner(msg.sender);

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
     * @inheritdoc ISoundEditionV1
     */
    function mint(address to, uint256 quantity)
        public
        payable
        onlyRolesOrOwner(ADMIN_ROLE | MINTER_ROLE)
        requireWithinAddressBatchMintLimit(quantity)
        requireMintable(quantity)
        updatesMintRandomness
        returns (uint256 fromTokenId)
    {
        fromTokenId = _nextTokenId();
        // Mint the tokens. Will revert if `quantity` is zero.
        _mint(to, quantity);
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function airdrop(address[] calldata to, uint256 quantity)
        public
        onlyRolesOrOwner(ADMIN_ROLE)
        requireWithinAddressBatchMintLimit(quantity)
        requireMintable(to.length * quantity)
        updatesMintRandomness
        returns (uint256 fromTokenId)
    {
        fromTokenId = _nextTokenId();

        // Won't overflow, as `to.length` is bounded by the block max gas limit.
        unchecked {
            uint256 toLength = to.length;
            // Mint the tokens. Will revert if `quantity` is zero.
            for (uint256 i; i != toLength; ++i) {
                _mint(to[i], quantity);
            }
        }
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function withdrawETH() external {
        SafeTransferLib.safeTransferETH(fundingRecipient, address(this).balance);
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function withdrawERC20(address[] calldata tokens) external {
        unchecked {
            uint256 n = tokens.length;
            for (uint256 i; i != n; ++i) {
                SafeTransferLib.safeTransfer(tokens[i], fundingRecipient, IERC20(tokens[i]).balanceOf(address(this)));
            }
        }
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function setMetadataModule(IMetadataModule metadataModule_) external onlyRolesOrOwner(ADMIN_ROLE) {
        if (isMetadataFrozen) revert MetadataIsFrozen();
        metadataModule = metadataModule_;

        emit MetadataModuleSet(metadataModule_);
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function setBaseURI(string memory baseURI_) external onlyRolesOrOwner(ADMIN_ROLE) {
        if (isMetadataFrozen) revert MetadataIsFrozen();
        baseURI = baseURI_;

        emit BaseURISet(baseURI_);
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function setContractURI(string memory contractURI_) external onlyRolesOrOwner(ADMIN_ROLE) {
        if (isMetadataFrozen) revert MetadataIsFrozen();
        contractURI = contractURI_;

        emit ContractURISet(contractURI_);
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function freezeMetadata() external onlyRolesOrOwner(ADMIN_ROLE) {
        if (isMetadataFrozen) revert MetadataIsFrozen();

        isMetadataFrozen = true;
        emit MetadataFrozen(metadataModule, baseURI, contractURI);
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function setFundingRecipient(address fundingRecipient_) external onlyRolesOrOwner(ADMIN_ROLE) {
        if (fundingRecipient_ == address(0)) revert InvalidFundingRecipient();
        fundingRecipient = fundingRecipient_;
        emit FundingRecipientSet(fundingRecipient_);
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function setRoyalty(uint16 royaltyBPS_) external onlyRolesOrOwner(ADMIN_ROLE) onlyValidRoyaltyBPS(royaltyBPS_) {
        royaltyBPS = royaltyBPS_;
        emit RoyaltySet(royaltyBPS_);
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
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

    /**
     * @inheritdoc ISoundEditionV1
     */
    function setMintRandomnessTokenThreshold(uint32 mintRandomnessTokenThreshold_)
        external
        onlyRolesOrOwner(ADMIN_ROLE)
    {
        if (mintRandomnessRevealed()) revert MintRandomnessAlreadyRevealed();

        if (mintRandomnessTokenThreshold_ < _totalMinted()) revert InvalidRandomnessLock();

        mintRandomnessTokenThreshold = mintRandomnessTokenThreshold_;
    }

    /// @inheritdoc ISoundEditionV1
    function setRandomnessTimeThreshold(uint32 mintRandomnessTimeThreshold_) external onlyRolesOrOwner(ADMIN_ROLE) {
        if (mintRandomnessRevealed()) revert MintRandomnessAlreadyRevealed();

        mintRandomnessTimeThreshold = mintRandomnessTimeThreshold_;
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundEditionV1
     */
    function mintRandomness() public view returns (uint256) {
        return mintRandomnessRevealed() ? uint256(keccak256(abi.encode(_mintRandomness, address(this)))) : 0;
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function mintRandomnessRevealed() public view returns (bool) {
        uint256 currentTotalMinted = _totalMinted();
        return
            currentTotalMinted == editionMaxMintable ||
            (currentTotalMinted >= mintRandomnessTokenThreshold && block.timestamp >= mintRandomnessTimeThreshold);
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function nextTokenId() external view returns (uint256) {
        return _nextTokenId();
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function totalMinted() external view returns (uint256) {
        return _totalMinted();
    }

    /**
     * @inheritdoc IERC721AUpgradeable
     */
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

    /**
     * @inheritdoc ISoundEditionV1
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ISoundEditionV1, ERC721AUpgradeable, IERC721AUpgradeable)
        returns (bool)
    {
        return
            interfaceId == type(ISoundEditionV1).interfaceId ||
            ERC721AUpgradeable.supportsInterface(interfaceId) ||
            interfaceId == _INTERFACE_ID_ERC2981 ||
            interfaceId == this.supportsInterface.selector;
    }

    /**
     * @inheritdoc IERC2981Upgradeable
     */
    function royaltyInfo(
        uint256, // tokenId
        uint256 salePrice
    ) external view override(IERC2981Upgradeable) returns (address fundingRecipient_, uint256 royaltyAmount) {
        fundingRecipient_ = fundingRecipient;
        royaltyAmount = (salePrice * royaltyBPS) / _MAX_BPS;
    }

    /**
     * @inheritdoc IERC721AUpgradeable
     */
    function name() public view override(ERC721AUpgradeable, IERC721AUpgradeable) returns (string memory) {
        (string memory name_, ) = _loadNameAndSymbol();
        return name_;
    }

    /**
     * @inheritdoc IERC721AUpgradeable
     */
    function symbol() public view override(ERC721AUpgradeable, IERC721AUpgradeable) returns (string memory) {
        (, string memory symbol_) = _loadNameAndSymbol();
        return symbol_;
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @inheritdoc ERC721AUpgradeable
     */
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    /**
     * @dev Ensures the royalty basis points is a valid value.
     * @param bps The royalty BPS.
     */
    modifier onlyValidRoyaltyBPS(uint16 bps) {
        if (bps > _MAX_BPS) revert InvalidRoyaltyBPS();
        _;
    }

    /**
     * @dev Ensures that `totalQuantity` can be minted.
     * @param totalQuantity The total number of tokens to mint.
     */
    modifier requireMintable(uint256 totalQuantity) {
        unchecked {
            uint256 currentTotalMinted = _totalMinted();
            // Check if there are enough tokens to mint.
            // We use version v4.2+ of ERC721A, which `_mint` will revert with out-of-gas
            // error via a loop if `totalQuantity` is large enough to cause an overflow in uint256.
            if (currentTotalMinted + totalQuantity > editionMaxMintable) {
                // Won't underflow as `editionMaxMintable` cannot be decreased
                // below `_totalMinted()`. See {reduceEditionMaxMintable}.
                uint256 available = editionMaxMintable - currentTotalMinted;
                revert ExceedsEditionAvailableSupply(uint32(available));
            }
        }
        _;
    }

    /**
     * @dev Ensures that the `quantity` does not exceed `ADDRESS_BATCH_MINT_LIMIT`.
     * @param quantity The number of tokens minted per address.
     */
    modifier requireWithinAddressBatchMintLimit(uint256 quantity) {
        if (quantity > ADDRESS_BATCH_MINT_LIMIT) revert ExceedsAddressBatchMintLimit();
        _;
    }

    /**
     * @dev Updates the mint randomness.
     */
    modifier updatesMintRandomness() {
        if (!mintRandomnessRevealed()) {
            bytes32 randomness = _mintRandomness;
            assembly {
                // Pick a psuedorandom block from the previous 256 blocks for the blockhash.
                // See: https://en.wikipedia.org/wiki/Lehmer_random_number_generator
                let o := add(1, and(mulmod(shr(224, randomness), 48271, 0x7fffffff), 255))
                // Store the blockhash, the current `randomness` and the `currentNextTokenId`
                // into the scratch space.
                mstore(0x00, blockhash(sub(number(), o)))
                mstore(0x20, xor(randomness, coinbase()))
                // Compute the randomness by hashing the scratch space.
                randomness := keccak256(0x00, 0x40)
            }
            _mintRandomness = bytes9(randomness);
        }
        _;
    }

    /**
     * @dev Helper function for initializing the name and symbol,
     *      packing them into a single word if possible.
     * @param name_   Name of the collection.
     * @param symbol_ Symbol of the collection.
     */
    function _initializeNameAndSymbol(string memory name_, string memory symbol_) internal {
        // Overflow impossible since max block gas limit bounds the length of the strings.
        unchecked {
            uint256 nameLength = bytes(name_).length;
            uint256 symbolLength = bytes(symbol_).length;
            uint256 totalLength = nameLength + symbolLength;
            // If we cannot pack both strings into a single 32-byte word, store separately.
            // We need 2 bytes to store their lengths.
            if (totalLength > 32 - 2) {
                ERC721AStorage.layout()._name = name_;
                ERC721AStorage.layout()._symbol = symbol_;
                return;
            }
            // Otherwise, pack them and store them into a single word.
            _shortNameAndSymbol = bytes32(abi.encodePacked(uint8(nameLength), name_, uint8(symbolLength), symbol_));
        }
    }

    /**
     * @dev Helper function for retrieving the name and symbol,
     *      unpacking them from a single word in storage if previously packed.
     * @return name_   Name of the collection.
     * @return symbol_ Symbol of the collection.
     */
    function _loadNameAndSymbol() internal view returns (string memory name_, string memory symbol_) {
        // Overflow impossible since max block gas limit bounds the length of the strings.
        unchecked {
            bytes32 packed = _shortNameAndSymbol;
            // If the strings have been previously packed.
            if (packed != bytes32(0)) {
                // Allocate the bytes.
                bytes memory nameBytes = new bytes(uint8(packed[0]));
                bytes memory symbolBytes = new bytes(uint8(packed[1 + nameBytes.length]));
                // Copy the bytes.
                for (uint256 i; i < nameBytes.length; ++i) {
                    nameBytes[i] = bytes1(packed[1 + i]);
                }
                for (uint256 i; i < symbolBytes.length; ++i) {
                    symbolBytes[i] = bytes1(packed[2 + nameBytes.length + i]);
                }
                // Cast the bytes.
                name_ = string(nameBytes);
                symbol_ = string(symbolBytes);
            } else {
                // Otherwise, load them from their separate variables.
                name_ = ERC721AStorage.layout()._name;
                symbol_ = ERC721AStorage.layout()._symbol;
            }
        }
    }
}
