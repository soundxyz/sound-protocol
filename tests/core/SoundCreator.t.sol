// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { ISoundCreatorV1 } from "contracts/core/interfaces/ISoundCreatorV1.sol";
import { SoundEditionV1 } from "contracts/core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "contracts/core/SoundCreatorV1.sol";
import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { TestConfig } from "../TestConfig.sol";
import { MockSoundCreatorV2 } from "../mocks/MockSoundCreatorV2.sol";

contract SoundCreatorTests is TestConfig {
    event SoundEditionCreated(address indexed soundEdition, address indexed deployer);
    event SoundEditionImplementationSet(address newImplementation);
    event Upgraded(address indexed implementation);

    // Tests that the factory deploys
    function test_deploysSoundCreator() public {
        // Deploy logic contracts
        SoundEditionV1 editionImplementation = new SoundEditionV1();
        SoundCreatorV1 soundCreatorImp = new SoundCreatorV1();

        // Deploy & initialize creator proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(soundCreatorImp), bytes(""));
        SoundCreatorV1 soundCreator = SoundCreatorV1(address(proxy));
        soundCreator.initialize(address(editionImplementation));

        assert(address(soundCreator) != address(0));

        assertEq(address(soundCreator.soundEditionImplementation()), address(editionImplementation));
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

    function test_createSoundSetsNameAndSymbolCorrectly(string memory name, string memory symbol) public {
        SoundEditionV1 soundEdition = SoundEditionV1(
            soundCreator.createSound(
                name,
                symbol,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                EDITION_MAX_MINTABLE,
                EDITION_MAX_MINTABLE,
                RANDOMNESS_LOCKED_TIMESTAMP
            )
        );

        assertEq(soundEdition.name(), name);
        assertEq(soundEdition.symbol(), symbol);
    }

    function test_createSoundRevertsOnDoubleInitialization() public {
        SoundEditionV1 soundEdition = createGenericEdition();
        vm.expectRevert(OwnableRoles.Unauthorized.selector);
        soundEdition.initialize(
            address(this),
            SONG_NAME,
            SONG_SYMBOL,
            METADATA_MODULE,
            BASE_URI,
            CONTRACT_URI,
            FUNDING_RECIPIENT,
            ROYALTY_BPS,
            EDITION_MAX_MINTABLE,
            EDITION_MAX_MINTABLE,
            RANDOMNESS_LOCKED_TIMESTAMP
        );
    }

    function test_ownership(address attacker) public {
        vm.assume(attacker != address(this));

        assertEq(address(soundCreator.owner()), address(this));

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(attacker);
        soundCreator.transferOwnership(attacker);
    }

    function test_ownerCanSetNewImplementation(address newImplementation) public {
        vm.assume(newImplementation != address(0));

        vm.expectEmit(false, false, false, true);
        emit SoundEditionImplementationSet(newImplementation);

        soundCreator.setEditionImplementation(newImplementation);
        assertEq(address(soundCreator.soundEditionImplementation()), newImplementation);
    }

    function test_attackerCantSetNewImplementation(address attacker) public {
        vm.assume(attacker != address(this));

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(attacker);
        soundCreator.setEditionImplementation(address(0));
    }

    function test_implementationAddressOfZeroReverts() public {
        SoundCreatorV1 soundCreator = new SoundCreatorV1();

        vm.expectRevert(ISoundCreatorV1.ImplementationAddressCantBeZero.selector);
        soundCreator.initialize(address(0));

        SoundEditionV1 soundEdition = createGenericEdition();
        soundCreator = new SoundCreatorV1();
        soundCreator.initialize(address(soundEdition));

        vm.expectRevert(ISoundCreatorV1.ImplementationAddressCantBeZero.selector);
        soundCreator.setEditionImplementation(address(0));
    }

    function test_ownerCanSuccessfullyUpgrade() public {
        MockSoundCreatorV2 creatorV2Implementation = new MockSoundCreatorV2();

        vm.expectEmit(true, false, false, true);
        emit Upgraded(address(creatorV2Implementation));
        soundCreator.upgradeTo(address(creatorV2Implementation));

        assertEq(MockSoundCreatorV2(address(soundCreator)).success(), "upgrade to v2 success!");
    }

    function test_attackerCantUpgrade(address attacker) public {
        vm.assume(attacker != address(this));
        vm.assume(attacker != address(0));

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(attacker);
        soundCreator.upgradeTo(address(666));
    }
}
