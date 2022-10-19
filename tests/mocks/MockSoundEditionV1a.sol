// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { SoundEditionV1a } from "@core/SoundEditionV1a.sol";

contract MockSoundEditionV1a is SoundEditionV1a {
    function mint(uint256 quantity) external payable {
        _mint(msg.sender, quantity);
    }
}
