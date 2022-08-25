// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { MerkleProof } from "openzeppelin/utils/cryptography/MerkleProof.sol";
import { EnumerableMap } from "openzeppelin/utils/structs/EnumerableMap.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { BaseMinter } from "@modules/BaseMinter.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { IMerkleDropMinter } from "./interfaces/IMerkleDropMinter.sol";

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

    mapping(address => mapping(uint256 => EditionMintData)) internal _editionMintData;

    // Tracking claimed amounts per wallet
    mapping(address => mapping(uint256 => EnumerableMap.AddressToUintMap)) claimed;

    // ================================
    // WRITE FUNCTIONS
    // ================================

    constructor(ISoundFeeRegistry feeRegistry_) BaseMinter(feeRegistry_) {}

    /**
     * @dev Initializes the configuration for an edition merkle drop mint.
     * @param edition Address of the song edition contract we are minting for.
     * @param merkleRootHash bytes32 hash of the Merkle tree representing eligible mints.
     * @param price_ Sale price in ETH for minting a single token in `edition`.
     * @param startTime Start timestamp of sale (in seconds since unix epoch).
     * @param endTime End timestamp of sale (in seconds since unix epoch).
     * @param maxMintable_ The maximum number of tokens that can can be minted for this sale.
     * @param maxMintablePerAccount_ The maximum number of tokens that a single wallet can mint.
     */
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

    /*
     * @dev Mints tokens.
     * @param edition Address of the song edition contract we are minting for.
     * @param mintId Id of the mint instance.
     * This is the maximum the user can claim.
     * @param requestedQuantity Number of tokens to actually mint. This can be anything up to the `maxMintablePerAccount`
     * @param merkleProof Merkle proof for the claim.
     * @param affiliate The affiliate's address. Set to the zero address if none.
     */
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

        _mint(edition, mintId, requestedQuantity, price(edition, mintId), affiliate);

        emit DropClaimed(msg.sender, requestedQuantity);
    }

    // ================================
    // VIEW FUNCTIONS
    // ================================

    /**
     * @dev Returns the amount of claimed tokens for `wallet` in `mintData`.
     * @param edition Address of the edition.
     * @param mintId Mint identifier.
     * @param wallet Address of the wallet.
     * @return claimedQuantity is defaulted to 0 when the wallet address key is not found
     * in the `claimed` map.
     */
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

    function maxMintable(address edition, uint256 mintId) public view returns (uint32) {
        return _editionMintData[edition][mintId].maxMintable;
    }

    function maxMintablePerAccount(address edition, uint256 mintId) public view returns (uint32) {
        return _editionMintData[edition][mintId].maxMintablePerAccount;
    }

    /**
     * @inheritdoc IMinterModule
     */
    function price(address edition, uint256 mintId) public view virtual override returns (uint256) {
        return _editionMintData[edition][mintId].price;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, BaseMinter) returns (bool) {
        return BaseMinter.supportsInterface(interfaceId) || interfaceId == type(IMerkleDropMinter).interfaceId;
    }
}
