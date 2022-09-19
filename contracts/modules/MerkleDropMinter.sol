// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { BaseMinter } from "@modules/BaseMinter.sol";
import { IMerkleDropMinter, EditionMintData, MintInfo } from "./interfaces/IMerkleDropMinter.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";

/**
 * @title MerkleDropMinter
 * @dev Module for minting Sound editions using a merkle tree of approved accounts.
 * @author Sound.xyz
 */
contract MerkleDropMinter is IMerkleDropMinter, BaseMinter {
    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev Edition mint data.
     *      Maps `edition` => `mintId` => value.
     */
    mapping(address => mapping(uint128 => EditionMintData)) internal _editionMintData;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor(ISoundFeeRegistry feeRegistry_) BaseMinter(feeRegistry_) {}

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IMerkleDropMinter
     */
    function createEditionMint(
        address edition,
        bytes32 merkleRootHash,
        uint96 price,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS,
        uint32 maxMintable,
        uint32 maxMintablePerAccount
    ) public returns (uint128 mintId) {
        if (merkleRootHash == bytes32(0)) revert MerkleRootHashIsEmpty();
        if (maxMintablePerAccount == 0) revert MaxMintablePerAccountIsZero();

        mintId = _createEditionMint(edition, startTime, endTime, affiliateFeeBPS);

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.merkleRootHash = merkleRootHash;
        data.price = price;
        data.maxMintable = maxMintable;
        data.maxMintablePerAccount = maxMintablePerAccount;
        // prettier-ignore
        emit MerkleDropMintCreated(
            edition,
            mintId,
            merkleRootHash,
            price,
            startTime,
            endTime,
            affiliateFeeBPS,
            maxMintable,
            maxMintablePerAccount
        );
    }

    /**
     * @inheritdoc IMerkleDropMinter
     */
    function mint(
        address edition,
        uint128 mintId,
        uint32 requestedQuantity,
        bytes32[] calldata merkleProof,
        address affiliate
    ) public payable {
        EditionMintData storage data = _editionMintData[edition][mintId];

        // Increase `totalMinted` by `requestedQuantity`.
        // Require that the increased value does not exceed `maxMintable`.
        data.totalMinted = _incrementTotalMinted(data.totalMinted, requestedQuantity, data.maxMintable);

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        bool valid = MerkleProofLib.verify(merkleProof, data.merkleRootHash, leaf);
        if (!valid) revert InvalidMerkleProof();

        unchecked {
            // Check the additional `requestedQuantity` does not exceed the maximum mintable per account.
            uint256 numberMinted = ISoundEditionV1(edition).numberMinted(msg.sender);
            // Won't overflow. The total number of tokens minted in `edition` won't exceed `type(uint32).max`,
            // and `quantity` has 32 bits.
            if (numberMinted + requestedQuantity > data.maxMintablePerAccount) revert ExceedsMaxPerAccount();
        }

        _mint(edition, mintId, requestedQuantity, affiliate);

        emit DropClaimed(msg.sender, requestedQuantity);
    }

    /**
     * @inheritdoc IMerkleDropMinter
     */
    function setPrice(
        address edition,
        uint128 mintId,
        uint96 price
    ) public onlyEditionOwnerOrAdmin(edition) {
        _editionMintData[edition][mintId].price = price;
        emit PriceSet(edition, mintId, price);
    }

    /**
     * @inheritdoc IMerkleDropMinter
     */
    function setMaxMintablePerAccount(
        address edition,
        uint128 mintId,
        uint32 maxMintablePerAccount
    ) public onlyEditionOwnerOrAdmin(edition) {
        if (maxMintablePerAccount == 0) revert MaxMintablePerAccountIsZero();
        _editionMintData[edition][mintId].maxMintablePerAccount = maxMintablePerAccount;
        emit MaxMintablePerAccountSet(edition, mintId, maxMintablePerAccount);
    }

    /**
     * @inheritdoc IMerkleDropMinter
     */
    function setMaxMintable(
        address edition,
        uint128 mintId,
        uint32 maxMintable
    ) public onlyEditionOwnerOrAdmin(edition) {
        _editionMintData[edition][mintId].maxMintable = maxMintable;
        emit MaxMintableSet(edition, mintId, maxMintable);
    }

    /*
     * @inheritdoc IMerkleDropMinter
     */
    function setMerkleRootHash(
        address edition,
        uint128 mintId,
        bytes32 merkleRootHash
    ) public onlyEditionOwnerOrAdmin(edition) {
        if (merkleRootHash == bytes32(0)) revert MerkleRootHashIsEmpty();

        _editionMintData[edition][mintId].merkleRootHash = merkleRootHash;
        emit MerkleRootHashSet(edition, mintId, merkleRootHash);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IMinterModule
     */
    function totalPrice(
        address edition,
        uint128 mintId,
        address, /* minter */
        uint32 quantity
    ) public view virtual override(BaseMinter, IMinterModule) returns (uint128) {
        unchecked {
            // Will not overflow, as `price` is 96 bits, and `quantity` is 32 bits. 96 + 32 = 128.
            return uint128(uint256(_editionMintData[edition][mintId].price) * uint256(quantity));
        }
    }

    /**
     * @inheritdoc IMerkleDropMinter
     */
    function mintInfo(address edition, uint128 mintId) external view returns (MintInfo memory) {
        BaseData memory baseData = _baseData[edition][mintId];
        EditionMintData storage mintData = _editionMintData[edition][mintId];

        MintInfo memory combinedMintData = MintInfo(
            baseData.startTime,
            baseData.endTime,
            baseData.affiliateFeeBPS,
            baseData.mintPaused,
            mintData.price,
            mintData.maxMintable,
            mintData.maxMintablePerAccount,
            mintData.totalMinted,
            mintData.merkleRootHash
        );

        return combinedMintData;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, BaseMinter) returns (bool) {
        return BaseMinter.supportsInterface(interfaceId) || interfaceId == type(IMerkleDropMinter).interfaceId;
    }

    /**
     * @inheritdoc IMinterModule
     */
    function moduleInterfaceId() public pure returns (bytes4) {
        return type(IMerkleDropMinter).interfaceId;
    }
}
