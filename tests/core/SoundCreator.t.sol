// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

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
        SoundEditionV1 soundEdition = createGenericEdition();

        assert(address(soundEdition) != address(0));
        assertEq(soundEdition.name(), SONG_NAME);
        assertEq(soundEdition.symbol(), SONG_SYMBOL);
    }

    function test_createSoundSetsNameAndSymbolCorrectly(string memory name, string memory symbol) public {
        SoundEditionV1 soundEdition = SoundEditionV1(
            createSound(
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

        bytes32 salt = keccak256(bytes("SomeRandomString"));
        address soundEditionAddress = soundCreator.soundEditionAddress(salt);

        contracts[0] = soundEditionAddress;
        contracts[1] = soundEditionAddress;
        contracts[2] = soundEditionAddress;

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

        // Use a unusual looking price.
        uint256 price = 308712640125698797;

        data[3] = abi.encodeWithSelector(
            signatureMinter.createEditionMint.selector,
            soundEditionAddress,
            price + 3,
            SIGNER,
            EDITION_MAX_MINTABLE,
            START_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS
        );

        data[4] = abi.encodeWithSelector(
            merkleMinter.createEditionMint.selector,
            soundEditionAddress,
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
            soundEditionAddress,
            price + 5,
            START_TIME,
            START_TIME + 1, // Closing time
            END_TIME,
            AFFILIATE_FEE_BPS,
            10, // Max mintable lower.
            20, // Max mintable upper.
            5 // Max mintable per account.
        );

        // Check that the creation event is emitted.
        vm.expectEmit(true, true, true, true);
        emit SoundEditionCreated(soundEditionAddress, address(this));

        bytes[] memory results = _createSoundEditionWithCalls(salt, contracts, data);

        SoundEditionV1 soundEdition = SoundEditionV1(soundEditionAddress);

        // Check that the `MINTER_ROLE` has been assigned properly.
        assertTrue(soundEdition.hasAnyRole(address(signatureMinter), editionImplementation.MINTER_ROLE()));
        assertTrue(soundEdition.hasAnyRole(address(merkleMinter), editionImplementation.MINTER_ROLE()));
        assertTrue(soundEdition.hasAnyRole(address(rangeMinter), editionImplementation.MINTER_ROLE()));

        // Check that the mint IDs have been properly incremented, and encoded into the results.
        assertEq(abi.decode(results[3], (uint128)), signatureMinter.nextMintId() - 1);
        assertEq(abi.decode(results[4], (uint128)), merkleMinter.nextMintId() - 1);
        assertEq(abi.decode(results[5], (uint128)), rangeMinter.nextMintId() - 1);

        // Simply check that the data has been initialized.
        assertEq(signatureMinter.mintInfo(soundEditionAddress, signatureMinter.nextMintId() - 1).price, price + 3);
        assertEq(merkleMinter.mintInfo(soundEditionAddress, merkleMinter.nextMintId() - 1).price, price + 4);
        assertEq(rangeMinter.mintInfo(soundEditionAddress, rangeMinter.nextMintId() - 1).price, price + 5);

        // Check that the caller owns the `soundEdition`.
        assertEq(soundEdition.owner(), address(this));

        // Check that it will revert if the lengths of the arrays are not the same.
        data = new bytes[](1);
        salt = keccak256(bytes("AnotherRandomString"));
        vm.expectRevert(ISoundCreatorV1.ArrayLengthsMismatch.selector);
        _createSoundEditionWithCalls(salt, contracts, data);
    }

    // For avoiding the stack too deep error.
    function _createSoundEditionWithCalls(
        bytes32 salt,
        address[] memory contracts,
        bytes[] memory data
    ) internal returns (bytes[] memory results) {
        results = soundCreator.createSoundAndMints(
            salt,
            abi.encodeWithSelector(
                SoundEditionV1.initialize.selector,
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
        );
    }
}
