// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

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
import { EditionMaxMinter } from "@modules/EditionMaxMinter.sol";

contract Deploy is Script {
    bool private ONLY_MINTERS = vm.envBool("ONLY_MINTERS");
    uint16 private PLATFORM_FEE_BPS = uint16(vm.envUint("PLATFORM_FEE_BPS"));
    address private OWNER = vm.envAddress("OWNER");

    function run() external {
        vm.startBroadcast();

        // Deploy registry and transfer ownership to given owner
        SoundFeeRegistry soundFeeRegistry = new SoundFeeRegistry(OWNER, PLATFORM_FEE_BPS);
        soundFeeRegistry.transferOwnership(OWNER);
    
        // Deploy minter modules
        new FixedPriceSignatureMinter(soundFeeRegistry);
        new MerkleDropMinter(soundFeeRegistry);
        new RangeEditionMinter(soundFeeRegistry);
        new EditionMaxMinter(soundFeeRegistry);

        // If only deploying minters, we're done.
        if (ONLY_MINTERS) return;

        // Deploy golden egg module
        new GoldenEggMetadata();

        // Deploy edition implementation (& initialize it for security)
        SoundEditionV1 editionImplementation = new SoundEditionV1();
        editionImplementation.initialize(
            "SoundEditionV1", // name
            "SOUND", // symbol
            address(0),
            "baseURI",
            "contractURI",
            address(1), // fundingRecipient
            0, // royaltyBPS
            0, // editionMaxMintableLower
            0, // editionMaxMintableUpper
            0, // editionCutoffTime
            editionImplementation.MINT_RANDOMNESS_ENABLED_FLAG() // flags
        );

        // Deploy the SoundCreator
        SoundCreatorV1 soundCreator = new SoundCreatorV1(address(editionImplementation));

        // Set creator ownership to gnosis safe
        soundCreator.transferOwnership(OWNER);

        vm.stopBroadcast();
    }
}
