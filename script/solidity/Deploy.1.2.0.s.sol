// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import { Script } from "forge-std/Script.sol";
import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import { ISoundFeeRegistry, SoundFeeRegistry } from "@core/SoundFeeRegistry.sol";
import { SoundEditionV1_2 } from "@core/SoundEditionV1_2.sol";
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

        // https://etherscan.io/address/0x8f921211c9771baEb648Ac7bECB322a540298A4B#readContract
        ISoundFeeRegistry soundFeeRegistry = ISoundFeeRegistry(0x8f921211c9771baEb648Ac7bECB322a540298A4B);

        // Deploy minter modules
        new FixedPriceSignatureMinter(soundFeeRegistry);
        new MerkleDropMinter(soundFeeRegistry);
        new RangeEditionMinter(soundFeeRegistry);
        new EditionMaxMinter(soundFeeRegistry);

        // If only deploying minters, we're done.
        if (ONLY_MINTERS) return;

        // Deploy edition implementation (& initialize it for security)
        SoundEditionV1_2 editionImplementation = new SoundEditionV1_2();
        editionImplementation.initialize(
            "SoundEditionV1.2.0", // name
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

        vm.stopBroadcast();
    }
}
