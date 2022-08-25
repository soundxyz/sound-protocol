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
        _mint(edition, mintId, quantity, totalPrice(edition, mintId, quantity), affiliate);
    }

    function mint(
        address edition,
        uint256 mintId,
        uint32 quantity
    ) external payable {
        _mint(edition, mintId, quantity, totalPrice(edition, mintId, quantity));
    }

    function maxMintable(
        address, /** edition */
        uint256 /** mintId */
    ) external pure returns (uint32) {
        return type(uint32).max;
    }

    function maxMintablePerAccount(
        address, /** edition */
        uint256 /** mintId */
    ) external pure returns (uint32) {
        return type(uint32).max;
    }

    function totalPrice(
        address, /** edition */
        uint256, /** mintId */
        uint256 quantity
    ) public view virtual override returns (uint256) {
        return _currentPrice * quantity;
    }

    function setPrice(uint256 price_) external {
        _currentPrice = price_;
    }
}
