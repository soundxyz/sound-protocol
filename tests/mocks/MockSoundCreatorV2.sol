// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MockSoundCreatorV2 is UUPSUpgradeable {
    function success() external pure returns (string memory) {
        return "upgrade to v2 success!";
    }

    function _authorizeUpgrade(address) internal override {}
}
