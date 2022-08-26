// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import { Script } from "forge-std/Script.sol";
import "forge-std/console.sol";
import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import { SoundFeeRegistry } from "@core/SoundFeeRegistry.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { GoldenEggMetadata } from "@modules/GoldenEggMetadata.sol";
import { FixedPriceSignatureMinter } from "@modules/FixedPriceSignatureMinter.sol";
import { MerkleDropMinter } from "@modules/MerkleDropMinter.sol";
import { RangeEditionMinter } from "@modules/RangeEditionMinter.sol";

contract SdkTest is Script {
    uint96 constant PRICE = 100000000 gwei; // 0.1 ETH
    uint32 constant MAX_MINTABLE_LOWER = 3;
    uint32 constant MAX_MINTABLE_UPPER = 5;
    uint32 constant MAX_PER_ACCOUNT = 1;

    function run() external {
        vm.startBroadcast();

        SoundFeeRegistry soundFeeRegistry = new SoundFeeRegistry(address(1), 0);

        // Deploy modules
        GoldenEggMetadata goldenEggModule = new GoldenEggMetadata();
        FixedPriceSignatureMinter fixedPriceMinter = new FixedPriceSignatureMinter(soundFeeRegistry);
        MerkleDropMinter merkleMinter = new MerkleDropMinter(soundFeeRegistry);
        RangeEditionMinter rangeMinter = new RangeEditionMinter(soundFeeRegistry);

        // Deploy core implementations
        SoundEditionV1 editionImplementation = new SoundEditionV1();
        SoundCreatorV1 creatorImplementation = new SoundCreatorV1();

        // Deploy creator proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(creatorImplementation), bytes(""));
        SoundCreatorV1 soundCreator = SoundCreatorV1(address(proxy));

        // Initialize creator
        soundCreator.initialize(address(editionImplementation));

        // Deploy edition proxy
        address editionAddress = soundCreator.createSound(
            "SDK Test",
            "SDK",
            goldenEggModule,
            "baseURI",
            "contractURI",
            address(1), // fundingRecipient
            0, // royaltyBPS
            type(uint32).max, // editionMaxMintable
            100, // mintRandomnessTokenThreshold
            100 // mintRandomnessTimeThreshold
        );

        console.log("SoundEdition: ", editionAddress);
        console.log("GoldenEggMetadata: ", address(goldenEggModule));
        console.log("FixedPriceSignatureMinter: ", address(fixedPriceMinter));
        console.log("MerkleDropMinter: ", address(merkleMinter));
        console.log("RangeEditionMinter: ", address(rangeMinter));

        // Cast edition address to SoundEditionV1
        SoundEditionV1 edition = SoundEditionV1(payable(editionAddress));

        // grant minter roles
        uint256 minterRole = edition.MINTER_ROLE();
        edition.grantRoles(address(fixedPriceMinter), minterRole);
        edition.grantRoles(address(merkleMinter), minterRole);
        edition.grantRoles(address(rangeMinter), minterRole);

        _createRangeMint(editionAddress, rangeMinter);

        // TODO: create signature & merkle mints

        vm.stopBroadcast();
    }

    function _createRangeMint(address editionAddress, RangeEditionMinter rangeMinter) internal {
        // TODO: import these values from a shared file so the SDK tests are referencing the same source of truth.

        uint32 MINT1_START_TIME = 0;
        uint32 MINT1_CLOSING_TIME = MINT1_START_TIME + 10;
        uint32 MINT1_END_TIME = MINT1_CLOSING_TIME + 10;

        // 2nd mint starts halfway through 1st mint
        uint32 MINT2_START_TIME = MINT1_CLOSING_TIME;
        // ...but its closing time is 10 seconds after the end time of the 1st mint
        uint32 MINT2_CLOSING_TIME = MINT1_END_TIME + 10;
        uint32 MINT2_END_TIME = MINT2_CLOSING_TIME + 10;

        // Create mints
        rangeMinter.createEditionMint(
            editionAddress,
            PRICE,
            MINT1_START_TIME,
            MINT1_CLOSING_TIME,
            MINT1_END_TIME,
            MAX_MINTABLE_LOWER,
            MAX_MINTABLE_UPPER,
            MAX_PER_ACCOUNT
        );

        rangeMinter.createEditionMint(
            editionAddress,
            PRICE,
            MINT2_START_TIME,
            MINT2_CLOSING_TIME,
            MINT2_END_TIME,
            MAX_MINTABLE_LOWER,
            MAX_MINTABLE_UPPER,
            MAX_PER_ACCOUNT
        );
    }
}
