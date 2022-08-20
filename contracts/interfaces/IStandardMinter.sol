// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "./IBaseMinter.sol";

/**
 * @title Interface for the standard mint function.
 */
interface IStandardMinter is IBaseMinter {
    function mint(
        address edition,
        uint256 mintId,
        uint32 quantity
    ) external payable;
}
