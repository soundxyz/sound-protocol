// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";
import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import { SoundFeeRegistry } from "@core/SoundFeeRegistry.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";
import { GoldenEggMetadata } from "@modules/GoldenEggMetadata.sol";
import { FixedPriceSignatureMinter } from "@modules/FixedPriceSignatureMinter.sol";
import { MerkleDropMinter } from "@modules/MerkleDropMinter.sol";
import { RangeEditionMinter } from "@modules/RangeEditionMinter.sol";

/**
 * Seed script for deploying editions & mint instances on goerli or anvil
 */
contract Seed is Script {
    uint16 private constant PLATFORM_FEE_BPS = 500;
    address SOUND_GNOSIS_SAFE_MAINNET = 0x858a92511485715Cfb754f397a7894b7724c7Abd;
    uint96 constant PRICE = 1 ether;
    address constant SIGNER = address(111111);
    bytes32 constant SALT = bytes32(uint256(2932323523848306));
    uint32 constant MAX_MINTABLE = 50;
    uint16 constant ROYALTY_BPS = 1000;
    uint16 constant AFFILIATE_FEE_BPS = 0;
    uint32 immutable START_TIME;
    uint32 immutable END_TIME;
    uint32 immutable RANDOMNESS_LOCKED_TIMESTAMP;

    SoundCreatorV1 public soundCreator;

    GoldenEggMetadata public goldenEggModule;
    FixedPriceSignatureMinter public signatureMinter;
    MerkleDropMinter public merkleMinter;
    RangeEditionMinter public rangeMinter;

    constructor() {
        START_TIME = uint32(block.timestamp);
        END_TIME = START_TIME + 1 days;
        RANDOMNESS_LOCKED_TIMESTAMP = START_TIME + 1 hours;
    }

    function run() external {
        vm.startBroadcast();

        console.log("msg.sender:", msg.sender);

        // Deploy the SoundFeeRegistry
        SoundFeeRegistry soundFeeRegistry = new SoundFeeRegistry(SOUND_GNOSIS_SAFE_MAINNET, PLATFORM_FEE_BPS);

        // Make the gnosis safe the owner of SoundFeeRegistry
        soundFeeRegistry.transferOwnership(SOUND_GNOSIS_SAFE_MAINNET);

        // Deploy modules
        goldenEggModule = new GoldenEggMetadata();
        signatureMinter = new FixedPriceSignatureMinter(soundFeeRegistry);
        merkleMinter = new MerkleDropMinter(soundFeeRegistry);
        rangeMinter = new RangeEditionMinter(soundFeeRegistry);

        // Deploy edition implementation (& initialize it for security)
        SoundEditionV1 editionImplementation = new SoundEditionV1();
        editionImplementation.initialize(
            "SoundEditionV1", // name
            "SOUND", // symbol
            IMetadataModule(address(0)),
            "baseURI",
            "contractURI",
            address(1), // fundingRecipient
            0, // royaltyBPS
            0, // editionMaxMintable
            0, // mintRandomnessTokenThreshold
            0 // mintRandomnessTimeThreshold
        );

        // Deploy creator implementation (& initialize it for security)
        soundCreator = new SoundCreatorV1(address(editionImplementation));

        // Set creator ownership to gnosis safe
        soundCreator.transferOwnership(SOUND_GNOSIS_SAFE_MAINNET);

        // These are the arrays we have to pass into the create function
        // to setup the minters.
        address[] memory contracts = new address[](6);
        bytes[] memory data = new bytes[](6);

        address soundEditionAddress = soundCreator.soundEditionAddress(msg.sender, SALT);

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
        // Then, we have to call the {createEditionMint} on the minters.
        data[3] = abi.encodeWithSelector(
            signatureMinter.createEditionMint.selector,
            soundEditionAddress,
            PRICE,
            SIGNER,
            MAX_MINTABLE,
            START_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS
        );
        data[4] = abi.encodeWithSelector(
            merkleMinter.createEditionMint.selector,
            soundEditionAddress,
            bytes32(uint256(123456)), // Merkle root hash.
            PRICE,
            START_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS,
            MAX_MINTABLE,
            5 // Max mintable per account.
        );
        data[5] = abi.encodeWithSelector(
            rangeMinter.createEditionMint.selector,
            soundEditionAddress,
            PRICE,
            START_TIME,
            START_TIME + 1 hours, // Closing time
            END_TIME,
            AFFILIATE_FEE_BPS,
            10, // Max mintable lower.
            20, // Max mintable upper.
            5 // Max mintable per account.
        );

        // Call the create function.
        _createSoundEditionWithCalls(SALT, contracts, data);

        vm.stopBroadcast();
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
                "SongName",
                "SONG",
                address(goldenEggModule),
                "baseURI",
                "contractURI",
                msg.sender, // fundingRecipient
                1000, // royaltyBPS
                100, // editionMaxMintable
                0, // mintRandomnessTokenThreshold
                0 // mintRandomnessTimeThreshold
            ),
            contracts,
            data
        );
    }
}
