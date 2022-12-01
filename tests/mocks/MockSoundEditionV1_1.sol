// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { SoundEditionV1_1 } from "@core/SoundEditionV1_1.sol";

contract MockSoundEditionV1_1 is SoundEditionV1_1 {
    function mint(uint256 quantity) external payable {
        _mint(msg.sender, quantity);
    }
}
