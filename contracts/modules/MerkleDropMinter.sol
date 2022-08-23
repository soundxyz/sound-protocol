// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { MerkleProof } from "openzeppelin/utils/cryptography/MerkleProof.sol";
import { EnumerableMap } from "openzeppelin/utils/structs/EnumerableMap.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { BaseMinter } from "@modules/BaseMinter.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { IMerkleDropMinter } from "./interfaces/IMerkleDropMinter.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

/// @dev Airdrop using merkle tree logic.
contract MerkleDropMinter is IMerkleDropMinter, BaseMinter {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    struct EditionMintData {
        // Hash of the root node for the merkle tree drop
        bytes32 merkleRootHash;
        // The price at which each token will be sold, in ETH.
        uint256 price;
        // The maximum number of tokens that can can be minted for this sale.
        uint32 maxMintable;
        // The maximum number of tokens that a wallet can mint.
        uint32 maxMintablePerAccount;
        // The total number of tokens minted so far for this sale.
        uint32 totalMinted;
    }

    /**
     * @dev Edition mint data
     * edition => mintId => EditionMintData
     */
    mapping(address => mapping(uint256 => EditionMintData)) internal _editionMintData;

    /**
     * @dev Tracks claimed amounts per account.
     * edition => mintId => enumerable map (address => claimed balance)
     */
    mapping(address => mapping(uint256 => EnumerableMap.AddressToUintMap)) claimed;

    // ================================
    // WRITE FUNCTIONS
    // ================================

    /// @inheritdoc IMerkleDropMinter
    function createEditionMint(
        address edition,
        bytes32 merkleRootHash,
        uint256 price_,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMintable_,
        uint32 maxMintablePerAccount_
    ) public returns (uint256 mintId) {
        mintId = _createEditionMint(edition, startTime, endTime);

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.merkleRootHash = merkleRootHash;
        data.price = price_;
        data.maxMintable = maxMintable_;
        data.maxMintablePerAccount = maxMintablePerAccount_;
        // prettier-ignore
        emit MerkleDropMintCreated(
            edition,
            mintId,
            merkleRootHash,
            price_,
            startTime,
            endTime,
            maxMintable_,
            maxMintablePerAccount_
        );
    }

    /// @inheritdoc IMerkleDropMinter
    function mint(
        address edition,
        uint256 mintId,
        uint32 requestedQuantity,
        bytes32[] calldata merkleProof,
        address affiliate
    ) public payable {
        EditionMintData storage data = _editionMintData[edition][mintId];

        uint32 nextTotalMinted = data.totalMinted + requestedQuantity;
        _requireNotSoldOut(nextTotalMinted, data.maxMintable);
        data.totalMinted = nextTotalMinted;

        uint256 updatedClaimedQuantity = getClaimed(edition, mintId, msg.sender) + requestedQuantity;

        // Revert if attempting to mint more than the max allowed per wallet.
        if (updatedClaimedQuantity > maxMintablePerAccount(edition, mintId)) revert ExceedsMaxPerAccount();

        // Update the claimed amount data
        claimed[edition][mintId].set(msg.sender, updatedClaimedQuantity);

        bytes32 leaf = keccak256(abi.encodePacked(edition, msg.sender));
        bool valid = MerkleProof.verify(merkleProof, data.merkleRootHash, leaf);
        if (!valid) revert InvalidMerkleProof();

        _mint(edition, mintId, requestedQuantity, affiliate);

        emit DropClaimed(msg.sender, requestedQuantity);
    }

    // ================================
    // VIEW FUNCTIONS
    // ================================

    /// @inheritdoc IMerkleDropMinter
    function getClaimed(
        address edition,
        uint256 mintId,
        address wallet
    ) public view returns (uint256) {
        (bool success, uint256 claimedQuantity) = claimed[edition][mintId].tryGet(wallet);
        claimedQuantity = success ? claimedQuantity : 0;
        return claimedQuantity;
    }

    /**
     * @dev Returns the `EditionMintData` for `edition.
     * @param edition Address of the song edition contract we are minting for.
     */
    function editionMintData(address edition, uint256 mintId) public view returns (EditionMintData memory) {
        return _editionMintData[edition][mintId];
    }

    /// @inheritdoc IMinterModule
    function price(address edition, uint256 mintId) public view returns (uint256) {
        return _editionMintData[edition][mintId].price;
    }

    /// @inheritdoc IMinterModule
    function maxMintable(address edition, uint256 mintId) public view returns (uint32) {
        return _editionMintData[edition][mintId].maxMintable;
    }

    /// @inheritdoc IMinterModule
    function maxMintablePerAccount(address edition, uint256 mintId) public view returns (uint32) {
        return _editionMintData[edition][mintId].maxMintablePerAccount;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, BaseMinter) returns (bool) {
        return BaseMinter.supportsInterface(interfaceId) || interfaceId == type(IMerkleDropMinter).interfaceId;
    }

    // ================================
    // INTERNAL FUNCTIONS
    // ================================

    function _baseTotalPrice(
        address edition,
        uint256 mintId,
        address, /* minter */
        uint32 quantity
    ) internal view virtual override returns (uint256) {
        return _editionMintData[edition][mintId].price * quantity;
    }
}
