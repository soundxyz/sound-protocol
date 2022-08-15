// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "../../contracts/modules/Minters/MintControllerBase.sol";

contract MockMinter is MintControllerBase {
    function createEditionMintController(address edition) external returns (uint256 mintId) {
        mintId = _createEditionMintController(edition, 0, type(uint32).max);
    }

    function deleteEditionMintController(address edition, uint256 mintId) external {
        _deleteEditionMintController(edition, mintId);
    }

    function mint(
        address edition,
        uint256 mintId,
        uint32 quantity,
        uint256 price
    ) external payable {
        _mint(edition, mintId, msg.sender, quantity, quantity * price);
    }

    function price(address edition, uint256 mintId) external view returns (uint256) {
        return 0;
    }

    function maxMintable(address edition, uint256 mintId) external view returns (uint32) {
        return type(uint32).max;
    }

    function maxAllowedPerWallet(address edition, uint256 mintId) external view returns (uint32) {
        return type(uint32).max;
    }
}
