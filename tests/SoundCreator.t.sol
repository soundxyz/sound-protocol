// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "./TestConfig.sol";
import "../contracts/SoundEdition/SoundEditionV1.sol";
import "../contracts/SoundCreator/SoundCreatorV1.sol";

contract SoundCreatorTests is TestConfig {
    event SoundCreated(address indexed soundEdition, address indexed creator);

    // Tests that the factory deploys
    function test_deploysSoundCreator() public {
        SoundEditionV1 soundEditionImplementation = new SoundEditionV1();
        SoundCreatorV1 _soundCreator = new SoundCreatorV1(address(soundEditionImplementation));

        assert(address(_soundCreator) != address(0));

        assertEq(address(_soundCreator.nftImplementation()), address(soundEditionImplementation));
    }

    // Tests that the factory creates a new sound NFT
    function test_createSound() public {
        // Can't test edition address is emitted from event unless we precalculate it,
        // but cloneDeterminstic would require a salt (==more gas & complexity)
        vm.expectEmit(false, true, false, false);
        emit SoundCreated(address(0), address(this));

        SoundEditionV1 soundEdition = createGenericEdition();

        assert(address(soundEdition) != address(0));
        assertEq(soundEdition.name(), SONG_NAME);
        assertEq(soundEdition.symbol(), SONG_SYMBOL);
    }
}
