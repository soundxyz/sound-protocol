// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "forge-std/console.sol";

import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { Clones } from "openzeppelin/proxy/Clones.sol";

import { ISoundCreatorV1 } from "@core/interfaces/ISoundCreatorV1.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { FixedPriceSignatureMinter } from "@modules/FixedPriceSignatureMinter.sol";
import { MerkleDropMinter } from "@modules/MerkleDropMinter.sol";
import { RangeEditionMinter } from "@modules/RangeEditionMinter.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { TestConfig } from "../TestConfig.sol";
import { MockSoundCreatorV2 } from "../mocks/MockSoundCreatorV2.sol";

contract SoundCreatorTests is TestConfig {
    event SoundEditionCreated(address indexed soundEdition, address indexed deployer);
    event SoundEditionImplementationSet(address newImplementation);
    event Upgraded(address indexed implementation);

    uint96 constant PRICE = 1 ether;
    uint32 constant START_TIME = 0;
    uint32 constant END_TIME = 10000;
    address constant SIGNER = address(111111);

    uint16 constant AFFILIATE_FEE_BPS = 0;

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

    function test_createSoundAndMints() public {
        address[] memory contracts = new address[](6);
        bytes[] memory data = new bytes[](6);

        ISoundFeeRegistry feeRegistry = ISoundFeeRegistry(address(1));
        FixedPriceSignatureMinter signatureMinter = new FixedPriceSignatureMinter(feeRegistry);
        MerkleDropMinter merkleMinter = new MerkleDropMinter(feeRegistry);
        RangeEditionMinter rangeMinter = new RangeEditionMinter(feeRegistry);

        SoundEditionV1 editionImplementation = new SoundEditionV1();

        address placeholderAddress = soundCreator.PLACEHOLDER_ADDRESS();

        // If the contract is the `PLACEHOLDER_ADDRESS`, the create method will
        // replace it with the address of the `soundEdition`.
        contracts[0] = placeholderAddress;
        contracts[1] = placeholderAddress;
        contracts[2] = placeholderAddress;

        contracts[3] = address(signatureMinter);
        contracts[4] = address(merkleMinter);
        contracts[5] = address(rangeMinter);

        data[0] = abi.encodeWithSelector(
            editionImplementation.grantRoles.selector,
            address(signatureMinter),
            editionImplementation.MINTER_ROLE()
        );
        data[1] = abi.encodeWithSelector(
            editionImplementation.grantRoles.selector,
            address(merkleMinter),
            editionImplementation.MINTER_ROLE()
        );
        data[2] = abi.encodeWithSelector(
            editionImplementation.grantRoles.selector,
            address(rangeMinter),
            editionImplementation.MINTER_ROLE()
        );

        // USe a unusual looking price.
        uint256 price = 308712640125698797;

        data[3] = abi.encodeWithSelector(
            signatureMinter.createEditionMint.selector,
            placeholderAddress, // Will be replaced by the address of the `soundEdition`.
            price + 3,
            SIGNER,
            EDITION_MAX_MINTABLE,
            START_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS
        );

        data[4] = abi.encodeWithSelector(
            merkleMinter.createEditionMint.selector,
            placeholderAddress, // Will be replaced by the address of the `soundEdition`.
            bytes32(uint256(123456)), // Merkle root hash.
            price + 4,
            START_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS,
            EDITION_MAX_MINTABLE,
            5 // Max mintable per account.
        );

        data[5] = abi.encodeWithSelector(
            rangeMinter.createEditionMint.selector,
            placeholderAddress, // Will be replaced by the address of the `soundEdition`.
            price + 5,
            START_TIME,
            START_TIME + 1, // Closing time
            END_TIME,
            AFFILIATE_FEE_BPS,
            10, // Max mintable lower.
            20, // Max mintable upper.
            5 // Max mintable per account.
        );

        SoundEditionV1 soundEdition = _createSoundEditionWithCalls(placeholderAddress, contracts, data);

        assertTrue(soundEdition.hasAnyRole(address(signatureMinter), editionImplementation.MINTER_ROLE()));
        assertTrue(soundEdition.hasAnyRole(address(merkleMinter), editionImplementation.MINTER_ROLE()));
        assertTrue(soundEdition.hasAnyRole(address(rangeMinter), editionImplementation.MINTER_ROLE()));

        // It is not convenient to return are parse the created mint IDs --
        // We have to depend on events to fetch them.

        // Simply check that the data has been initialized.
        assertEq(signatureMinter.mintInfo(address(soundEdition), signatureMinter.nextMintId() - 1).price, price + 3);
        assertEq(merkleMinter.mintInfo(address(soundEdition), merkleMinter.nextMintId() - 1).price, price + 4);
        assertEq(rangeMinter.mintInfo(address(soundEdition), rangeMinter.nextMintId() - 1).price, price + 5);

        // Check that it will revert if the lengths of the arrays are not the same.
        data = new bytes[](1);
        vm.expectRevert(ISoundCreatorV1.ArrayLengthsMismatch.selector);
        _createSoundEditionWithCalls(placeholderAddress, contracts, data);
    }

    // For avoiding the stack too deep error.
    function _createSoundEditionWithCalls(
        address placeholderAddress,
        address[] memory contracts,
        bytes[] memory data
    ) internal returns (SoundEditionV1) {
        return
            SoundEditionV1(
                soundCreator.createSoundAndMints(
                    abi.encodeWithSelector(
                        SoundEditionV1.initialize.selector,
                        placeholderAddress, // Will be replaced by the address of the caller.
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
                    ),
                    contracts,
                    data
                )
            );
    }
}
