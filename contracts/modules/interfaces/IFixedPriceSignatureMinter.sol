// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

/**
 * @title Mint interface for the `FixedPriceSignatureMinter`.
 */
interface IFixedPriceSignatureMinter is IMinterModule {
    function mint(
        address edition,
        uint256 mintId,
        uint32 quantity,
        bytes calldata signature
    ) external payable;
}
