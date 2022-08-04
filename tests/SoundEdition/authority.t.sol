// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "../TestConfig.sol";
import "../../contracts/SoundEdition/SoundEditionV1.sol";

contract SoundEdition_authority is TestConfig {
    event GuardianSet(address indexed guardian);

    function test_setsGuardianOnInitialization() external {
        address guardian = address(123);

        vm.expectEmit(false, false, false, true);
        emit GuardianSet(guardian);

        SoundEditionV1 soundEdition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI, guardian)
        );

        assertEq(soundEdition.guardian(), guardian);
    }

    // Owner can set guardian.
    function test_ownerCanSetGuardian() external {
        address guardian = address(123);

        SoundEditionV1 soundEdition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI, address(0))
        );

        vm.expectEmit(false, false, false, true);
        emit GuardianSet(guardian);

        soundEdition.setGuardian(guardian);

        assertEq(soundEdition.guardian(), guardian);
    }

    // Non-owners can't set guardian.
    function test_nonOwnerCantSetGuardian(address nonOwner) external {
        SoundEditionV1 soundEdition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI, address(0))
        );

        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(nonOwner);
        soundEdition.setGuardian(nonOwner);
    }

    // Guardian can relinquish guardianship.
    function test_guardianCanRelinquishRole() external {
        address guardian = address(12345);

        SoundEditionV1 soundEdition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI, guardian)
        );

        vm.expectEmit(false, false, false, true);
        emit GuardianSet(address(0));

        vm.prank(soundEdition.guardian());
        soundEdition.relinquishGuardianship();

        assertEq(soundEdition.guardian(), address(0));
    }

    // Non-guardians can't relinquish role.
    function test_nonGuardiansCantRelinquishRole(address nonGuardian) external {
        vm.assume(nonGuardian != GUARDIAN);

        SoundEditionV1 soundEdition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI, GUARDIAN)
        );

        vm.expectRevert(SoundEditionV1.Unauthorized.selector);

        vm.prank(nonGuardian);
        soundEdition.relinquishGuardianship();
    }

    // Guardian can set a new owner.
    function test_guardianCanSetNewOwner() external {
        address guardian = address(12345);
        address newOwner = address(6789);

        SoundEditionV1 soundEdition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI, guardian)
        );

        vm.prank(soundEdition.guardian());
        soundEdition.setNewOwner(newOwner);

        assertEq(soundEdition.owner(), newOwner);
    }

    // Non-guardians can't set a new owner.
    function test_nonGuardiansCantSetNewOwner(address nonGuardian) external {
        address guardian = address(12345);

        SoundEditionV1 soundEdition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI, guardian)
        );

        vm.expectRevert(SoundEditionV1.Unauthorized.selector);

        vm.prank(nonGuardian);
        soundEdition.setNewOwner(nonGuardian);
    }
}
