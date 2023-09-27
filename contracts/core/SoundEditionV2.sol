// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IERC721AUpgradeable } from "chiru-labs/ERC721A-Upgradeable/IERC721AUpgradeable.sol";
import { ERC721AUpgradeable, ERC721AStorage } from "chiru-labs/ERC721A-Upgradeable/ERC721AUpgradeable.sol";
import { ERC721AQueryableUpgradeable } from "chiru-labs/ERC721A-Upgradeable/extensions/ERC721AQueryableUpgradeable.sol";
import { ERC721ABurnableUpgradeable } from "chiru-labs/ERC721A-Upgradeable/extensions/ERC721ABurnableUpgradeable.sol";
import { IERC2981Upgradeable } from "openzeppelin-upgradeable/interfaces/IERC2981Upgradeable.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { LibString } from "solady/utils/LibString.sol";
import { LibMap } from "solady/utils/LibMap.sol";
import { LibMulticaller } from "multicaller/LibMulticaller.sol";
import { ISoundEditionV2 } from "./interfaces/ISoundEditionV2.sol";
import { IMetadataModule } from "./interfaces/IMetadataModule.sol";

import { LibOps } from "./utils/LibOps.sol";
import { ArweaveURILib } from "./utils/ArweaveURILib.sol";
import { MintRandomnessLib } from "./utils/MintRandomnessLib.sol";

/**
 * @title SoundEditionV2
 * @notice The Sound Edition contract - a creator-owned, modifiable implementation of ERC721A.
 */
contract SoundEditionV2 is ISoundEditionV2, ERC721AQueryableUpgradeable, ERC721ABurnableUpgradeable, OwnableRoles {
    using ArweaveURILib for ArweaveURILib.URI;
    using LibMap for *;

    // =============================================================
    //                            STRUCTS
    // =============================================================

    /**
     * @dev A struct containing the tier data in storage.
     */
    struct TierData {
        // The current mint randomness state.
        uint64 mintRandomness;
        // The lower bound of the maximum number of tokens that can be minted for the tier.
        uint32 maxMintableLower;
        // The upper bound of the maximum number of tokens that can be minted for the tier.
        uint32 maxMintableUpper;
        // The timestamp (in seconds since unix epoch) after which the
        // max amount of tokens mintable for the tier will drop from
        // `maxMintableUpper` to `maxMintableLower`.
        uint32 cutoffTime;
        // The total number of tokens minted for the tier.
        uint32 minted;
        // The offset to the next tier data in the linked list.
        uint8 next;
        // Packed boolean flags.
        uint8 flags;
    }

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /**
     * @dev The GA tier. Which is 0.
     */
    uint8 public constant GA_TIER = 0;

    /**
     * @dev A role every minter module must have in order to mint new tokens.
     *      Note: this constant will always be 2 for past and future sound protocol contracts.
     */
    uint256 public constant MINTER_ROLE = LibOps.MINTER_ROLE;

    /**
     * @dev A role the owner can grant for performing admin actions.
     *      Note: this constant will always be 1 for past and future sound protocol contracts.
     */
    uint256 public constant ADMIN_ROLE = LibOps.ADMIN_ROLE;

    /**
     * @dev Basis points denominator used in fee calculations.
     */
    uint16 public constant BPS_DENOMINATOR = LibOps.BPS_DENOMINATOR;

    /**
     * @dev The interface ID for EIP-2981 (royaltyInfo)
     */
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    /**
     * @dev The boolean flag on whether the metadata is frozen.
     */
    uint8 private constant _METADATA_IS_FROZEN_FLAG = 1 << 0;

    /**
     * @dev The boolean flag on whether the ability to create a new tier is frozen.
     */
    uint8 private constant _CREATE_TIER_IS_FROZEN_FLAG = 1 << 1;

    /**
     * @dev The boolean flag on whether the tier has been created.
     */
    uint8 private constant _TIER_CREATED_FLAG = 1 << 0;

    /**
     * @dev The boolean flag on whether the tier has mint randomness enabled.
     */
    uint8 private constant _TIER_MINT_RANDOMNESS_ENABLED_FLAG = 1 << 1;

    /**
     * @dev The boolean flag on whether the tier is frozen.
     */
    uint8 private constant _TIER_IS_FROZEN_FLAG = 1 << 2;

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
     * @dev The royalty fee in basis points.
     */
    uint16 public royaltyBPS;

    /**
     * @dev Packed boolean flags.
     */
    uint8 private _flags;

    /**
     * @dev Metadata module used for `tokenURI` and `contractURI` if it is set.
     */
    address public metadataModule;

    /**
     * @dev The total number of tiers.
     */
    uint16 private _numTiers;

    /**
     * @dev The head of the tier data linked list.
     */
    uint8 private _tierDataHead;

    /**
     * @dev A mapping of `tier` => `tierData`.
     */
    mapping(uint256 => TierData) private _tierData;

    /**
     * @dev A packed mapping `tokenId` => `tier`.
     */
    LibMap.Uint8Map private _tokenTiers;

    /**
     * @dev A packed mapping of `tier` => `index` => `tokenId`.
     */
    mapping(uint256 => LibMap.Uint32Map) private _tierTokenIds;

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundEditionV2
     */
    function initialize(EditionInitialization memory init) public {
        // Will revert upon double initialization.
        _initializeERC721A(init.name, init.symbol);
        _initializeOwner(LibMulticaller.sender());

        _validateRoyaltyBPS(init.royaltyBPS);
        _validateFundingRecipient(init.fundingRecipient);

        _baseURIStorage.initialize(init.baseURI);
        _contractURIStorage.initialize(init.contractURI);

        fundingRecipient = init.fundingRecipient;

        unchecked {
            uint256 n = init.tierCreations.length;
            if (n == 0) revert ZeroTiersProvided();
            for (uint256 i; i != n; ++i) {
                _createTier(init.tierCreations[i]);
            }
        }

        metadataModule = init.metadataModule;
        royaltyBPS = init.royaltyBPS;

        _flags =
            LibOps.toFlag(init.isMetadataFrozen, _METADATA_IS_FROZEN_FLAG) |
            LibOps.toFlag(init.isCreateTierFrozen, _CREATE_TIER_IS_FROZEN_FLAG);

        emit SoundEditionInitialized(init);
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function mint(
        uint8 tier,
        address to,
        uint256 quantity
    ) external payable onlyRolesOrOwner(ADMIN_ROLE | MINTER_ROLE) returns (uint256 fromTokenId) {
        fromTokenId = _beforeTieredMint(tier, quantity);
        _batchMint(to, quantity);
        emit Minted(tier, to, quantity, fromTokenId);
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function airdrop(
        uint8 tier,
        address[] calldata to,
        uint256 quantity
    ) external payable onlyRolesOrOwner(ADMIN_ROLE) returns (uint256 fromTokenId) {
        unchecked {
            // Multiplication overflow is not possible due to the max block gas limit.
            // If `quantity` is too big (e.g. 2**64), the loop in `_batchMint` will run out of gas.
            // If `to.length` is too big (e.g. 2**64), the airdrop mint loop will run out of gas.
            fromTokenId = _beforeTieredMint(tier, to.length * quantity);
            for (uint256 i; i != to.length; ++i) {
                _batchMint(to[i], quantity);
            }
        }
        emit Airdropped(tier, to, quantity, fromTokenId);
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function withdrawETH() external {
        uint256 amount = address(this).balance;
        address recipient = fundingRecipient;
        SafeTransferLib.forceSafeTransferETH(recipient, amount);
        emit ETHWithdrawn(recipient, amount, msg.sender);
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function withdrawERC20(address[] calldata tokens) external {
        unchecked {
            uint256[] memory amounts = new uint256[](tokens.length);
            address recipient = fundingRecipient;
            for (uint256 i; i != tokens.length; ++i) {
                amounts[i] = SafeTransferLib.safeTransferAll(tokens[i], recipient);
            }
            emit ERC20Withdrawn(recipient, tokens, amounts, msg.sender);
        }
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function setMetadataModule(address module) external onlyRolesOrOwner(ADMIN_ROLE) {
        _requireMetadataNotFrozen();
        metadataModule = module;
        emit MetadataModuleSet(module);
        emitAllMetadataUpdate();
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function setBaseURI(string memory uri) external onlyRolesOrOwner(ADMIN_ROLE) {
        _requireMetadataNotFrozen();
        _baseURIStorage.update(uri);
        emit BaseURISet(uri);
        emitAllMetadataUpdate();
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function setContractURI(string memory uri) public onlyRolesOrOwner(ADMIN_ROLE) {
        _requireMetadataNotFrozen();
        _contractURIStorage.update(uri);
        emit ContractURISet(uri);
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function freezeMetadata() public onlyRolesOrOwner(ADMIN_ROLE) {
        _requireMetadataNotFrozen();
        _flags |= _METADATA_IS_FROZEN_FLAG;
        emit MetadataFrozen(metadataModule, baseURI(), contractURI());
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function freezeCreateTier() public onlyRolesOrOwner(ADMIN_ROLE) {
        _requireCreateTierNotFrozen();
        _flags |= _CREATE_TIER_IS_FROZEN_FLAG;
        emit CreateTierFrozen();
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function setFundingRecipient(address recipient) public onlyRolesOrOwner(ADMIN_ROLE) {
        _setFundingRecipient(recipient);
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function createSplit(address splitMain, bytes calldata splitData)
        public
        onlyRolesOrOwner(ADMIN_ROLE)
        returns (address split)
    {
        assembly {
            // Grab the free memory pointer.
            let m := mload(0x40)
            // Copy the `splitData` into the free memory.
            calldatacopy(m, splitData.offset, splitData.length)
            // Zeroize 0x00, so that if the call doesn't return anything, `split` will be the zero address.
            mstore(0x00, 0)
            // Call the `splitMain`, reverting if the call fails.
            if iszero(
                call(
                    gas(), // Gas remaining.
                    splitMain, // Address of the SplitMain.
                    0, // Send 0 ETH.
                    m, // Start of the `splitData` in memory.
                    splitData.length, // Length of `splitData`.
                    0x00, // Start of returndata.
                    0x20 // Length of returndata.
                )
            ) {
                // Bubble up the revert if the call reverts.
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
            split := mload(0x00)
        }
        _setFundingRecipient(split);
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function setRoyalty(uint16 bps) public onlyRolesOrOwner(ADMIN_ROLE) {
        _validateRoyaltyBPS(bps);
        royaltyBPS = bps;
        emit RoyaltySet(bps);
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function setMaxMintableRange(
        uint8 tier,
        uint32 lower,
        uint32 upper
    ) public onlyRolesOrOwner(ADMIN_ROLE) {
        TierData storage d = _getTierData(tier);
        _requireNotFrozen(d);
        _requireBeforeMintConcluded(d);
        uint256 minted = d.minted;

        if (minted != 0) {
            // Disallow increasing either lower or upper.
            if (LibOps.or(lower > d.maxMintableLower, upper > d.maxMintableUpper)) revert InvalidMaxMintableRange();
            // If either is below `minted`, set to `minted`.
            lower = uint32(LibOps.max(lower, minted));
            upper = uint32(LibOps.max(upper, minted));
        }

        if (lower > upper) revert InvalidMaxMintableRange();

        d.maxMintableLower = lower;
        d.maxMintableUpper = upper;

        emit MaxMintableRangeSet(tier, lower, upper);
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function freezeTier(uint8 tier) public onlyRolesOrOwner(ADMIN_ROLE) {
        TierData storage d = _getTierData(tier);
        _requireNotFrozen(d);
        d.flags |= _TIER_IS_FROZEN_FLAG;
        emit TierFrozen(tier);
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function setCutoffTime(uint8 tier, uint32 cutoff) public onlyRolesOrOwner(ADMIN_ROLE) {
        TierData storage d = _getTierData(tier);
        _requireNotFrozen(d);
        _requireBeforeMintConcluded(d);
        d.cutoffTime = cutoff;
        emit CutoffTimeSet(tier, cutoff);
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function createTier(TierCreation memory creation) public onlyRolesOrOwner(ADMIN_ROLE) {
        _requireCreateTierNotFrozen();
        _createTier(creation);
        emit TierCreated(creation);
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function setMintRandomnessEnabled(uint8 tier, bool enabled) public onlyRolesOrOwner(ADMIN_ROLE) {
        TierData storage d = _getTierData(tier);
        _requireNotFrozen(d);
        _requireNoTierMints(d);
        d.flags = LibOps.setFlagTo(d.flags, _TIER_MINT_RANDOMNESS_ENABLED_FLAG, enabled);
        emit MintRandomnessEnabledSet(tier, enabled);
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function emitAllMetadataUpdate() public {
        emit BatchMetadataUpdate(_startTokenId(), _nextTokenId() - 1);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundEditionV2
     */
    function editionInfo() public view returns (EditionInfo memory info) {
        info.baseURI = baseURI();
        info.contractURI = contractURI();
        (info.name, info.symbol) = _loadNameAndSymbol();
        info.fundingRecipient = fundingRecipient;
        info.metadataModule = metadataModule;
        info.isMetadataFrozen = isMetadataFrozen();
        info.isCreateTierFrozen = isCreateTierFrozen();
        info.royaltyBPS = royaltyBPS;
        info.nextTokenId = nextTokenId();
        info.totalMinted = totalMinted();
        info.totalBurned = totalBurned();
        info.totalSupply = totalSupply();

        unchecked {
            uint256 n = _numTiers; // Linked-list length.
            uint8 p = _tierDataHead; // Current linked-list pointer.
            info.tierInfo = new TierInfo[](n);
            // Traverse the linked-list and fill the array in reverse.
            // Front: earliest added tier. Back: latest added tier.
            while (n != 0) {
                TierData storage d = _getTierData(p);
                info.tierInfo[--n] = tierInfo(p);
                p = d.next;
            }
        }
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function tierInfo(uint8 tier) public view returns (TierInfo memory info) {
        TierData storage d = _getTierData(tier);
        info.tier = tier;
        info.maxMintable = _maxMintable(d);
        info.maxMintableLower = d.maxMintableLower;
        info.maxMintableUpper = d.maxMintableUpper;
        info.cutoffTime = d.cutoffTime;
        info.minted = d.minted;
        info.mintRandomness = _mintRandomness(d);
        info.mintRandomnessEnabled = _mintRandomnessEnabled(d);
        info.mintConcluded = _mintConcluded(d);
        info.isFrozen = _isFrozen(d);
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function isFrozen(uint8 tier) public view returns (bool) {
        return _isFrozen(_getTierData(tier));
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function isMetadataFrozen() public view returns (bool) {
        return _flags & _METADATA_IS_FROZEN_FLAG != 0;
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function isCreateTierFrozen() public view returns (bool) {
        return _flags & _CREATE_TIER_IS_FROZEN_FLAG != 0;
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function nextTokenId() public view returns (uint256) {
        return _nextTokenId();
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function numberBurned(address owner) public view returns (uint256) {
        return _numberBurned(owner);
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function totalMinted() public view returns (uint256) {
        return _totalMinted();
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function totalBurned() public view returns (uint256) {
        return _totalBurned();
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function tokenTier(uint256 tokenId) public view returns (uint8) {
        if (!_exists(tokenId)) revert TierQueryForNonexistentToken();
        return _tokenTiers.get(tokenId);
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function explicitTokenTier(uint256 tokenId) public view returns (uint8) {
        return _tokenTiers.get(tokenId);
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function tokenTiers(uint256[] calldata tokenIds) public view returns (uint8[] memory tiers) {
        unchecked {
            tiers = new uint8[](tokenIds.length);
            for (uint256 i; i != tokenIds.length; ++i) {
                tiers[i] = _tokenTiers.get(tokenIds[i]);
            }
        }
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function tierMinted(uint8 tier) public view returns (uint32) {
        return _getTierData(tier).minted;
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function tierTokenIds(uint8 tier) public view returns (uint256[] memory tokenIds) {
        tokenIds = tierTokenIdsIn(tier, 0, tierMinted(tier));
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function tierTokenIdsIn(
        uint8 tier,
        uint256 start,
        uint256 stop
    ) public view returns (uint256[] memory tokenIds) {
        unchecked {
            uint256 l = stop - start;
            uint256 n = tierMinted(tier);
            if (LibOps.or(start >= stop, stop > n)) revert InvalidQueryRange();
            tokenIds = new uint256[](l);
            LibMap.Uint32Map storage m = _tierTokenIds[tier];
            for (uint256 i; i != l; ++i) {
                tokenIds[i] = m.get(start + i);
            }
        }
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function tierTokenIdIndex(uint256 tokenId) public view returns (uint256) {
        uint8 tier = tokenTier(tokenId);
        (bool found, uint256 index) = _tierTokenIds[tier].searchSorted(uint32(tokenId), 0, tierMinted(tier));
        return LibOps.and(tokenId < 1 << 32, found) ? index : type(uint256).max;
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function mintRandomness(uint8 tier) public view returns (uint256 result) {
        return _mintRandomness(_getTierData(tier));
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function mintConcluded(uint8 tier) public view returns (bool) {
        return _mintConcluded(_getTierData(tier));
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function maxMintable(uint8 tier) public view returns (uint32) {
        return _maxMintable(_getTierData(tier));
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function maxMintableUpper(uint8 tier) public view returns (uint32) {
        return _getTierData(tier).maxMintableUpper;
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function maxMintableLower(uint8 tier) public view returns (uint32) {
        return _getTierData(tier).maxMintableLower;
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function cutoffTime(uint8 tier) public view returns (uint32) {
        return _getTierData(tier).cutoffTime;
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function mintRandomnessEnabled(uint8 tier) public view returns (bool) {
        return _mintRandomnessEnabled(_getTierData(tier));
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function mintRandomnessOneOfOne(uint8 tier) public view returns (uint32) {
        TierData storage d = _getTierData(tier);
        uint256 r = _mintRandomness(d);
        uint256 n = _maxMintable(d);
        return LibOps.or(r == 0, n == 0) ? 0 : _tierTokenIds[tier].get(LibOps.rawMod(r, n));
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
        return explicitTokenURI(tokenId);
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function explicitTokenURI(uint256 tokenId) public view returns (string memory) {
        if (metadataModule != address(0)) return IMetadataModule(metadataModule).tokenURI(tokenId);
        string memory baseURI_ = baseURI();
        return bytes(baseURI_).length != 0 ? string.concat(baseURI_, _toString(tokenId)) : "";
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ISoundEditionV2, ERC721AUpgradeable, IERC721AUpgradeable)
        returns (bool)
    {
        return
            LibOps.or(
                interfaceId == type(ISoundEditionV2).interfaceId,
                ERC721AUpgradeable.supportsInterface(interfaceId),
                interfaceId == _INTERFACE_ID_ERC2981
            );
    }

    /**
     * @inheritdoc IERC2981Upgradeable
     */
    function royaltyInfo(
        uint256, // tokenId
        uint256 salePrice
    ) public view override(IERC2981Upgradeable) returns (address recipient, uint256 royaltyAmount) {
        recipient = fundingRecipient;
        if (salePrice >= 1 << 240) LibOps.revertOverflow(); // `royaltyBPS` is uint16. `256 - 16 = 240`.
        royaltyAmount = LibOps.rawMulDiv(salePrice, royaltyBPS, BPS_DENOMINATOR);
    }

    /**
     * @inheritdoc IERC721AUpgradeable
     */
    function name() public view override(ERC721AUpgradeable, IERC721AUpgradeable) returns (string memory name_) {
        (name_, ) = _loadNameAndSymbol();
    }

    /**
     * @inheritdoc IERC721AUpgradeable
     */
    function symbol() public view override(ERC721AUpgradeable, IERC721AUpgradeable) returns (string memory symbol_) {
        (, symbol_) = _loadNameAndSymbol();
    }

    /**
     * @inheritdoc ISoundEditionV2
     */
    function baseURI() public view returns (string memory) {
        return _baseURIStorage.load();
    }

    /**
     * @inheritdoc ISoundEditionV2
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
        _requireOnlyRolesOrOwner(roles);
        _;
    }

    /**
     * @dev Require that the caller has any of the `roles`, or is the owner of the contract.
     * @param roles A roles bitmap.
     */
    function _requireOnlyRolesOrOwner(uint256 roles) internal view {
        address sender = LibMulticaller.sender();
        if (!hasAnyRole(sender, roles))
            if (sender != owner()) LibOps.revertUnauthorized();
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
    function _validateRoyaltyBPS(uint16 bps) internal pure {
        if (bps > BPS_DENOMINATOR) revert InvalidRoyaltyBPS();
    }

    /**
     * @dev Ensures the funding recipient is not the zero address.
     * @param recipient The funding recipient.
     */
    function _validateFundingRecipient(address recipient) internal pure {
        if (recipient == address(0)) revert InvalidFundingRecipient();
    }

    /**
     * @dev Reverts if the metadata is frozen.
     */
    function _requireMetadataNotFrozen() internal view {
        if (isMetadataFrozen()) revert MetadataIsFrozen();
    }

    /**
     * @dev Reverts if the max tier is frozen.
     */
    function _requireCreateTierNotFrozen() internal view {
        if (isCreateTierFrozen()) revert CreateTierIsFrozen();
    }

    /**
     * @dev Reverts if there are any mints.
     */
    function _requireNoMints() internal view {
        if (_totalMinted() != 0) revert MintsAlreadyExist();
    }

    /**
     * @dev Reverts if there are any mints for the tier.
     * @param d The tier data.
     */
    function _requireNoTierMints(TierData storage d) internal view {
        if (d.minted != 0) revert TierMintsAlreadyExist();
    }

    /**
     * @dev Create a new tier.
     * @param c The tier creation struct.
     */
    function _createTier(TierCreation memory c) internal {
        uint8 tier = c.tier;
        TierData storage d = _tierData[tier];
        if (d.flags & _TIER_CREATED_FLAG != 0) revert TierAlreadyExists();

        // If GA, overwrite any immutable variables as required.
        if (tier == GA_TIER) {
            c.maxMintableLower = type(uint32).max;
            c.maxMintableUpper = type(uint32).max;
            c.cutoffTime = type(uint32).max;
            c.mintRandomnessEnabled = false;
            c.isFrozen = true;
        } else {
            if (c.maxMintableLower > c.maxMintableUpper) revert InvalidMaxMintableRange();
        }

        d.maxMintableLower = c.maxMintableLower;
        d.maxMintableUpper = c.maxMintableUpper;
        d.cutoffTime = c.cutoffTime;
        d.flags =
            _TIER_CREATED_FLAG |
            LibOps.toFlag(c.mintRandomnessEnabled, _TIER_MINT_RANDOMNESS_ENABLED_FLAG) |
            LibOps.toFlag(c.isFrozen, _TIER_IS_FROZEN_FLAG);

        unchecked {
            uint16 n = uint16(uint256(_numTiers) + 1); // `_numTiers` is uint16. `tier` is uint8.
            d.next = _tierDataHead;
            _numTiers = n;
            _tierDataHead = tier;
        }
    }

    /**
     * @dev Sets the funding recipient address.
     * @param recipient Address to be set as the new funding recipient.
     */
    function _setFundingRecipient(address recipient) internal {
        _validateFundingRecipient(recipient);
        fundingRecipient = recipient;
        emit FundingRecipientSet(recipient);
    }

    /**
     * @dev Ensures that the tier is not frozen.
     * @param d The tier data.
     */
    function _requireNotFrozen(TierData storage d) internal view {
        if (_isFrozen(d)) revert TierIsFrozen();
    }

    /**
     * @dev Ensures that the mint has not been concluded.
     * @param d The tier data.
     */
    function _requireBeforeMintConcluded(TierData storage d) internal view {
        if (_mintConcluded(d)) revert MintHasConcluded();
    }

    /**
     * @dev Ensures that the mint has been concluded.
     * @param d The tier data.
     */
    function _requireAfterMintConcluded(TierData storage d) internal view {
        if (!_mintConcluded(d)) revert MintNotConcluded();
    }

    /**
     * @dev Append to the tier token IDs and the token tiers arrays.
     * Reverts if there is insufficient supply.
     * @param tier     The tier.
     * @param quantity The total number of tokens to mint.
     */
    function _beforeTieredMint(uint8 tier, uint256 quantity) internal returns (uint256 fromTokenId) {
        unchecked {
            if (quantity == 0) revert MintZeroQuantity();
            fromTokenId = _nextTokenId();

            // To ensure that we won't store a token ID above 2**31 - 1 in `_tierTokenIds`.
            if (fromTokenId + quantity - 1 >= 1 << 32) LibOps.revertOverflow();

            TierData storage d = _getTierData(tier);

            uint256 minted = d.minted; // uint32.
            uint256 limit = _maxMintable(d); // uint32.

            // Check that the mints will not exceed the available supply.
            uint256 finalMinted = minted + quantity;
            if (finalMinted > limit) revert ExceedsAvailableSupply();

            d.minted = uint32(finalMinted);

            // Update the mint randomness state if required.
            if (_mintRandomnessEnabled(d))
                d.mintRandomness = uint64(
                    MintRandomnessLib.nextMintRandomness(d.mintRandomness, minted, quantity, limit)
                );

            LibMap.Uint32Map storage m = _tierTokenIds[tier];
            for (uint256 i; i != quantity; ++i) {
                m.set(minted + i, uint32(fromTokenId + i)); // Set the token IDs for the tier.
                if (tier != 0) _tokenTiers.set(fromTokenId + i, tier); // Set the tier for the token ID.
            }
        }
    }

    /**
     * @dev Returns the full mint randomness for the tier.
     * @param d The tier data.
     * @return result The full mint randomness.
     */
    function _mintRandomness(TierData storage d) internal view returns (uint256 result) {
        if (_mintRandomnessEnabled(d) && _mintConcluded(d)) {
            result = d.mintRandomness;
            assembly {
                mstore(0x00, result)
                mstore(0x20, address())
                result := keccak256(0x00, 0x40)
                result := add(iszero(result), result)
            }
        }
    }

    /**
     * @dev Returns whether the mint has concluded for the tier.
     * @param d The tier data.
     * @return Whether the mint has concluded.
     */
    function _mintConcluded(TierData storage d) internal view returns (bool) {
        return d.minted >= _maxMintable(d);
    }

    /**
     * @dev Returns whether the mint has mint randomness enabled.
     * @param d The tier data.
     * @return Whether mint randomness is enabled.
     */
    function _mintRandomnessEnabled(TierData storage d) internal view returns (bool) {
        return d.flags & _TIER_MINT_RANDOMNESS_ENABLED_FLAG != 0;
    }

    /**
     * @dev Returns the current max mintable supply for the tier.
     * @param d The tier data.
     * @return The current max mintable supply.
     */
    function _maxMintable(TierData storage d) internal view returns (uint32) {
        if (block.timestamp < d.cutoffTime) return d.maxMintableUpper;
        return uint32(LibOps.max(d.maxMintableLower, d.minted));
    }

    /**
     * @dev Returns whether the tier is frozen.
     * @param d The tier data.
     * @return Whether the tier is frozen.
     */
    function _isFrozen(TierData storage d) internal view returns (bool) {
        return d.flags & _TIER_IS_FROZEN_FLAG != 0;
    }

    /**
     * @dev Returns a storage pointer to the tier data, reverting if the tier does not exist.
     * @param tier The tier.
     * @return d A storage pointer to the tier data.
     */
    function _getTierData(uint8 tier) internal view returns (TierData storage d) {
        d = _tierData[tier];
        if (d.flags & _TIER_CREATED_FLAG == 0) revert TierDoesNotExist();
    }

    /**
     * @dev Helper function for initializing the ERC721A class.
     * @param name_   Name of the collection.
     * @param symbol_ Symbol of the collection.
     */
    function _initializeERC721A(string memory name_, string memory symbol_) internal {
        ERC721AStorage.Layout storage layout = ERC721AStorage.layout();

        // Prevent double initialization.
        // We can "cheat" here and avoid the initializer modifier to save a SSTORE,
        // since the `_nextTokenId()` is defined to always return 1.
        if (layout._currentIndex != 0) LibOps.revertUnauthorized();
        layout._currentIndex = _startTokenId();

        // Returns `bytes32(0)` if the strings are too long to be packed into a single word.
        bytes32 packed = LibString.packTwo(name_, symbol_);
        // If we cannot pack both strings into a single 32-byte word, store separately.
        // We need 2 bytes to store their lengths.
        if (packed == bytes32(0)) {
            layout._name = name_;
            layout._symbol = symbol_;
        } else {
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
        bytes32 packed = _shortNameAndSymbol;
        // If the strings have been previously packed.
        if (packed != bytes32(0)) {
            (name_, symbol_) = LibString.unpackTwo(packed);
        } else {
            // Otherwise, load them from their separate variables.
            ERC721AStorage.Layout storage layout = ERC721AStorage.layout();
            name_ = layout._name;
            symbol_ = layout._symbol;
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
            // Mint in mini batches of 32.
            uint256 i = quantity % 32;
            if (i != 0) _mint(to, i);
            while (i != quantity) {
                _mint(to, 32);
                i += 32;
            }
        }
    }
}
