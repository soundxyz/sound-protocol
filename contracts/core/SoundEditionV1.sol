// SPDX-License-Identifier: MIT
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
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

import { ISoundEditionV1, EditionInfo } from "./interfaces/ISoundEditionV1.sol";
import { IMetadataModule } from "./interfaces/IMetadataModule.sol";

import { ArweaveURILib } from "./utils/ArweaveURILib.sol";

/**
 * @title SoundEditionV1
 * @notice The Sound Edition contract - a creator-owned, modifiable implementation of ERC721A.
 */
contract SoundEditionV1 is ISoundEditionV1, ERC721AQueryableUpgradeable, ERC721ABurnableUpgradeable, OwnableRoles {
    using ArweaveURILib for ArweaveURILib.URI;

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

    /**
     * @dev The boolean flag on whether the metadata is frozen.
     */
    uint8 public constant METADATA_IS_FROZEN_FLAG = 1 << 0;

    /**
     * @dev The boolean flag on whether the `mintRandomness` is enabled.
     */
    uint8 public constant MINT_RANDOMNESS_ENABLED_FLAG = 1 << 1;

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
    ArweaveURILib.URI private _baseURIStorage;

    /**
     * @dev The contract base URI.
     */
    ArweaveURILib.URI private _contractURIStorage;

    /**
     * @dev The destination for ETH withdrawals.
     */
    address public fundingRecipient;

    /**
     * @dev The upper bound of the max mintable quantity for the edition.
     */
    uint32 public editionMaxMintableUpper;

    /**
     * @dev The lower bound for the maximum tokens that can be minted for this edition.
     */
    uint32 public editionMaxMintableLower;

    /**
     * @dev The timestamp after which `editionMaxMintable` drops from
     *      `editionMaxMintableUpper` to `max(_totalMinted(), editionMaxMintableLower)`.
     */
    uint32 public editionCutoffTime;

    /**
     * @dev Metadata module used for `tokenURI` and `contractURI` if it is set.
     */
    address public metadataModule;

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
     * @dev Packed boolean flags.
     */
    uint8 private _flags;

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundEditionV1
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        address metadataModule_,
        string memory baseURI_,
        string memory contractURI_,
        address fundingRecipient_,
        uint16 royaltyBPS_,
        uint32 editionMaxMintableLower_,
        uint32 editionMaxMintableUpper_,
        uint32 editionCutoffTime_,
        uint8 flags_
    ) external onlyValidRoyaltyBPS(royaltyBPS_) {
        // Prevent double initialization.
        // We can "cheat" here and avoid the initializer modifer to save a SSTORE,
        // since the `_nextTokenId()` is defined to always return 1.
        if (_nextTokenId() != 0) revert Unauthorized();

        if (fundingRecipient_ == address(0)) revert InvalidFundingRecipient();

        if (editionMaxMintableLower_ > editionMaxMintableUpper_) revert InvalidEditionMaxMintableRange();

        _initializeNameAndSymbol(name_, symbol_);
        ERC721AStorage.layout()._currentIndex = _startTokenId();

        _initializeOwner(msg.sender);

        _baseURIStorage.initialize(baseURI_);
        _contractURIStorage.initialize(contractURI_);

        fundingRecipient = fundingRecipient_;
        editionMaxMintableUpper = editionMaxMintableUpper_;
        editionMaxMintableLower = editionMaxMintableLower_;
        editionCutoffTime = editionCutoffTime_;

        _flags = flags_;

        metadataModule = metadataModule_;
        royaltyBPS = royaltyBPS_;

        emit SoundEditionInitialized(
            address(this),
            name_,
            symbol_,
            metadataModule_,
            baseURI_,
            contractURI_,
            fundingRecipient_,
            royaltyBPS_,
            editionMaxMintableLower_,
            editionMaxMintableUpper_,
            editionCutoffTime_,
            flags_
        );
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function mint(address to, uint256 quantity)
        external
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
        external
        onlyRolesOrOwner(ADMIN_ROLE)
        requireWithinAddressBatchMintLimit(quantity)
        requireMintable(to.length * quantity)
        updatesMintRandomness
        returns (uint256 fromTokenId)
    {
        if (to.length == 0) revert NoAddressesToAirdrop();

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
    function setMetadataModule(address metadataModule_) external onlyRolesOrOwner(ADMIN_ROLE) onlyMetadataNotFrozen {
        metadataModule = metadataModule_;

        emit MetadataModuleSet(metadataModule_);
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function setBaseURI(string memory baseURI_) external onlyRolesOrOwner(ADMIN_ROLE) onlyMetadataNotFrozen {
        _baseURIStorage.update(baseURI_);

        emit BaseURISet(baseURI_);
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function setContractURI(string memory contractURI_) external onlyRolesOrOwner(ADMIN_ROLE) onlyMetadataNotFrozen {
        _contractURIStorage.update(contractURI_);

        emit ContractURISet(contractURI_);
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function freezeMetadata() external onlyRolesOrOwner(ADMIN_ROLE) onlyMetadataNotFrozen {
        _flags |= METADATA_IS_FROZEN_FLAG;
        emit MetadataFrozen(metadataModule, baseURI(), contractURI());
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
    function setEditionMaxMintableRange(uint32 editionMaxMintableLower_, uint32 editionMaxMintableUpper_)
        external
        onlyRolesOrOwner(ADMIN_ROLE)
    {
        if (mintConcluded()) revert MintHasConcluded();

        uint32 currentTotalMinted = uint32(_totalMinted());

        if (currentTotalMinted != 0) {
            editionMaxMintableLower_ = uint32(FixedPointMathLib.max(editionMaxMintableLower_, currentTotalMinted));

            editionMaxMintableUpper_ = uint32(FixedPointMathLib.max(editionMaxMintableUpper_, currentTotalMinted));

            // If the upper bound is larger than the current stored value, revert.
            if (editionMaxMintableUpper_ > editionMaxMintableUpper) revert InvalidEditionMaxMintableRange();
        }

        // If the lower bound is larger than the upper bound, revert.
        if (editionMaxMintableLower_ > editionMaxMintableUpper_) revert InvalidEditionMaxMintableRange();

        editionMaxMintableLower = editionMaxMintableLower_;
        editionMaxMintableUpper = editionMaxMintableUpper_;

        emit EditionMaxMintableRangeSet(editionMaxMintableLower, editionMaxMintableUpper);
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function setEditionCutoffTime(uint32 editionCutoffTime_) external onlyRolesOrOwner(ADMIN_ROLE) {
        if (mintConcluded()) revert MintHasConcluded();

        editionCutoffTime = editionCutoffTime_;

        emit EditionCutoffTimeSet(editionCutoffTime_);
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function setMintRandomnessEnabled(bool mintRandomnessEnabled_) external onlyRolesOrOwner(ADMIN_ROLE) {
        if (_totalMinted() != 0) revert MintsAlreadyExist();

        if (mintRandomnessEnabled() != mintRandomnessEnabled_) {
            _flags ^= MINT_RANDOMNESS_ENABLED_FLAG;
        }

        emit MintRandomnessEnabledSet(mintRandomnessEnabled_);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundEditionV1
     */
    function editionInfo() external view returns (EditionInfo memory info) {
        info.baseURI = baseURI();
        info.contractURI = contractURI();
        info.name = name();
        info.symbol = symbol();
        info.fundingRecipient = fundingRecipient;
        info.editionMaxMintable = editionMaxMintable();
        info.editionMaxMintableUpper = editionMaxMintableUpper;
        info.editionMaxMintableLower = editionMaxMintableLower;
        info.editionCutoffTime = editionCutoffTime;
        info.metadataModule = metadataModule;
        info.mintRandomness = mintRandomness();
        info.royaltyBPS = royaltyBPS;
        info.mintRandomnessEnabled = mintRandomnessEnabled();
        info.mintConcluded = mintConcluded();
        info.isMetadataFrozen = isMetadataFrozen();
        info.nextTokenId = nextTokenId();
        info.totalMinted = totalMinted();
        info.totalBurned = totalBurned();
        info.totalSupply = totalSupply();
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function mintRandomness() public view returns (uint256) {
        if (mintConcluded() && mintRandomnessEnabled()) {
            return uint256(keccak256(abi.encode(_mintRandomness, address(this))));
        }
        return 0;
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function editionMaxMintable() public view returns (uint32) {
        if (block.timestamp < editionCutoffTime) {
            return editionMaxMintableUpper;
        } else {
            return uint32(FixedPointMathLib.max(editionMaxMintableLower, _totalMinted()));
        }
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function isMetadataFrozen() public view returns (bool) {
        return _flags & METADATA_IS_FROZEN_FLAG != 0;
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function mintRandomnessEnabled() public view returns (bool) {
        return _flags & MINT_RANDOMNESS_ENABLED_FLAG != 0;
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function mintConcluded() public view returns (bool) {
        return _totalMinted() == editionMaxMintable();
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function nextTokenId() public view returns (uint256) {
        return _nextTokenId();
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function numberMinted(address owner) external view returns (uint256) {
        return _numberMinted(owner);
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function numberBurned(address owner) external view returns (uint256) {
        return _numberBurned(owner);
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function totalMinted() public view returns (uint256) {
        return _totalMinted();
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function totalBurned() public view returns (uint256) {
        return _totalBurned();
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

        if (metadataModule != address(0)) {
            return IMetadataModule(metadataModule).tokenURI(tokenId);
        }

        string memory baseURI_ = baseURI();
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

    /**
     * @inheritdoc ISoundEditionV1
     */
    function baseURI() public view returns (string memory) {
        return _baseURIStorage.load();
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function contractURI() public view returns (string memory) {
        return _contractURIStorage.load();
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
     * @dev Reverts if the metadata is frozen.
     */
    modifier onlyMetadataNotFrozen() {
        // Inlined to save gas.
        if (_flags & METADATA_IS_FROZEN_FLAG != 0) revert MetadataIsFrozen();
        _;
    }

    /**
     * @dev Ensures that `totalQuantity` can be minted.
     * @param totalQuantity The total number of tokens to mint.
     */
    modifier requireMintable(uint256 totalQuantity) {
        unchecked {
            uint256 currentTotalMinted = _totalMinted();
            uint256 currentEditionMaxMintable = editionMaxMintable();
            // Check if there are enough tokens to mint.
            // We use version v4.2+ of ERC721A, which `_mint` will revert with out-of-gas
            // error via a loop if `totalQuantity` is large enough to cause an overflow in uint256.
            if (currentTotalMinted + totalQuantity > currentEditionMaxMintable) {
                // Won't underflow.
                //
                // `currentTotalMinted`, which is `_totalMinted()`,
                // will return either `editionMaxMintableUpper`
                // or `max(editionMaxMintableLower, _totalMinted())`.
                //
                // We have the following invariants:
                // - `editionMaxMintableUpper >= _totalMinted()`
                // - `max(editionMaxMintableLower, _totalMinted()) >= _totalMinted()`
                uint256 available = currentEditionMaxMintable - currentTotalMinted;
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
        if (mintRandomnessEnabled() && !mintConcluded()) {
            bytes32 randomness = _mintRandomness;
            assembly {
                // Pick any of the last 256 blocks psuedorandomly for the blockhash.
                // Store the blockhash, the current `randomness` and the `coinbase()`
                // into the scratch space.
                mstore(0x00, blockhash(sub(number(), add(1, byte(0, randomness)))))
                // `randomness` is left-aligned.
                // `coinbase()` is right-aligned.
                // `difficulty()` is right-aligned.
                // After the merge, if [EIP-4399](https://eips.ethereum.org/EIPS/eip-4399)
                // is implemented, the randomness will be determined by the beacon chain.
                mstore(0x20, xor(randomness, xor(coinbase(), difficulty())))
                // Compute the new `randomness` by hashing the scratch space.
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
