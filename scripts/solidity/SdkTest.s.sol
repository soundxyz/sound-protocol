// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";
import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import { SoundFeeRegistry } from "@core/SoundFeeRegistry.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { GoldenEggMetadata } from "@modules/GoldenEggMetadata.sol";
import { FixedPriceSignatureMinter } from "@modules/FixedPriceSignatureMinter.sol";
import { MerkleDropMinter } from "@modules/MerkleDropMinter.sol";
import { RangeEditionMinter } from "@modules/RangeEditionMinter.sol";

import { ParseJson } from "./ParseJson.sol";

contract SdkTest is Script {
    address private constant VM_ADDRESS = address(bytes20(uint160(uint256(keccak256("hevm cheat code")))));
    ParseJson public constant pj = ParseJson(VM_ADDRESS);

    uint32 constant ONE_HOUR = 3600;
    uint32 constant RANGE_MINT_ID1 = 0;
    uint32 constant RANGE_MINT_ID2 = 1;

    uint32 immutable USER1_INITIAL_BALANCE;
    uint96 immutable PRICE;
    uint32 immutable MAX_MINTABLE_LOWER;
    uint32 immutable MAX_MINTABLE_UPPER;
    uint32 immutable MAX_PER_ACCOUNT;
    uint32 immutable MINT1_START_TIME;
    uint32 immutable MINT1_CLOSING_TIME;
    uint32 immutable MINT1_END_TIME;
    uint32 immutable MINT2_START_TIME;
    uint32 immutable MINT2_CLOSING_TIME;
    uint32 immutable MINT2_END_TIME;

    string configJson;

    constructor() {
        /******************************* 
                    LOAD CONFIG
        *******************************/

        string memory path = "scripts/solidity/testConfig.json";
        configJson = vm.readFile(path);

        bytes memory data = pj.parseJson(configJson, ".PRICE");
        PRICE = uint96(abi.decode(data, (uint256)));
        data = pj.parseJson(configJson, ".MAX_MINTABLE_LOWER");
        MAX_MINTABLE_LOWER = uint32(abi.decode(data, (uint256)));
        data = pj.parseJson(configJson, ".MAX_MINTABLE_UPPER");
        MAX_MINTABLE_UPPER = uint32(abi.decode(data, (uint256)));
        data = pj.parseJson(configJson, ".MAX_PER_ACCOUNT");
        MAX_PER_ACCOUNT = uint32(abi.decode(data, (uint256)));
        data = pj.parseJson(configJson, ".USER1_INITIAL_BALANCE");
        USER1_INITIAL_BALANCE = uint32(abi.decode(data, (uint256)));
        MINT1_START_TIME = uint32(block.timestamp);
        MINT1_CLOSING_TIME = MINT1_START_TIME + ONE_HOUR;
        MINT1_END_TIME = MINT1_CLOSING_TIME + ONE_HOUR;

        // 2nd mint starts halfway through 1st mint
        MINT2_START_TIME = MINT1_CLOSING_TIME;
        // ...but its closing time is 10 seconds after the end time of the 1st mint
        MINT2_CLOSING_TIME = MINT1_END_TIME + ONE_HOUR;
        MINT2_END_TIME = MINT2_CLOSING_TIME + ONE_HOUR;
    }

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

        // Set user1 initial balance by minting
        rangeMinter.mint{ value: PRICE }(editionAddress, RANGE_MINT_ID1, USER1_INITIAL_BALANCE, address(0));

        vm.stopBroadcast();
    }

    function _createRangeMint(address editionAddress, RangeEditionMinter rangeMinter) internal {
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
