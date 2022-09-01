// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import { Script } from "forge-std/Script.sol";
import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import { SoundFeeRegistry } from "@core/SoundFeeRegistry.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";
import { GoldenEggMetadata } from "@modules/GoldenEggMetadata.sol";
import { FixedPriceSignatureMinter } from "@modules/FixedPriceSignatureMinter.sol";
import { MerkleDropMinter } from "@modules/MerkleDropMinter.sol";
import { RangeEditionMinter } from "@modules/RangeEditionMinter.sol";

contract Deploy is Script {
    uint16 private constant PLATFORM_FEE_BPS = 500;
    address SOUND_GNOSIS_SAFE_MAINNET = 0x858a92511485715Cfb754f397a7894b7724c7Abd;

    FixedPriceSignatureMinter public fixedPriceSignatureMinter;
    MerkleDropMinter public merkleDropMinter;
    RangeEditionMinter public rangeEditionMinter;

    function run() external {
        vm.startBroadcast();

        // Deploy the SoundFeeRegistry
        SoundFeeRegistry soundFeeRegistry = new SoundFeeRegistry(SOUND_GNOSIS_SAFE_MAINNET, PLATFORM_FEE_BPS);

        // Make the gnosis safe the owner of SoundFeeRegistry
        soundFeeRegistry.transferOwnership(SOUND_GNOSIS_SAFE_MAINNET);

        // Deploy modules
        new GoldenEggMetadata();
        fixedPriceSignatureMinter = new FixedPriceSignatureMinter(soundFeeRegistry);
        merkleDropMinter = new MerkleDropMinter(soundFeeRegistry);
        rangeEditionMinter = new RangeEditionMinter(soundFeeRegistry);

        // Deploy edition implementation (& initialize it for security)
        SoundEditionV1 editionImplementation = new SoundEditionV1();
        editionImplementation.initialize(
            address(0), // owner
            "SoundEditionV1", // name
            "SOUND", // symbol
            IMetadataModule(address(0)),
            "baseURI",
            "contractURI",
            address(1), // fundingRecipient
            0, // royaltyBPS
            0, // editionMaxMintable
            0, // mintRandomnessTokenThreshold
            0 // mintRandomnessTimeThreshold
        );

        // Deploy creator implementation (& initialize it for security)
        SoundCreatorV1 creatorImplementation = new SoundCreatorV1();
        creatorImplementation.initialize(address(editionImplementation));

        // Deploy creator proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(creatorImplementation), bytes(""));
        SoundCreatorV1 soundCreator = SoundCreatorV1(address(proxy));

        // Initialize creator proxy
        soundCreator.initialize(address(editionImplementation));

        // Set creator ownership to gnosis safe
        soundCreator.transferOwnership(SOUND_GNOSIS_SAFE_MAINNET);

        vm.stopBroadcast();
    }

    function _deployDummyEdition(SoundCreatorV1 soundCreator) internal {
        SoundEditionV1 soundEdition = SoundEditionV1(
            soundCreator.createSound(
                "SoundEditionV1", // name
                "SOUND", // symbol
                IMetadataModule(address(0)),
                "baseURI",
                "contractURI",
                address(1), // fundingRecipient
                0, // royaltyBPS
                0, // editionMaxMintable
                0, // mintRandomnessTokenThreshold
                0 // mintRandomnessTimeThreshold
            )
        );

        rangeEditionMinter.createEditionMint(
            address(soundEdition),
            10000000000000000, // 0.01 eth
            0, // startTime
            1662184609, // closingTime 9/2/22
            1664863009, // endTime 10/3/22
            0, // affiliateFeeBPS,
            10, // maxMintableLower,
            15, // maxMintableUpper,
            3 // maxMintablePerAccount
        );

        soundEdition.grantRoles(address(rangeEditionMinter), soundEdition.MINTER_ROLE());
    }
}
