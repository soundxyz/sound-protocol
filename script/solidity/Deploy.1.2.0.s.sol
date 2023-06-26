// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import { Script } from "forge-std/Script.sol";
import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import { ISoundFeeRegistry, SoundFeeRegistry } from "@core/SoundFeeRegistry.sol";
import { SoundEditionV1_2 } from "@core/SoundEditionV1_2.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";
import { GoldenEggMetadata } from "@modules/GoldenEggMetadata.sol";
import { FixedPriceSignatureMinterV2_1 } from "@modules/FixedPriceSignatureMinterV2_1.sol";
import { MerkleDropMinterV2_1 } from "@modules/MerkleDropMinterV2_1.sol";
import { RangeEditionMinterV2_1 } from "@modules/RangeEditionMinterV2_1.sol";
import { EditionMaxMinterV2_1 } from "@modules/EditionMaxMinterV2_1.sol";

contract Deploy is Script {
    bool private ONLY_MINTERS = vm.envBool("ONLY_MINTERS");
    uint16 private PLATFORM_FEE_BPS = uint16(vm.envUint("PLATFORM_FEE_BPS"));
    address private OWNER = vm.envAddress("OWNER");

    function run() external {
        vm.startBroadcast();

        // Deploy minter modules
        new FixedPriceSignatureMinterV2_1();
        new MerkleDropMinterV2_1();
        new RangeEditionMinterV2_1();
        new EditionMaxMinterV2_1();

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
