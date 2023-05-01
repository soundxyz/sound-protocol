// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { BaseMinterV2 } from "@modules/BaseMinterV2.sol";
import { DelegateCashLib } from "@modules/utils/DelegateCashLib.sol";
import { IMerkleDropMinterV2, EditionMintData, MintInfo } from "./interfaces/IMerkleDropMinterV2.sol";
import { IMinterModuleV2 } from "@core/interfaces/IMinterModuleV2.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";

/**
 * @title MerkleDropMinterV2
 * @dev Module for minting Sound editions using a merkle tree of approved accounts.
 * @author Sound.xyz
 */
contract MerkleDropMinterV2 is IMerkleDropMinterV2, BaseMinterV2 {
    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev Edition mint data.
     *      `_baseDataSlot(_getBaseData(edition, mintId))` => value.
     */
    mapping(bytes32 => EditionMintData) internal _editionMintData;

    /**
     * @dev The number of mints for each account.
     *      `_baseDataSlot(_getBaseData(edition, mintId))` => `address` => value.
     *      We will simply store a uint256 for every account, to keep the Merkle tree
     *      simple, so that it is compatible with 3rd party allowlist services like Lanyard.
     */
    mapping(bytes32 => mapping(address => uint256)) internal _mintCounts;

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IMerkleDropMinterV2
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

        BaseData storage baseData = _getBaseDataUnchecked(edition, mintId);
        baseData.price = price;
        baseData.maxMintablePerAccount = maxMintablePerAccount;

        EditionMintData storage data = _editionMintData[_baseDataSlot(baseData)];
        data.merkleRootHash = merkleRootHash;
        data.maxMintable = maxMintable;

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
     * @inheritdoc IMerkleDropMinterV2
     */
    function mintTo(
        address edition,
        uint128 mintId,
        address to,
        uint32 quantity,
        address allowlisted,
        bytes32[] calldata proof,
        address affiliate,
        bytes32[] calldata affiliateProof,
        uint256 attributionId
    ) public payable {
        BaseData storage baseData = _getBaseData(edition, mintId);
        EditionMintData storage data = _editionMintData[_baseDataSlot(baseData)];

        // Increase `totalMinted` by `quantity`.
        // Require that the increased value does not exceed `maxMintable`.
        data.totalMinted = _incrementTotalMinted(data.totalMinted, quantity, data.maxMintable);

        // Verify that `allowlisted` is in the Merkle tree with the `proof`.
        // We also revert if `allowlisted` is the zero address to prevent libraries
        // that fill up partial Merkle trees with empty leafs from screwing things up.
        if (
            allowlisted == address(0) ||
            !MerkleProofLib.verifyCalldata(proof, data.merkleRootHash, _keccak256EncodePacked(allowlisted))
        ) revert InvalidMerkleProof();

        // To mint, either `msg.sender` or `to` must be equal to `allowlisted`,
        // or `msg.sender` must be a delegate of `allowlisted`.
        if (msg.sender != allowlisted && to != allowlisted)
            if (!DelegateCashLib.checkDelegateForAll(msg.sender, allowlisted)) revert CallerNotDelegated();

        unchecked {
            // Check that the additional `quantity` does not exceed the maximum mintable per account.
            // Won't overflow, as `maxMintablePerAccount` and `quantity` are 32 bits.
            if ((_mintCounts[_baseDataSlot(baseData)][allowlisted] += quantity) > baseData.maxMintablePerAccount)
                revert ExceedsMaxPerAccount();
        }

        _mintTo(edition, mintId, to, quantity, affiliate, affiliateProof, attributionId);

        emit DropClaimed(allowlisted, quantity);
    }

    /**
     * @inheritdoc IMerkleDropMinterV2
     */
    function mint(
        address edition,
        uint128 mintId,
        uint32 quantity,
        bytes32[] calldata proof,
        address affiliate
    ) public payable {
        mintTo(edition, mintId, msg.sender, quantity, msg.sender, proof, affiliate, MerkleProofLib.emptyProof(), 0);
    }

    /**
     * @inheritdoc IMerkleDropMinterV2
     */
    function setPrice(
        address edition,
        uint128 mintId,
        uint96 price
    ) public onlyEditionOwnerOrAdmin(edition) {
        _getBaseData(edition, mintId).price = price;
        emit PriceSet(edition, mintId, price);
    }

    /**
     * @inheritdoc IMerkleDropMinterV2
     */
    function setMaxMintablePerAccount(
        address edition,
        uint128 mintId,
        uint32 maxMintablePerAccount
    ) public onlyEditionOwnerOrAdmin(edition) {
        if (maxMintablePerAccount == 0) revert MaxMintablePerAccountIsZero();
        _getBaseData(edition, mintId).maxMintablePerAccount = maxMintablePerAccount;
        emit MaxMintablePerAccountSet(edition, mintId, maxMintablePerAccount);
    }

    /**
     * @inheritdoc IMerkleDropMinterV2
     */
    function setMaxMintable(
        address edition,
        uint128 mintId,
        uint32 maxMintable
    ) public onlyEditionOwnerOrAdmin(edition) {
        _editionMintData[_baseDataSlot(_getBaseData(edition, mintId))].maxMintable = maxMintable;
        emit MaxMintableSet(edition, mintId, maxMintable);
    }

    /*
     * @inheritdoc IMerkleDropMinterV2
     */
    function setMerkleRootHash(
        address edition,
        uint128 mintId,
        bytes32 merkleRootHash
    ) public onlyEditionOwnerOrAdmin(edition) {
        if (merkleRootHash == bytes32(0)) revert MerkleRootHashIsEmpty();
        _editionMintData[_baseDataSlot(_getBaseData(edition, mintId))].merkleRootHash = merkleRootHash;
        emit MerkleRootHashSet(edition, mintId, merkleRootHash);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IMerkleDropMinterV2
     */
    function mintCount(
        address edition,
        uint128 mintId,
        address to
    ) public view virtual returns (uint256) {
        return _mintCounts[_baseDataSlot(_getBaseData(edition, mintId))][to];
    }

    /**
     * @inheritdoc IMerkleDropMinterV2
     */
    function mintInfo(address edition, uint128 mintId) external view returns (MintInfo memory info) {
        BaseData storage baseData = _getBaseData(edition, mintId);
        EditionMintData storage mintData = _editionMintData[_baseDataSlot(baseData)];

        info.startTime = baseData.startTime;
        info.endTime = baseData.endTime;
        info.affiliateFeeBPS = baseData.affiliateFeeBPS;
        info.mintPaused = baseData.mintPaused;
        info.price = baseData.price;
        info.maxMintable = mintData.maxMintable;
        info.maxMintablePerAccount = baseData.maxMintablePerAccount;
        info.totalMinted = mintData.totalMinted;
        info.merkleRootHash = mintData.merkleRootHash;

        info.affiliateMerkleRoot = baseData.affiliateMerkleRoot;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, BaseMinterV2) returns (bool) {
        return BaseMinterV2.supportsInterface(interfaceId) || interfaceId == type(IMerkleDropMinterV2).interfaceId;
    }

    /**
     * @inheritdoc IMinterModuleV2
     */
    function moduleInterfaceId() public pure returns (bytes4) {
        return type(IMerkleDropMinterV2).interfaceId;
    }
}
