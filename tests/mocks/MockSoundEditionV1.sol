// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { SoundEditionV1 } from "contracts/core/SoundEditionV1.sol";

contract MockSoundEditionV1 is SoundEditionV1 {
    function mint(uint256 quantity) external payable {
        _mint(msg.sender, quantity);
    }
}
