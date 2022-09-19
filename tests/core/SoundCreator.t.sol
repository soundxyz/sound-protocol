// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { ISoundCreatorV1 } from "@core/interfaces/ISoundCreatorV1.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { FixedPriceSignatureMinter } from "@modules/FixedPriceSignatureMinter.sol";
import { MerkleDropMinter } from "@modules/MerkleDropMinter.sol";
import { RangeEditionMinter } from "@modules/RangeEditionMinter.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { TestConfig } from "../TestConfig.sol";

contract SoundCreatorTests is TestConfig {
    event SoundEditionCreated(
        address indexed soundEdition,
        address indexed deployer,
        bytes initData,
        address[] contracts,
        bytes[] data,
        bytes[] results
    );

    event SoundEditionImplementationSet(address newImplementation);

    uint96 constant PRICE = 1 ether;
    uint32 constant START_TIME = 0;
    uint32 constant END_TIME = 10000;
    address constant SIGNER = address(111111);

    uint16 constant AFFILIATE_FEE_BPS = 0;

    // Tests that the factory deploys
    function test_deploysSoundCreator() public {
        // Deploy logic contracts
        SoundEditionV1 editionImplementation = new SoundEditionV1();
        SoundCreatorV1 soundCreator = new SoundCreatorV1(address(editionImplementation));

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
                EDITION_CUTOFF_TIME,
                FLAGS
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
            EDITION_CUTOFF_TIME,
            FLAGS
        );
    }

    function test_ownership(address attacker) public {
        vm.assume(attacker != address(this));

        assertEq(address(soundCreator.owner()), address(this));

        vm.expectRevert(OwnableRoles.Unauthorized.selector);
        vm.prank(attacker);
        soundCreator.transferOwnership(attacker);
    }

    function test_twoStepOwnershipHandover(address newOwner) public {
        vm.assume(newOwner != address(this));

        assertEq(address(soundCreator.owner()), address(this));

        vm.expectRevert(OwnableRoles.Unauthorized.selector);
        vm.prank(newOwner);
        soundCreator.completeOwnershipHandover(newOwner);

        vm.expectRevert(OwnableRoles.NoHandoverRequest.selector);
        soundCreator.completeOwnershipHandover(newOwner);

        vm.prank(newOwner);
        soundCreator.requestOwnershipHandover();

        soundCreator.completeOwnershipHandover(newOwner);

        assertEq(address(soundCreator.owner()), newOwner);
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

        vm.expectRevert(OwnableRoles.Unauthorized.selector);
        vm.prank(attacker);
        soundCreator.setEditionImplementation(address(0));
    }

    function test_implementationAddressOfZeroReverts() public {
        vm.expectRevert(ISoundCreatorV1.ImplementationAddressCantBeZero.selector);
        new SoundCreatorV1(address(0));

        SoundEditionV1 soundEdition = createGenericEdition();
        SoundCreatorV1 soundCreator = new SoundCreatorV1(address(soundEdition));

        vm.expectRevert(ISoundCreatorV1.ImplementationAddressCantBeZero.selector);
        soundCreator.setEditionImplementation(address(0));
    }

    function test_createSoundAndMints(
        uint96 price0,
        uint96 price1,
        uint96 price2,
        bytes32 salt
    ) public {
        // These are the arrays we have to pass into the create function
        // to setup the minters.
        address[] memory contracts = new address[](6);
        bytes[] memory data = new bytes[](6);

        FixedPriceSignatureMinter signatureMinter;
        MerkleDropMinter merkleMinter;
        RangeEditionMinter rangeMinter;

        // Deploy the registry and minters.
        {
            ISoundFeeRegistry feeRegistry = ISoundFeeRegistry(address(1));
            signatureMinter = new FixedPriceSignatureMinter(feeRegistry);
            merkleMinter = new MerkleDropMinter(feeRegistry);
            rangeMinter = new RangeEditionMinter(feeRegistry);
        }

        // Deploy the implementation of the edition.
        SoundEditionV1 editionImplementation = new SoundEditionV1();

        (address soundEditionAddress, ) = soundCreator.soundEditionAddress(address(this), salt);

        // Populate the contracts:
        // First, we have to call the {grantRoles} on the `soundEditionAddress`.
        contracts[0] = soundEditionAddress;
        contracts[1] = soundEditionAddress;
        contracts[2] = soundEditionAddress;
        // Then, we have to call the {createEditionMint} on the minters.
        contracts[3] = address(signatureMinter);
        contracts[4] = address(merkleMinter);
        contracts[5] = address(rangeMinter);

        // Populate the data:
        // First, we have to call the {grantRoles} on the `soundEditionAddress`.
        {
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
        }

        // Then, we have to call the {createEditionMint} on the minters.
        {
            data[3] = abi.encodeWithSelector(
                signatureMinter.createEditionMint.selector,
                soundEditionAddress,
                price0,
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
                price1,
                START_TIME,
                END_TIME,
                AFFILIATE_FEE_BPS,
                EDITION_MAX_MINTABLE,
                5 // Max mintable per account.
            );
            data[5] = abi.encodeWithSelector(
                rangeMinter.createEditionMint.selector,
                soundEditionAddress,
                price2,
                START_TIME,
                START_TIME + 1, // Closing time
                END_TIME,
                AFFILIATE_FEE_BPS,
                10, // Max mintable lower.
                20, // Max mintable upper.
                5 // Max mintable per account.
            );
        }

        {
            bytes[] memory expectedResults = new bytes[](6);
            expectedResults[3] = abi.encode(signatureMinter.nextMintId());
            expectedResults[4] = abi.encode(merkleMinter.nextMintId());
            expectedResults[5] = abi.encode(rangeMinter.nextMintId());

            // Check that the creation event is emitted.
            vm.expectEmit(true, true, true, true);
            emit SoundEditionCreated(
                soundEditionAddress,
                address(this),
                _makeInitData(),
                contracts,
                data,
                expectedResults
            );
        }

        // Call the create function.
        (, bytes[] memory results) = _createSoundEditionWithCalls(salt, contracts, data);

        // Cast it to `SoundEditionV1` for convenience.
        SoundEditionV1 soundEdition = SoundEditionV1(soundEditionAddress);

        // Check that the `MINTER_ROLE` has been assigned properly.
        assertTrue(soundEdition.hasAnyRole(address(signatureMinter), editionImplementation.MINTER_ROLE()));
        assertTrue(soundEdition.hasAnyRole(address(merkleMinter), editionImplementation.MINTER_ROLE()));
        assertTrue(soundEdition.hasAnyRole(address(rangeMinter), editionImplementation.MINTER_ROLE()));

        // Check that the mint IDs have been properly incremented, and encoded into the results.
        assertEq(abi.decode(results[3], (uint96)), signatureMinter.nextMintId() - 1);
        assertEq(abi.decode(results[4], (uint96)), merkleMinter.nextMintId() - 1);
        assertEq(abi.decode(results[5], (uint96)), rangeMinter.nextMintId() - 1);

        // Simply check that the data has been initialized.
        assertEq(signatureMinter.mintInfo(soundEditionAddress, signatureMinter.nextMintId() - 1).price, price0);
        assertEq(merkleMinter.mintInfo(soundEditionAddress, merkleMinter.nextMintId() - 1).price, price1);
        assertEq(rangeMinter.mintInfo(soundEditionAddress, rangeMinter.nextMintId() - 1).price, price2);

        // Check that the caller owns the `soundEdition`.
        assertEq(soundEdition.owner(), address(this));
    }

    function test_createSoundAndMints() public {
        uint96 price0 = 308712640125698797;
        uint96 price1 = 208712640125698797;
        uint96 price2 = 108712640125698797;
        bytes32 salt = keccak256(bytes("SomeRandomString"));
        test_createSoundAndMints(price0, price1, price2, salt);
    }

    function test_createSoundAndMintsRevertForArrayLengthsMismatch(
        uint8 contractsLength,
        uint8 dataLength,
        bytes32 salt
    ) public {
        vm.assume(contractsLength != dataLength);

        address[] memory contracts = new address[](contractsLength);
        bytes[] memory data = new bytes[](dataLength);

        vm.expectRevert(ISoundCreatorV1.ArrayLengthsMismatch.selector);
        _createSoundEditionWithCalls(salt, contracts, data);
    }

    function test_createSoundAndMintsRevertForArrayLengthsMismatch() public {
        bytes32 salt = keccak256(bytes("SomeRandomString"));
        test_createSoundAndMintsRevertForArrayLengthsMismatch(0, 1, salt);
    }

    function _makeInitData() internal pure returns (bytes memory) {
        return
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
                EDITION_CUTOFF_TIME,
                FLAGS
            );
    }

    function _createSoundEditionWithCalls(
        bytes32 salt,
        address[] memory contracts,
        bytes[] memory data
    ) internal returns (address soundEdition, bytes[] memory results) {
        (soundEdition, results) = soundCreator.createSoundAndMints(salt, _makeInitData(), contracts, data);
    }
}
