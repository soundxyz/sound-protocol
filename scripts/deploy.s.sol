// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "../contracts/SoundEdition/SoundEditionV1.sol";
import "../contracts/SoundCreator/SoundCreatorV1.sol";
import "../contracts/modules/Metadata/GoldenEggMetadataModule.sol";
import "../contracts/modules/Minters/FixedPricePermissionedSaleMinter.sol";
import "../contracts/modules/Minters/FixedPricePublicSaleMinter.sol";
import "../contracts/modules/Minters/MerkleDropMinter.sol";
import "../contracts/modules/Minters/RangeEditionMinter.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        new GoldenEggMetadataModule();

        new FixedPricePermissionedSaleMinter();
        new FixedPricePublicSaleMinter();
        new MerkleDropMinter();
        new RangeEditionMinter();

        SoundEditionV1 soundEdition = new SoundEditionV1();
        new SoundCreatorV1(address(soundEdition), address(0));

        vm.stopBroadcast();
    }
}
