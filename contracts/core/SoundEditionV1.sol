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
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";

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

    /**
     * @dev The boolean flag on whether the metadata is frozen.
     */
    uint8 private constant _METADATA_FROZEN_FLAG = 1 << 0;

    /**
     * @dev The boolean flag on whether the `mintRandomness` is enabled.
     */
    uint8 private constant _MINT_RANDOMNESS_ENABLED_FLAG = 1 << 1;

    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev The value for `name` and `symbol` if their combined
     *      length is (32 - 2) bytes. We need 2 bytes for their lengths.
     */
    bytes32 private _shortNameAndSymbol;

    /**
     * @dev The metadata's base URI (for Arweave CIDs).
     */
    bytes32 private _baseURIArweaveCID;

    /**
     * @dev The metadata's base URI (for regular URIs).
     */
    string private _baseURIRegular;

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
        IMetadataModule metadataModule_,
        string memory baseURI_,
        string memory contractURI_,
        address fundingRecipient_,
        uint16 royaltyBPS_,
        uint32 editionMaxMintableLower_,
        uint32 editionMaxMintableUpper_,
        uint32 editionCutoffTime_,
        bool mintRandomnessEnabled_
    ) public onlyValidRoyaltyBPS(royaltyBPS_) {
        // Prevent double initialization.
        // We can "cheat" here and avoid the initializer modifer to save a SSTORE,
        // since the `_nextTokenId()` is defined to always return 1.
        if (_nextTokenId() != 0) revert Unauthorized();

        if (fundingRecipient_ == address(0)) revert InvalidFundingRecipient();

        if (editionMaxMintableLower_ > editionMaxMintableUpper_) revert InvalidEditionMaxMintableRange();

        _initializeNameAndSymbol(name_, symbol_);
        ERC721AStorage.layout()._currentIndex = _startTokenId();

        _initializeOwner(msg.sender);

        _setBaseURI(baseURI_, false);
        contractURI = contractURI_;

        fundingRecipient = fundingRecipient_;
        editionMaxMintableUpper = editionMaxMintableUpper_;
        editionMaxMintableLower = editionMaxMintableLower_;
        editionCutoffTime = editionCutoffTime_;

        _flags = mintRandomnessEnabled_ ? _MINT_RANDOMNESS_ENABLED_FLAG : 0;

        metadataModule = metadataModule_;
        royaltyBPS = royaltyBPS_;
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
    function setMetadataModule(IMetadataModule metadataModule_) external onlyRolesOrOwner(ADMIN_ROLE) {
        if (isMetadataFrozen()) revert MetadataIsFrozen();
        metadataModule = metadataModule_;

        emit MetadataModuleSet(metadataModule_);
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function setBaseURI(string memory baseURI_) external onlyRolesOrOwner(ADMIN_ROLE) {
        if (isMetadataFrozen()) revert MetadataIsFrozen();
        _setBaseURI(baseURI_, true);

        emit BaseURISet(baseURI_);
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function setContractURI(string memory contractURI_) external onlyRolesOrOwner(ADMIN_ROLE) {
        if (isMetadataFrozen()) revert MetadataIsFrozen();
        contractURI = contractURI_;

        emit ContractURISet(contractURI_);
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function freezeMetadata() external onlyRolesOrOwner(ADMIN_ROLE) {
        if (isMetadataFrozen()) revert MetadataIsFrozen();

        _flags |= _METADATA_FROZEN_FLAG;
        emit MetadataFrozen(metadataModule, baseURI(), contractURI);
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

        editionMaxMintableLower_ = uint32(FixedPointMathLib.max(editionMaxMintableLower_, currentTotalMinted));

        editionMaxMintableUpper_ = uint32(FixedPointMathLib.max(editionMaxMintableUpper_, currentTotalMinted));

        // If the lower bound is larger than the upper bound, revert.
        if (editionMaxMintableLower_ > editionMaxMintableUpper_) revert InvalidEditionMaxMintableRange();

        // If the upper bound is larger than the current stored value, revert.
        if (editionMaxMintableUpper_ > editionMaxMintableUpper) revert InvalidEditionMaxMintableRange();

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
            _flags ^= _MINT_RANDOMNESS_ENABLED_FLAG;
        }

        emit MintRandomnessEnabledSet(mintRandomnessEnabled_);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

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
        return _flags & _METADATA_FROZEN_FLAG != 0;
    }

    /**
     * @inheritdoc ISoundEditionV1
     */
    function mintRandomnessEnabled() public view returns (bool) {
        return _flags & _MINT_RANDOMNESS_ENABLED_FLAG != 0;
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
        return _loadBaseURI();
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
            uint256 currentEditionMaxMintable = editionMaxMintable();
            // Check if there are enough tokens to mint.
            // We use version v4.2+ of ERC721A, which `_mint` will revert with out-of-gas
            // error via a loop if `totalQuantity` is large enough to cause an overflow in uint256.
            if (currentTotalMinted + totalQuantity > currentEditionMaxMintable) {
                // Won't underflow as `editionMaxMintableUpper` cannot be decreased
                // below `_totalMinted()`. See {setEditionMaxMintableRange}.
                // `zeroFloorSub(x, y)` is `max(x - y, 0)`.
                uint256 available = FixedPointMathLib.zeroFloorSub(currentEditionMaxMintable, currentTotalMinted);
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

    /**
     * @dev Helper function for initializing the baseURI.
     * @param baseURI_ The base URI.
     * @param isUpdate Whether this is called in an update.
     */
    function _setBaseURI(string memory baseURI_, bool isUpdate) internal {
        string memory copy;
        bool isArweave;
        assembly {
            // Example: "ar://Hjtz2YLeVyXQkGxKTNcIYfWkKnHioDvfICulzQIAt3E"
            let n := mload(baseURI_)
            // If the URI is length 48 or 49 (due to a trailing slash).
            if or(eq(n, 48), eq(n, 49)) {
                // If starts with "ar://".
                if eq(and(mload(add(5, baseURI_)), 0xffffffffff), 0x61723a2f2f) {
                    isArweave := 1
                    // Copy `_baseURI`.
                    copy := mload(0x40)
                    mstore(0x40, add(copy, 0x60)) // Allocate 3 slots.
                    mstore(add(copy, 0x20), mload(add(baseURI_, 0x20)))
                    mstore(add(copy, 0x40), mload(add(baseURI_, 0x40)))
                    // Make the `copy` skip the first 5 bytes.
                    copy := add(5, copy)
                    // Resize the length of the `copy`,
                    // such that it only contains the CID.
                    mstore(copy, 43)
                    // Replace '-' with '+', and '_' with '/'.
                    let i := add(copy, 0x20)
                    let end := add(i, 43)
                    // prettier-ignore
                    for {} 1 {} {
                        switch byte(0, mload(i)) 
                        case 45 { // '-' => '+'.
                            mstore8(i, 43) 
                        }
                        case 95 { // '_' => '/'.
                            mstore8(i, 47)
                        }
                        i := add(i, 1)
                        // prettier-ignore
                        if iszero(lt(i, end)) { break }
                    }
                }
            }
        }
        if (isArweave) {
            bytes memory decoded = Base64.decode(copy);
            bytes32 cid;
            assembly {
                cid := mload(add(decoded, 0x20))
            }
            _baseURIArweaveCID = cid;
            if (isUpdate) delete _baseURIRegular;
        } else {
            _baseURIRegular = baseURI_;
            if (isUpdate) delete _baseURIArweaveCID;
        }
    }

    /**
     * @dev Helper function for retrieving the baseURI.
     */
    function _loadBaseURI() internal view returns (string memory) {
        bytes32 cid = _baseURIArweaveCID;
        if (cid == bytes32(0)) {
            return _baseURIRegular;
        }
        bytes memory decoded;
        assembly {
            decoded := mload(0x40)
            mstore(0x40, add(decoded, 0x40)) // Allocate 2 slots.
            mstore(decoded, 0x20)
            mstore(add(decoded, 0x20), cid)
        }
        string memory encoded = Base64.encode(decoded);
        assembly {
            // Replace '-' with '+', and '_' with '/'.
            let i := add(encoded, 0x20)
            let end := add(i, 43)
            // prettier-ignore
            for {} 1 {} {
                switch byte(0, mload(i)) 
                case 43 { // '+' => '-'.
                    mstore8(i, 45) 
                }
                case 47 { // '/' => '_'.
                    mstore8(i, 95)
                }
                i := add(i, 1)
                // prettier-ignore
                if iszero(lt(i, end)) { break }
            }
            // Strip the padding.
            mstore(encoded, 43)
        }
        return string.concat("ar://", encoded, "/");
    }
}
