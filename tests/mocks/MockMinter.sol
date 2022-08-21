// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "@modules/BaseMinter.sol";

contract MockMinter is BaseMinter {
    function createEditionMint(
        address edition,
        uint32 startTime,
        uint32 endTime
    ) external returns (uint256 mintId) {
        mintId = _createEditionMint(edition, startTime, endTime);
    }

    function mint(
        address edition,
        uint256 mintId,
        uint32 quantity,
        uint256 price_
    ) external payable {
        _mint(edition, mintId, msg.sender, quantity, quantity * price_);
    }

    function price(
        address, /** edition */
        uint256 /** mintId */
    ) external pure returns (uint256) {
        return 0;
    }

    function maxMintable(
        address, /** edition */
        uint256 /** mintId */
    ) external pure returns (uint32) {
        return type(uint32).max;
    }

    function maxAllowedPerWallet(
        address, /** edition */
        uint256 /** mintId */
    ) external pure returns (uint32) {
        return type(uint32).max;
    }
}
