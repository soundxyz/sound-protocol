// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

import "openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MockSoundFeeRegistryV2 is UUPSUpgradeable {
    function success() external pure returns (string memory) {
        return "Upgrade to MockSoundFeeRegistryV2 success!";
    }

    function _authorizeUpgrade(address) internal override {}
}
