// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

/**
 * @title Mint interface for the `MerkleDropMinter`.
 */
interface IMerkleDropMinter is IMinterModule {
    event MerkleDropMintCreated(
        address indexed edition,
        uint256 indexed mintId,
        bytes32 merkleRootHash,
        uint256 price,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMintable,
        uint32 maxMintablePerAccount
    );

    event DropClaimed(address recipient, uint32 quantity);

    error InvalidMerkleProof();

    // The number of tokens minted has exceeded the number allowed for each wallet.
    error ExceedsMaxPerAccount();

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
    ) external returns (uint256 mintId);

    function mint(
        address edition,
        uint256 mintId,
        uint32 requestedQuantity,
        bytes32[] calldata merkleProof,
        address affiliate
    ) external payable;

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
    ) external view returns (uint256);
}
