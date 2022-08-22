// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import { Script } from "forge-std/Script.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { GoldenEggMetadata } from "@modules/GoldenEggMetadata.sol";
import { FixedPricePermissionedSaleMinter } from "@modules/minter/FixedPricePermissionedSaleMinter.sol";
import { MerkleDropMinter } from "@modules/minter/MerkleDropMinter.sol";
import { RangeEditionMinter } from "@modules/minter/RangeEditionMinter.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        new GoldenEggMetadataModule();
        new FixedPricePermissionedSaleMinter();
        new MerkleDropMinter();
        new RangeEditionMinter();

        SoundEditionV1 soundEdition = new SoundEditionV1();
        new SoundCreatorV1(address(soundEdition), address(0));

        vm.stopBroadcast();
    }
}
