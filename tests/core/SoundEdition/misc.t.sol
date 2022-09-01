// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IAccessControlEnumerableUpgradeable } from "openzeppelin-upgradeable/access/IAccessControlEnumerableUpgradeable.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { TestConfig } from "../../TestConfig.sol";

/**
 * @dev Miscellaneous tests for SoundEdition
 */
contract SoundEdition_misc is TestConfig {
    function test_supportsInterface() public {
        SoundEditionV1 edition = createGenericEdition();
        bool supportsEditionIface = edition.supportsInterface(type(ISoundEditionV1).interfaceId);
        assertTrue(supportsEditionIface);
        bool supports165 = edition.supportsInterface(type(IERC165).interfaceId);
        assertTrue(supports165);
    }
}
