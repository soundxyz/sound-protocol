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
import { IERC2981Upgradeable } from "openzeppelin-upgradeable/interfaces/IERC2981Upgradeable.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { LibString } from "solady/utils/LibString.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { OperatorFilterer } from "closedsea/OperatorFilterer.sol";
import { LibMulticaller } from "multicaller/LibMulticaller.sol";

import { ISoundEditionV1_2, EditionInfo } from "./interfaces/ISoundEditionV1_2.sol";
import { IMetadataModule } from "./interfaces/IMetadataModule.sol";

import { ArweaveURILib } from "./utils/ArweaveURILib.sol";
import { MintRandomnessLib } from "./utils/MintRandomnessLib.sol";

/**
 * @title SoundEditionV1_2
 * @notice The Sound Edition contract - a creator-owned, modifiable implementation of ERC721A.
 */
contract SoundEditionV1_2 is
    ISoundEditionV1_2,
    ERC721AQueryableUpgradeable,
    ERC721ABurnableUpgradeable,
    OwnableRoles,
    OperatorFilterer
{
    using ArweaveURILib for ArweaveURILib.URI;
    using LibBitmap for LibBitmap.Bitmap;

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
     * @dev Basis points denominator used in fee calculations.
     */
    uint16 internal constant _MAX_BPS = 10_000;

    /**
     * @dev The interface ID for EIP-2981 (royaltyInfo)
     */
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    /**
     * @dev The interface ID for SoundEdition v1.0.0.
     */
    bytes4 private constant _INTERFACE_ID_SOUND_EDITION_V1 = 0x50899e54;

    /**
     * @dev The interface ID for SoundEdition v1.1.0.
     */
    bytes4 private constant _INTERFACE_ID_SOUND_EDITION_V1_1 = 0x425aac3d;

    /**
     * @dev The boolean flag on whether the metadata is frozen.
     */
    uint8 public constant METADATA_IS_FROZEN_FLAG = 1 << 0;

    /**
     * @dev The boolean flag on whether the `mintRandomness` is enabled.
     */
    uint8 public constant MINT_RANDOMNESS_ENABLED_FLAG = 1 << 1;

    /**
     * @dev The boolean flag on whether OpenSea operator filtering is enabled.
     */
    uint8 public constant OPERATOR_FILTERING_ENABLED_FLAG = 1 << 2;

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
    uint72 private _mintRandomness;

    /**
     * @dev The royalty fee in basis points.
     */
    uint16 public royaltyBPS;

    /**
     * @dev Packed boolean flags.
     */
    uint8 private _flags;

    /**
     * @dev The Sound Automated Market (i.e. bonding curve minter), if any.
     */
    address public sam;

    /**
     * @dev The total number of tokens minted at the very first use of `samMint`.
     */
    uint32 private _totalMintedSnapshot;

    /**
     * @dev Whether the `_totalMintedSnapshot` has been initialized.
     */
    bool private _totalMintedSnapshotInitialized;

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundEditionV1_2
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

        if (flags_ & OPERATOR_FILTERING_ENABLED_FLAG != 0) {
            _registerForOperatorFiltering();
        }
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function setSAM(address sam_) external onlyRolesOrOwner(ADMIN_ROLE) onlyBeforeMintConcluded {
        // If there has been any tokens minted, disallow setting
        // the SAM to a non-zero address.
        // So, as long as the initial mints have not concluded,
        // the artist can still unset SAM if they desire.
        if (_totalMinted() != 0)
            if (sam_ != address(0)) revert MintsAlreadyExist();
        sam = sam_;
        emit SAMSet(sam_);
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function mint(address to, uint256 quantity)
        external
        payable
        onlyRolesOrOwner(ADMIN_ROLE | MINTER_ROLE)
        requireMintable(quantity)
        updatesMintRandomness(quantity)
        returns (uint256 fromTokenId)
    {
        fromTokenId = _nextTokenId();
        // Mint the tokens. Will revert if `quantity` is zero.
        _batchMint(to, quantity);

        emit Minted(to, quantity, fromTokenId);
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function airdrop(address[] calldata to, uint256 quantity)
        external
        onlyRolesOrOwner(ADMIN_ROLE)
        requireMintable(to.length * quantity)
        updatesMintRandomness(to.length * quantity)
        returns (uint256 fromTokenId)
    {
        if (to.length == 0) revert NoAddressesToAirdrop();

        fromTokenId = _nextTokenId();

        // Won't overflow, as `to.length` is bounded by the block max gas limit.
        unchecked {
            uint256 toLength = to.length;
            // Mint the tokens. Will revert if `quantity` is zero.
            for (uint256 i; i != toLength; ++i) {
                _batchMint(to[i], quantity);
            }
        }

        emit Airdropped(to, quantity, fromTokenId);
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function samMint(address to, uint256 quantity)
        external
        payable
        onlySAM
        onlyAfterMintConcluded
        returns (uint256 fromTokenId)
    {
        if (!_totalMintedSnapshotInitialized) {
            _totalMintedSnapshot = uint32(_totalMinted());
            _totalMintedSnapshotInitialized = true;
        }

        fromTokenId = _nextTokenId();
        _batchMint(to, quantity);

        // We don't need to emit an event here,
        // as the bonding curve minter will have already emitted a comprehensive event.
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function samBurn(address burner, uint256[] calldata tokenIds) external onlySAM onlyAfterMintConcluded {
        // We can use unchecked as the length of `tokenIds` is bounded
        // to a small number by the max block gas limit.
        unchecked {
            // For performance, we will directly read and update the storage of ERC721A.
            ERC721AStorage.Layout storage layout = ERC721AStorage.layout();
            // The next `tokenId` to be minted (i.e. `_nextTokenId()`).
            uint256 stop = layout._currentIndex;

            uint256 burnedBit = 1 << 224; // Bit 224 in a packed ownership represents a burned token in ERC721A.
            uint256 n = tokenIds.length;

            // For checking if the `tokenIds` are strictly ascending.
            uint256 prevTokenId;

            for (uint256 i; i != n; ) {
                uint256 tokenId = tokenIds[i];

                // Revert `tokenId` is out of bounds.
                if (_or(tokenId < _startTokenId(), stop <= tokenId)) revert OwnerQueryForNonexistentToken();

                // Revert if `tokenIds` is not strictly ascending.
                // SoundEdition tokens IDs start from 1, and `prevTokenId` is initially 0,
                // so the initial pass of the loop won't revert.
                if (tokenId <= prevTokenId) revert TokenIdsNotStrictlyAscending();

                // The initialized packed ownership slot's value.
                uint256 prevOwnershipPacked;
                // Scan backwards for an initialized packed ownership slot.
                // ERC721A's invariant guarantees that there will always be an initialized slot as long as
                // the start of the backwards scan falls within `[_startTokenId() .. _nextTokenId())`.
                for (uint256 j = tokenId; (prevOwnershipPacked = layout._packedOwnerships[j]) == 0; ) --j;

                // If the initialized slot is burned, revert.
                if (prevOwnershipPacked & burnedBit != 0) revert OwnerQueryForNonexistentToken();

                // Unpack the `tokenOwner` from bits [0..159] of `prevOwnershipPacked`.
                address tokenOwner = address(uint160(prevOwnershipPacked));

                // Enforce waiting a block before a recently minted or transferred token can be burned.
                if (block.timestamp == ((prevOwnershipPacked >> 160) & (2**64 - 1))) revert CannotBurnImmediately();

                // Check if the burner is either the owner or an approved operator for all the
                bool mayBurn = tokenOwner == burner || isApprovedForAll(tokenOwner, burner);

                uint256 offset;
                uint256 currTokenId = tokenId;
                do {
                    // Revert if the burner is not authorized to burn the token.
                    if (!mayBurn)
                        if (getApproved(currTokenId) != burner) revert TransferCallerNotOwnerNorApproved();
                    // Emit the `Transfer` event for burn.
                    emit Transfer(tokenOwner, address(0), currTokenId);
                    // Increment `offset` and update `currTokenId`.
                    currTokenId = tokenId + (++offset);
                } while (
                    // Neither out of bounds, nor at the end of `tokenIds`.
                    !_or(currTokenId == stop, i + offset == n) &&
                        // Token ID is sequential.
                        tokenIds[i + offset] == currTokenId &&
                        // The packed ownership slot is not initialized.
                        layout._packedOwnerships[currTokenId] == 0
                );

                // Update the packed ownership for `tokenId` in ERC721A's storage.
                //
                // Bits Layout:
                // - [0..159]   `addr`
                // - [160..223] `startTimestamp`
                // - [224]      `burned`
                // - [225]      `nextInitialized` (optional)
                // - [232..255] `extraData` (not used)
                layout._packedOwnerships[tokenId] = burnedBit | (block.timestamp << 160) | uint256(uint160(tokenOwner));

                // If the slot after the mini batch is neither out of bounds, nor initialized.
                if (currTokenId != stop)
                    if (layout._packedOwnerships[currTokenId] == 0)
                        layout._packedOwnerships[currTokenId] = prevOwnershipPacked;

                // Update the address data in ERC721A's storage.
                // - Decrease the token balance for the `tokenOwner` (bits [0..63]).
                // - Increase the number burned for the `tokenOwner` (bits [128..191]).
                //
                // Note that this update has to be in the loop as tokens
                // can be burned by an operator that is not the token owner.
                layout._packedAddressData[tokenOwner] += (offset << 128) - offset;

                // Advance `i` by `offset`, the number of tokens burned in the mini batch.
                i += offset;

                // Set the `prevTokenId` for checking that the `tokenIds` is strictly ascending.
                prevTokenId = currTokenId - 1;
            }
            // Increase the `_burnCounter` in ERC721A's storage.
            layout._burnCounter += n;
        }
        // We don't need to emit an event here,
        // as the bonding curve minter will have already emitted a comprehensive event.
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function withdrawETH() external {
        uint256 amount = address(this).balance;
        SafeTransferLib.forceSafeTransferETH(fundingRecipient, amount);
        emit ETHWithdrawn(fundingRecipient, amount, msg.sender);
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function withdrawERC20(address[] calldata tokens) external {
        unchecked {
            uint256 n = tokens.length;
            uint256[] memory amounts = new uint256[](n);
            for (uint256 i; i != n; ++i) {
                amounts[i] = SafeTransferLib.safeTransferAll(tokens[i], fundingRecipient);
            }
            emit ERC20Withdrawn(fundingRecipient, tokens, amounts, msg.sender);
        }
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function setMetadataModule(address metadataModule_)
        external
        onlyRolesOrOwner(ADMIN_ROLE)
        onlyMetadataNotFrozen
        onlyBeforeMintConcluded
    {
        metadataModule = metadataModule_;

        emit MetadataModuleSet(metadataModule_);
        emitAllMetadataUpdate();
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function setBaseURI(string memory baseURI_) external onlyRolesOrOwner(ADMIN_ROLE) onlyMetadataNotFrozen {
        _baseURIStorage.update(baseURI_);

        emit BaseURISet(baseURI_);
        emitAllMetadataUpdate();
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function setContractURI(string memory contractURI_) external onlyRolesOrOwner(ADMIN_ROLE) onlyMetadataNotFrozen {
        _contractURIStorage.update(contractURI_);

        emit ContractURISet(contractURI_);
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function freezeMetadata() external onlyRolesOrOwner(ADMIN_ROLE) onlyMetadataNotFrozen {
        _flags |= METADATA_IS_FROZEN_FLAG;
        emit MetadataFrozen(metadataModule, baseURI(), contractURI());
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function setFundingRecipient(address fundingRecipient_) external onlyRolesOrOwner(ADMIN_ROLE) {
        if (fundingRecipient_ == address(0)) revert InvalidFundingRecipient();
        fundingRecipient = fundingRecipient_;
        emit FundingRecipientSet(fundingRecipient_);
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function setRoyalty(uint16 royaltyBPS_) external onlyRolesOrOwner(ADMIN_ROLE) onlyValidRoyaltyBPS(royaltyBPS_) {
        royaltyBPS = royaltyBPS_;
        emit RoyaltySet(royaltyBPS_);
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function setEditionMaxMintableRange(uint32 editionMaxMintableLower_, uint32 editionMaxMintableUpper_)
        external
        onlyRolesOrOwner(ADMIN_ROLE)
        onlyBeforeMintConcluded
    {
        uint32 currentTotalMinted = uint32(_totalMinted());

        if (currentTotalMinted != 0) {
            // If the lower bound is larger than the current stored value, revert.
            if (editionMaxMintableLower_ > editionMaxMintableLower) revert InvalidEditionMaxMintableRange();
            // If the upper bound is larger than the current stored value, revert.
            if (editionMaxMintableUpper_ > editionMaxMintableUpper) revert InvalidEditionMaxMintableRange();

            editionMaxMintableLower_ = uint32(FixedPointMathLib.max(editionMaxMintableLower_, currentTotalMinted));
            editionMaxMintableUpper_ = uint32(FixedPointMathLib.max(editionMaxMintableUpper_, currentTotalMinted));
        }

        // If the lower bound is larger than the upper bound, revert.
        if (editionMaxMintableLower_ > editionMaxMintableUpper_) revert InvalidEditionMaxMintableRange();

        editionMaxMintableLower = editionMaxMintableLower_;
        editionMaxMintableUpper = editionMaxMintableUpper_;

        emit EditionMaxMintableRangeSet(editionMaxMintableLower, editionMaxMintableUpper);
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function setEditionCutoffTime(uint32 editionCutoffTime_)
        external
        onlyRolesOrOwner(ADMIN_ROLE)
        onlyBeforeMintConcluded
    {
        editionCutoffTime = editionCutoffTime_;

        emit EditionCutoffTimeSet(editionCutoffTime_);
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function setMintRandomnessEnabled(bool mintRandomnessEnabled_) external onlyRolesOrOwner(ADMIN_ROLE) {
        if (_totalMinted() != 0) revert MintsAlreadyExist();

        if (mintRandomnessEnabled() != mintRandomnessEnabled_) {
            _flags ^= MINT_RANDOMNESS_ENABLED_FLAG;
        }

        emit MintRandomnessEnabledSet(mintRandomnessEnabled_);
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function setOperatorFilteringEnabled(bool operatorFilteringEnabled_) external onlyRolesOrOwner(ADMIN_ROLE) {
        if (operatorFilteringEnabled() != operatorFilteringEnabled_) {
            _flags ^= OPERATOR_FILTERING_ENABLED_FLAG;
            if (operatorFilteringEnabled_) {
                _registerForOperatorFiltering();
            }
        }

        emit OperatorFilteringEnablededSet(operatorFilteringEnabled_);
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function emitAllMetadataUpdate() public {
        emit BatchMetadataUpdate(_startTokenId(), _nextTokenId() - 1);
    }

    /**
     * @inheritdoc IERC721AUpgradeable
     */
    function setApprovalForAll(address operator, bool approved)
        public
        override(ERC721AUpgradeable, IERC721AUpgradeable)
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    /**
     * @inheritdoc IERC721AUpgradeable
     */
    function approve(address operator, uint256 tokenId)
        public
        payable
        override(ERC721AUpgradeable, IERC721AUpgradeable)
        onlyAllowedOperatorApproval(operator)
    {
        super.approve(operator, tokenId);
    }

    /**
     * @inheritdoc IERC721AUpgradeable
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable override(ERC721AUpgradeable, IERC721AUpgradeable) onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    /**
     * @inheritdoc IERC721AUpgradeable
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable override(ERC721AUpgradeable, IERC721AUpgradeable) onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    /**
     * @inheritdoc IERC721AUpgradeable
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public payable override(ERC721AUpgradeable, IERC721AUpgradeable) onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundEditionV1_2
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
     * @inheritdoc ISoundEditionV1_2
     */
    function mintRandomness() public view returns (uint256 result) {
        if (mintConcluded())
            if (mintRandomnessEnabled()) {
                result = _mintRandomness;
                assembly {
                    mstore(0x00, result)
                    mstore(0x20, address())
                    result := keccak256(0x00, 0x40)
                }
            }
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function editionMaxMintable() public view returns (uint32) {
        if (block.timestamp < editionCutoffTime) {
            return editionMaxMintableUpper;
        } else {
            uint256 t = _totalMintedSnapshotInitialized ? _totalMintedSnapshot : _totalMinted();
            return uint32(FixedPointMathLib.max(editionMaxMintableLower, t));
        }
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function isMetadataFrozen() public view returns (bool) {
        return _flags & METADATA_IS_FROZEN_FLAG != 0;
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function mintRandomnessEnabled() public view returns (bool) {
        return _flags & MINT_RANDOMNESS_ENABLED_FLAG != 0;
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function operatorFilteringEnabled() public view returns (bool) {
        return _operatorFilteringEnabled();
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function mintConcluded() public view returns (bool) {
        return _totalMinted() >= editionMaxMintable();
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function nextTokenId() public view returns (uint256) {
        return _nextTokenId();
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function numberMinted(address owner) external view returns (uint256) {
        return _numberMinted(owner);
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function numberBurned(address owner) external view returns (uint256) {
        return _numberBurned(owner);
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function totalMinted() public view returns (uint256) {
        return _totalMinted();
    }

    /**
     * @inheritdoc ISoundEditionV1_2
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
     * @inheritdoc ISoundEditionV1_2
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ISoundEditionV1_2, ERC721AUpgradeable, IERC721AUpgradeable)
        returns (bool)
    {
        return
            interfaceId == _INTERFACE_ID_SOUND_EDITION_V1 ||
            interfaceId == _INTERFACE_ID_SOUND_EDITION_V1_1 ||
            interfaceId == type(ISoundEditionV1_2).interfaceId ||
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
     * @inheritdoc ISoundEditionV1_2
     */
    function baseURI() public view returns (string memory) {
        return _baseURIStorage.load();
    }

    /**
     * @inheritdoc ISoundEditionV1_2
     */
    function contractURI() public view returns (string memory) {
        return _contractURIStorage.load();
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Override the `onlyRolesOrOwner` modifier on `OwnableRoles`
     *      to support multicaller sender forwarding.
     */
    modifier onlyRolesOrOwner(uint256 roles) virtual override {
        address sender = LibMulticaller.sender();
        if (!hasAnyRole(sender, roles))
            if (sender != owner()) revert Unauthorized();
        _;
    }

    /**
     * @dev For operator filtering to be toggled on / off.
     */
    function _operatorFilteringEnabled() internal view override returns (bool) {
        return _flags & OPERATOR_FILTERING_ENABLED_FLAG != 0;
    }

    /**
     * @dev For skipping the operator check if the operator is the OpenSea Conduit.
     * If somehow, we use a different address in the future, it won't break functionality,
     * only increase the gas used back to what it will be with regular operator filtering.
     */
    function _isPriorityOperator(address operator) internal pure override returns (bool) {
        // OpenSea Seaport Conduit:
        // https://etherscan.io/address/0x1E0049783F008A0085193E00003D00cd54003c71
        // https://goerli.etherscan.io/address/0x1E0049783F008A0085193E00003D00cd54003c71
        return operator == address(0x1E0049783F008A0085193E00003D00cd54003c71);
    }

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
     * @dev Ensures that the caller is the Sound Automated Market (i.e. bonding curve minter).
     */
    modifier onlySAM() {
        if (msg.sender != sam) revert Unauthorized();
        _;
    }

    /**
     * @dev Ensures that the mint has not been concluded.
     */
    modifier onlyBeforeMintConcluded() {
        if (mintConcluded()) revert MintHasConcluded();
        _;
    }

    /**
     * @dev Ensures that the mint has been concluded.
     */
    modifier onlyAfterMintConcluded() {
        if (!mintConcluded()) revert MintNotConcluded();
        _;
    }

    /**
     * @dev Updates the mint randomness.
     * @param totalQuantity The total number of tokens to mint.
     */
    modifier updatesMintRandomness(uint256 totalQuantity) {
        if (mintRandomnessEnabled() && !mintConcluded()) {
            uint256 randomness = _mintRandomness;
            uint256 newRandomness = MintRandomnessLib.nextMintRandomness(
                randomness,
                _totalMinted(),
                totalQuantity,
                editionMaxMintable()
            );
            if (newRandomness != randomness) {
                _mintRandomness = uint72(newRandomness);
            }
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
            // Returns `bytes32(0)` if the strings are too long to be packed into a single word.
            bytes32 packed = LibString.packTwo(name_, symbol_);
            // If we cannot pack both strings into a single 32-byte word, store separately.
            // We need 2 bytes to store their lengths.
            if (packed == bytes32(0)) {
                ERC721AStorage.layout()._name = name_;
                ERC721AStorage.layout()._symbol = symbol_;
                return;
            }
            // Otherwise, pack them and store them into a single word.
            _shortNameAndSymbol = packed;
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
                (name_, symbol_) = LibString.unpackTwo(packed);
            } else {
                // Otherwise, load them from their separate variables.
                name_ = ERC721AStorage.layout()._name;
                symbol_ = ERC721AStorage.layout()._symbol;
            }
        }
    }

    /**
     * @dev Mints a big batch in mini batches to prevent expensive
     *      first-time transfer gas costs.
     * @param to       The address to mint to.
     * @param quantity The number of NFTs to mint.
     */
    function _batchMint(address to, uint256 quantity) internal {
        unchecked {
            if (quantity == 0) revert MintZeroQuantity();
            // Mint in mini batches of 32.
            uint256 i = quantity % 32;
            if (i != 0) _mint(to, i);
            while (i != quantity) {
                _mint(to, 32);
                i += 32;
            }
        }
    }

    /**
     * @dev Branchless or.
     */
    function _or(bool a, bool b) internal pure returns (bool c) {
        assembly {
            c := or(a, b)
        }
    }
}
