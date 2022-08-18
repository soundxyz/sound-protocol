// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "./TestConfig.sol";
import "../contracts/SoundEdition/SoundEditionV1.sol";
import "../contracts/SoundCreator/SoundCreatorV1.sol";

contract SoundCreatorTests is TestConfig {
    event SoundEditionCreated(address indexed soundEdition, address indexed creator);
    event SoundEditionImplementationSet(address newImplementation);

    // Tests that the factory deploys
    function test_deploysSoundCreator() public {
        SoundEditionV1 editionImplementation = new SoundEditionV1();
        SoundCreatorV1 _soundCreator = new SoundCreatorV1();
        _soundCreator.initialize(address(editionImplementation));

        assert(address(_soundCreator) != address(0));

        assertEq(address(_soundCreator.soundEditionImplementation()), address(editionImplementation));
    }

    // Tests that the factory creates a new sound NFT
    function test_createSound() public {
        // Can't test edition address is emitted from event unless we precalculate it,
        // but cloneDeterminstic would require a salt (==more gas & complexity)
        vm.expectEmit(false, true, false, false);
        emit SoundEditionCreated(address(0), address(this));

        SoundEditionV1 soundEdition = createGenericEdition();

        assert(address(soundEdition) != address(0));
        assertEq(soundEdition.name(), SONG_NAME);
        assertEq(soundEdition.symbol(), SONG_SYMBOL);
    }

    function test_ownership(address attacker) public {
        vm.assume(attacker != address(this));

        SoundEditionV1 soundEdition = createGenericEdition();
        SoundCreatorV1 soundCreator = new SoundCreatorV1();
        soundCreator.initialize(address(soundEdition));

        assertEq(address(soundCreator.owner()), address(this));

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(attacker);
        soundCreator.transferOwnership(attacker);
    }

    function test_ownerCanSetNewImplementation(address newImplementation) public {
        vm.assume(newImplementation != address(0));

        SoundEditionV1 soundEdition = createGenericEdition();
        SoundCreatorV1 soundCreator = new SoundCreatorV1();
        soundCreator.initialize(address(soundEdition));

        vm.expectEmit(false, false, false, true);
        emit SoundEditionImplementationSet(newImplementation);

        soundCreator.setEditionImplementation(newImplementation);
        assertEq(address(soundCreator.soundEditionImplementation()), newImplementation);
    }

    function test_attackerCantSetNewImplementation(address attacker) public {
        vm.assume(attacker != address(this));

        SoundEditionV1 soundEdition = createGenericEdition();
        SoundCreatorV1 soundCreator = new SoundCreatorV1();
        soundCreator.initialize(address(soundEdition));

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(attacker);
        soundCreator.setEditionImplementation(address(0));
    }

    function test_implementationAddressOfZeroReverts() public {
        SoundCreatorV1 soundCreator = new SoundCreatorV1();

        vm.expectRevert(SoundCreatorV1.ImplementationAddressCantBeZero.selector);
        soundCreator.initialize(address(0));

        SoundEditionV1 soundEdition = createGenericEdition();
        soundCreator = new SoundCreatorV1();
        soundCreator.initialize(address(soundEdition));

        vm.expectRevert(SoundCreatorV1.ImplementationAddressCantBeZero.selector);
        soundCreator.setEditionImplementation(address(0));
    }
}
