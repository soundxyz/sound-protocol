// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "../../contracts/modules/Minters/MintControllerBase.sol";

contract MockMinter is MintControllerBase {
    function createEditionMintController(address edition) external {
        _createEditionMintController(edition);
    }

    function deleteEditionMintController(address edition, uint256 mintId) external {
        _deleteEditionMintController(edition, mintId);
    }
}
