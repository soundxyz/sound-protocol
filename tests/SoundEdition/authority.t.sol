// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "../TestConfig.sol";

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

    // function test_setGuardian()
}
