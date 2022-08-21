// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "openzeppelin-upgradeable/access/IAccessControlEnumerableUpgradeable.sol";
import "@core/SoundEditionV1.sol";
import "../../TestConfig.sol";

/**
 * @dev Miscellaneous tests for SoundEdition
 */
contract SoundEdition_misc is TestConfig {
    function test_getMembersOfRole() public {
        ISoundEditionV1 edition = createGenericEdition();

        // Test with 4 minters

        address[] memory minters = new address[](4);
        minters[0] = address(111);
        minters[1] = address(222);
        minters[2] = address(333);
        minters[3] = address(444);

        for (uint256 i = 0; i < minters.length; i++) {
            IAccessControlEnumerableUpgradeable(address(edition)).grantRole(edition.MINTER_ROLE(), minters[i]);
        }

        address[] memory expectedMinters = edition.getMembersOfRole(edition.MINTER_ROLE());

        for (uint256 i = 0; i < minters.length; i++) {
            assertEq(expectedMinters[i], minters[i]);
        }

        // Test with 5 admins

        address[] memory admins = new address[](5);
        admins[0] = address(555);
        admins[1] = address(666);
        admins[2] = address(777);
        admins[3] = address(888);
        admins[4] = address(999);

        for (uint256 i = 0; i < admins.length; i++) {
            IAccessControlEnumerableUpgradeable(address(edition)).grantRole(edition.ADMIN_ROLE(), admins[i]);
        }

        address[] memory expectedAdmins = edition.getMembersOfRole(edition.ADMIN_ROLE());

        for (uint256 i = 0; i < admins.length; i++) {
            assertEq(expectedAdmins[i], admins[i]);
        }
    }
}
