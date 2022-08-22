// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { TestConfig } from "../TestConfig.sol";
import { MockSoundCreatorV2 } from "../mocks/MockSoundCreatorV2.sol";

contract SoundCreatorTests is TestConfig {
    event SoundEditionCreated(address indexed soundEdition, address indexed creator);
    event SoundEditionImplementationSet(address newImplementation);
    event Upgraded(address indexed implementation);

    function deployCreator() public returns (SoundCreatorV1 creator) {
        // Deploy logic contracts
        SoundEditionV1 editionImplementation = new SoundEditionV1();
        SoundCreatorV1 soundCreatorImp = new SoundCreatorV1();

        // Deploy & initialize creator proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(soundCreatorImp), bytes(""));
        creator = SoundCreatorV1(address(proxy));
        creator.initialize(address(editionImplementation));
    }

    // Tests that the factory deploys
    function test_deploysSoundCreator() public {
        // Deploy logic contracts
        SoundEditionV1 editionImplementation = new SoundEditionV1();
        SoundCreatorV1 soundCreatorImp = new SoundCreatorV1();

        // Deploy & initialize creator proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(soundCreatorImp), bytes(""));
        SoundCreatorV1 creatorProxy = SoundCreatorV1(address(proxy));
        creatorProxy.initialize(address(editionImplementation));

        assert(address(creatorProxy) != address(0));

        assertEq(address(creatorProxy.soundEditionImplementation()), address(editionImplementation));
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

        SoundCreatorV1 creatorProxy = deployCreator();

        assertEq(address(creatorProxy.owner()), address(this));

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(attacker);
        creatorProxy.transferOwnership(attacker);
    }

    function test_ownerCanSetNewImplementation(address newImplementation) public {
        vm.assume(newImplementation != address(0));

        SoundCreatorV1 creatorProxy = deployCreator();

        vm.expectEmit(false, false, false, true);
        emit SoundEditionImplementationSet(newImplementation);

        creatorProxy.setEditionImplementation(newImplementation);
        assertEq(address(creatorProxy.soundEditionImplementation()), newImplementation);
    }

    function test_attackerCantSetNewImplementation(address attacker) public {
        vm.assume(attacker != address(this));

        SoundCreatorV1 creatorProxy = deployCreator();

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(attacker);
        creatorProxy.setEditionImplementation(address(0));
    }

    function test_implementationAddressOfZeroReverts() public {
        SoundCreatorV1 creatorProxy = new SoundCreatorV1();

        vm.expectRevert(SoundCreatorV1.ImplementationAddressCantBeZero.selector);
        creatorProxy.initialize(address(0));

        SoundEditionV1 soundEdition = createGenericEdition();
        creatorProxy = new SoundCreatorV1();
        creatorProxy.initialize(address(soundEdition));

        vm.expectRevert(SoundCreatorV1.ImplementationAddressCantBeZero.selector);
        creatorProxy.setEditionImplementation(address(0));
    }

    function test_ownerCanSuccessfullyUpgrade() public {
        SoundCreatorV1 creatorProxy = deployCreator();

        MockSoundCreatorV2 creatorV2Implementation = new MockSoundCreatorV2();

        vm.expectEmit(true, false, false, true);
        emit Upgraded(address(creatorV2Implementation));
        creatorProxy.upgradeTo(address(creatorV2Implementation));

        assertEq(MockSoundCreatorV2(address(creatorProxy)).success(), "upgrade to v2 success!");
    }

    function test_attackerCantUpgrade(address attacker) public {
        vm.assume(attacker != address(this));
        vm.assume(attacker != address(0));

        SoundCreatorV1 creatorProxy = deployCreator();

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(attacker);
        creatorProxy.upgradeTo(address(666));
    }
}
