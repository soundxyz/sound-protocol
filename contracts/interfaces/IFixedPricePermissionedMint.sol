// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

/**
 * @title Mint interface for the `FixedPricePermissionedSaleMinter`.
 */
interface IFixedPricePermissionedMint {
    function mint(
        address edition,
        uint256 mintId,
        uint32 quantity,
        bytes calldata signature
    ) external payable;
}
