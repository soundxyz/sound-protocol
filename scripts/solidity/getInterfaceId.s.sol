// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import { Script } from "forge-std/Script.sol";
import "forge-std/console.sol";
import { ISoundEditionV1 } from "contracts/core/interfaces/ISoundEditionV1.sol";
import { IMinterModule } from "contracts/core/interfaces/IMinterModule.sol";
import { IFixedPriceSignatureMinter } from "contracts/modules/interfaces/IFixedPriceSignatureMinter.sol";
import { IMerkleDropMinter } from "contracts/modules/interfaces/IMerkleDropMinter.sol";
import { IRangeEditionMinter } from "contracts/modules/interfaces/IRangeEditionMinter.sol";

contract GetInterfaceId is Script {
    function run() external {
        console.log("ISoundEditionV1");
        console.logBytes4(type(ISoundEditionV1).interfaceId);

        console.log("IMinterModule");
        console.logBytes4(type(IMinterModule).interfaceId);

        console.log("IFixedPriceSignatureMinter");
        console.logBytes4(type(IFixedPriceSignatureMinter).interfaceId);

        console.log("IMerkleDropMinter");
        console.logBytes4(type(IMerkleDropMinter).interfaceId);

        console.log("IRangeEditionMinter");
        console.logBytes4(type(IRangeEditionMinter).interfaceId);
    }
}
