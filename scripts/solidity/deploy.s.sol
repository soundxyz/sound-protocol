// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import { Script } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { ISoundFeeRegistry } from "contracts/core/interfaces/ISoundFeeRegistry.sol";
import { SoundEditionV1 } from "contracts/core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "contracts/core/SoundCreatorV1.sol";
import { GoldenEggMetadata } from "contracts/modules/GoldenEggMetadata.sol";
import { FixedPriceSignatureMinter } from "contracts/modules/FixedPriceSignatureMinter.sol";
import { MerkleDropMinter } from "contracts/modules/MerkleDropMinter.sol";
import { RangeEditionMinter } from "contracts/modules/RangeEditionMinter.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        // TODO - deploy this for real
        ISoundFeeRegistry soundFeeRegistry = ISoundFeeRegistry(address(0));

        new GoldenEggMetadata();
        new FixedPriceSignatureMinter(soundFeeRegistry);
        new MerkleDropMinter(soundFeeRegistry);
        new RangeEditionMinter(soundFeeRegistry);

        // Deploy implementations
        SoundEditionV1 editionImplementation = new SoundEditionV1();
        SoundCreatorV1 creatorImplementation = new SoundCreatorV1();

        // Deploy creator proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(creatorImplementation), bytes(""));
        SoundCreatorV1 soundCreator = SoundCreatorV1(address(proxy));

        // Initialize creator
        soundCreator.initialize(address(editionImplementation));

        vm.stopBroadcast();
    }
}
