// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "../contracts/SoundCreator/SoundCreatorV1.sol";
import "../contracts/SoundEdition/SoundEditionV1.sol";
import "../contracts/modules/Metadata/IMetadataModule.sol";
import "./mocks/MockSoundEditionV1.sol";

contract TestConfig is Test {
    // Artist contract creation vars
    string public constant SONG_NAME = "Never Gonna Give You Up";
    string public constant SONG_SYMBOL = "NEVER";
    IMetadataModule public constant METADATA_MODULE = IMetadataModule(address(0));
    string public constant BASE_URI = "https://example.com/metadata/";
    string public constant CONTRACT_URI = "https://example.com/storefront/";
    address public constant ARTIST_ADMIN = address(8888888888);

    SoundCreatorV1 public soundCreator;

    // Set up called before each test
    function setUp() public {
        // Deploy SoundEdition implementation
        MockSoundEditionV1 soundEditionImplementation = new MockSoundEditionV1();

        // todo: deploy registry here
        address soundRegistry = address(123);

        soundCreator = new SoundCreatorV1(address(soundEditionImplementation), soundRegistry);
    }

    // Returns a random address funded with ETH
    function getRandomAccount(uint256 num) public returns (address) {
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(num)))));
        // Fund with some ETH
        vm.deal(addr, 1e19);

        return addr;
    }
}
