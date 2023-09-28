// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import { Script } from "forge-std/Script.sol";
import "forge-std/console.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { ISoundEditionV1_2 } from "@core/interfaces/ISoundEditionV1_2.sol";
import { ISoundEditionV2 } from "@core/interfaces/ISoundEditionV2.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { IFixedPriceSignatureMinter } from "@modules/interfaces/IFixedPriceSignatureMinter.sol";
import { IMerkleDropMinter } from "@modules/interfaces/IMerkleDropMinter.sol";
import { IEditionMaxMinter } from "@modules/interfaces/IEditionMaxMinter.sol";
import { IRangeEditionMinter } from "@modules/interfaces/IRangeEditionMinter.sol";

import { IMinterModuleV2 } from "@core/interfaces/IMinterModuleV2.sol";
import { IFixedPriceSignatureMinterV2 } from "@modules/interfaces/IFixedPriceSignatureMinterV2.sol";
import { IMerkleDropMinterV2 } from "@modules/interfaces/IMerkleDropMinterV2.sol";
import { IEditionMaxMinterV2 } from "@modules/interfaces/IEditionMaxMinterV2.sol";
import { IRangeEditionMinterV2 } from "@modules/interfaces/IRangeEditionMinterV2.sol";

import { ISuperMinter } from "@modules/interfaces/ISuperMinter.sol";

contract GetInterfaceId is Script {
    function run() external view {
        console.log("{");

        /* solhint-disable quotes */
        console.log('"ISoundEditionV1": "');
        console.logBytes4(type(ISoundEditionV1).interfaceId);

        console.log('", "ISoundEditionV1_2": "');
        console.logBytes4(type(ISoundEditionV1_2).interfaceId);

        console.log('", "IMinterModule": "');
        console.logBytes4(type(IMinterModule).interfaceId);

        console.log('", "IFixedPriceSignatureMinter": "');
        console.logBytes4(type(IFixedPriceSignatureMinter).interfaceId);

        console.log('", "IMerkleDropMinter": "');
        console.logBytes4(type(IMerkleDropMinter).interfaceId);

        console.log('", "IEditionMaxMinter": "');
        console.logBytes4(type(IEditionMaxMinter).interfaceId);

        console.log('", "IRangeEditionMinter": "');
        console.logBytes4(type(IRangeEditionMinter).interfaceId);

        // v2
        console.log('", "IMinterModuleV2": "');
        console.logBytes4(type(IMinterModuleV2).interfaceId);

        console.log('", "IFixedPriceSignatureMinterV2": "');
        console.logBytes4(type(IFixedPriceSignatureMinterV2).interfaceId);

        console.log('", "IMerkleDropMinterV2": "');
        console.logBytes4(type(IMerkleDropMinterV2).interfaceId);

        console.log('", "IEditionMaxMinterV2": "');
        console.logBytes4(type(IEditionMaxMinterV2).interfaceId);

        console.log('", "IRangeEditionMinterV2": "');
        console.logBytes4(type(IRangeEditionMinterV2).interfaceId);

        // tiers

        console.log('", "ISoundEditionV2": "');
        console.logBytes4(type(ISoundEditionV2).interfaceId);

        console.log('", "ISuperMinter": "');
        console.logBytes4(type(ISuperMinter).interfaceId);

        console.log('"}');
    }
}
