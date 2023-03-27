// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { SoundEditionV1_2 } from "@core/SoundEditionV1_2.sol";

contract MockSoundEditionV1_2 is SoundEditionV1_2 {
    function mint(uint256 quantity) external payable {
        _mint(msg.sender, quantity);
    }
}
