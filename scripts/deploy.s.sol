// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "@core/SoundEditionV1.sol";
import "@core/SoundCreatorV1.sol";
import "@modules/GoldenEggMetadata.sol";
import "@modules/FixedPriceSignatureMinter.sol";
import "@modules/MerkleDropMinter.sol";
import "@modules/RangeEditionMinter.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        new GoldenEggMetadataModule();
        new FixedPriceSignatureMinter();
        new MerkleDropMinter();
        new RangeEditionMinter();

        SoundEditionV1 soundEdition = new SoundEditionV1();
        new SoundCreatorV1(address(soundEdition), address(0));

        vm.stopBroadcast();
    }
}
