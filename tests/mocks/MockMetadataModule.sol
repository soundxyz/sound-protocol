// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IMetadataModule } from "contracts/core/interfaces/IMetadataModule.sol";

contract MockMetadataModule is IMetadataModule {
    function tokenURI(
        uint256 /** tokenId */
    ) external pure returns (string memory) {
        return "MOCK";
    }
}
