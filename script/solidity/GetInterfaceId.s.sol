// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import { Script } from "forge-std/Script.sol";
import "forge-std/console.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { ISoundEditionV1_2 } from "@core/interfaces/ISoundEditionV1_2.sol";
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


import { IMinterModuleV2_1 } from "@core/interfaces/IMinterModuleV2_1.sol";
import { IFixedPriceSignatureMinterV2_1 } from "@modules/interfaces/IFixedPriceSignatureMinterV2_1.sol";
import { IMerkleDropMinterV2_1 } from "@modules/interfaces/IMerkleDropMinterV2_1.sol";
import { IEditionMaxMinterV2_1 } from "@modules/interfaces/IEditionMaxMinterV2_1.sol";
import { IRangeEditionMinterV2_1 } from "@modules/interfaces/IRangeEditionMinterV2_1.sol";

import { ISAM } from "@modules/interfaces/ISAM.sol";

contract GetInterfaceId is Script {
    function run() external view {
        console.log("{");

        // Core.

        /* solhint-disable quotes */
        console.log('"ISoundEditionV1": "');
        console.logBytes4(type(ISoundEditionV1).interfaceId);

        console.log('", "ISoundEditionV1_2": "');
        console.logBytes4(type(ISoundEditionV1_2).interfaceId);

        // Modules.

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

        // v2_1
        console.log('", "IMinterModuleV2_1": "');
        console.logBytes4(type(IMinterModuleV2_1).interfaceId);

        console.log('", "IFixedPriceSignatureMinterV2_1": "');
        console.logBytes4(type(IFixedPriceSignatureMinterV2_1).interfaceId);

        console.log('", "IMerkleDropMinterV2_1": "');
        console.logBytes4(type(IMerkleDropMinterV2_1).interfaceId);

        console.log('", "IEditionMaxMinterV2_1": "');
        console.logBytes4(type(IEditionMaxMinterV2_1).interfaceId);

        console.log('", "IRangeEditionMinterV2_1": "');
        console.logBytes4(type(IRangeEditionMinterV2_1).interfaceId);

        console.log('", "ISAM": "');
        console.logBytes4(type(ISAM).interfaceId);

        console.log('"}');
    }
}
