// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IAccessControlEnumerableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/IAccessControlEnumerableUpgradeable.sol";

import { SoundEditionV1 } from "contracts/core/SoundEditionV1.sol";
import { ISoundEditionV1 } from "contracts/core/interfaces/ISoundEditionV1.sol";
import { TestConfig } from "../../TestConfig.sol";

/**
 * @dev Miscellaneous tests for SoundEdition
 */
contract SoundEdition_misc is TestConfig {
    function test_supportsInterface() public {
        SoundEditionV1 edition = createGenericEdition();
        bool supportsEditionIface = edition.supportsInterface(type(ISoundEditionV1).interfaceId);
        assertTrue(supportsEditionIface);
    }
}
