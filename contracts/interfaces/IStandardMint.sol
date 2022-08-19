// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

/**
 * @title Interface for the standard mint function.
 */
interface IStandardMint {
    function mint(
        address edition,
        uint256 mintId,
        uint32 quantity
    ) external payable;
}
