// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";

contract MockMetadataModule is IMetadataModule {
    function tokenURI(
        uint256 /** tokenId */
    ) external pure returns (string memory) {
        return "MOCK";
    }
}
