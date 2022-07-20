// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "../../contracts/SoundNft/SoundNftV1.sol";

contract MockSoundNftV1 is SoundNftV1 {
    function mint(uint256 quantity) external {
        _mint(msg.sender, quantity);
    }
}
