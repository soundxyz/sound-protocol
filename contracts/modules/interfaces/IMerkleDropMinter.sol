// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

/**
 * @title Mint interface for the `MerkleDropMinter`.
 */
interface IMerkleDropMinter is IMinterModule {
    function mint(
        address edition,
        uint256 mintId,
        uint32 requestedQuantity,
        bytes32[] calldata merkleProof
    ) external payable;
}
