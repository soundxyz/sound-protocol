// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

/**
 * @title Mint interface for the `MerkleDropMinter`.
 */
interface IMerkleDropMint {
    function mint(
        address edition,
        uint256 mintId,
        uint32 requestedQuantity,
        bytes32[] calldata merkleProof
    ) external payable;
}
