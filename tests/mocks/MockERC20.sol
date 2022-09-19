// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MOCK", "MOCK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}
