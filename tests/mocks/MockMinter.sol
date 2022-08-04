// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "../../contracts/modules/Minters/MintControllerBase.sol";
import "../../contracts/SoundEdition/ISoundEditionV1.sol";

contract MockMinter is MintControllerBase {
    // Minimal mint function for testing
    function adminMint(address edition) public {
        uint256 quantity = 1;

        ISoundEditionV1(edition).mint(msg.sender, quantity);
    }
}
