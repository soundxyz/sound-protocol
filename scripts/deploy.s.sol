// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "../contracts/core/SoundEditionV1.sol";
import "../contracts/core/SoundCreatorV1.sol";
import "../contracts/modules/GoldenEggMetadata.sol";
import "../contracts/modules/FixedPricePermissionedSaleMinter.sol";
import "../contracts/modules/MerkleDropMinter.sol";
import "../contracts/modules/RangeEditionMinter.sol";

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
