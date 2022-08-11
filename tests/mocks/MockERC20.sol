// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "openzeppelin/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MOCK", "MOCK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}
