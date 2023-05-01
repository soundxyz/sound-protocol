// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import { Script } from "forge-std/Script.sol";

import { OpenGoldenEggMetadata } from "@modules/OpenGoldenEggMetadata.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        new OpenGoldenEggMetadata();

        vm.stopBroadcast();
    }
}
