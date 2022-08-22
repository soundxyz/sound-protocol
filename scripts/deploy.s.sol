// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "@core/SoundEditionV1.sol";
import "@core/SoundCreatorV1.sol";
import "@modules/GoldenEggMetadata.sol";
import "@modules/minter/FixedPricePermissionedSaleMinter.sol";
import "@modules/minter/MerkleDropMinter.sol";
import "@modules/minter/RangeEditionMinter.sol";

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
