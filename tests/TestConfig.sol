// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "../contracts/SoundCreator/SoundCreatorV1.sol";
import "../contracts/SoundEdition/SoundEditionV1.sol";
import "../contracts/modules/Metadata/IMetadataModule.sol";
import "./mocks/MockSoundEditionV1.sol";
import "../contracts/SoundFeeRegistry/SoundFeeRegistry.sol";

contract TestConfig is Test {
    // Artist contract creation vars
    string constant SONG_NAME = "Never Gonna Give You Up";
    string constant SONG_SYMBOL = "NEVER";
    IMetadataModule constant METADATA_MODULE = IMetadataModule(address(0));
    string constant BASE_URI = "https://example.com/metadata/";
    string constant CONTRACT_URI = "https://example.com/storefront/";
    uint32 constant PLATFORM_FEE = 200;
    address constant FUNDING_RECIPIENT = address(99);
    uint32 constant ROYALTY_BPS = 100;

    SoundCreatorV1 soundCreator;
    SoundFeeRegistry soundFeeRegistry;
    address soundFeeAddress;

    // Set up called before each test
    function setUp() public {
        // Deploy SoundEdition implementation
        MockSoundEditionV1 soundEditionImplementation = new MockSoundEditionV1();

        // todo: deploy registry here
        address soundRegistry = address(123);
        soundFeeAddress = getRandomAccount(100);

        soundFeeRegistry = new SoundFeeRegistry(soundFeeAddress, PLATFORM_FEE);

        soundCreator = new SoundCreatorV1(address(soundEditionImplementation), soundRegistry, soundFeeRegistry);
    }

    // Returns a random address funded with ETH
    function getRandomAccount(uint256 num) public returns (address) {
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(num)))));
        // Fund with some ETH
        vm.deal(addr, 1e19);

        return addr;
    }
}
