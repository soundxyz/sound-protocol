// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "../../contracts/modules/Metadata/IMetadataModule.sol";

contract MockMetadataModule is IMetadataModule {
    function tokenURI(
        uint256 /** tokenId */
    ) external pure returns (string memory) {
        return "MOCK";
    }
}
