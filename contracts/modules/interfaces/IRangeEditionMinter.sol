// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

/**
 * @title Interface for the standard mint function.
 */
interface IRangeEditionMinter is IMinterModule {
    function mint(
        address edition,
        uint256 mintId,
        uint32 quantity
    ) external payable;
}
