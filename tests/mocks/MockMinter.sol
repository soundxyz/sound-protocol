// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { BaseMinter } from "@modules/BaseMinter.sol";

contract MockMinter is BaseMinter {
    uint256 private _currentPrice;

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
        address affiliate
    ) external payable {
        _mint(edition, mintId, quantity, affiliate);
    }

    function setPrice(uint128 price_) external {
        _currentPrice = price_;
    }

    // ================================
    // INTERNAL FUNCTIONS
    // ================================

    function _baseTotalPrice(
        address, /* edition */
        uint256, /* mintId */
        address, /* minter */
        uint32 quantity
    ) internal view virtual override returns (uint256) {
        return _currentPrice * quantity;
    }
}
