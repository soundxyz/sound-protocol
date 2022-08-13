// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "../contracts/SoundCreator/SoundCreatorV1.sol";
import "../contracts/SoundEdition/SoundEditionV1.sol";
import "../contracts/modules/Metadata/IMetadataModule.sol";
import "./mocks/MockSoundEditionV1.sol";

contract TestConfig is Test {
    // Artist contract creation vars
    string constant SONG_NAME = "Never Gonna Give You Up";
    string constant SONG_SYMBOL = "NEVER";
    IMetadataModule constant METADATA_MODULE = IMetadataModule(address(390720730));
    string constant BASE_URI = "https://example.com/metadata/";
    string constant CONTRACT_URI = "https://example.com/storefront/";
    address public constant ARTIST_ADMIN = address(8888888888);
    uint32 constant EDITION_MAX_MINTABLE = type(uint32).max;
    uint32 constant RANDOMNESS_LOCKED_TIMESTAMP = 200;

    SoundCreatorV1 soundCreator;

    // Set up called before each test
    function setUp() public virtual {
        // Deploy SoundEdition implementation
        MockSoundEditionV1 soundEditionImplementation = new MockSoundEditionV1();

        soundCreator = new SoundCreatorV1(address(soundEditionImplementation));
    }

    // Returns a random address funded with ETH
    function getRandomAccount(uint256 num) public returns (address) {
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(num)))));
        // Fund with some ETH
        vm.deal(addr, 1e19);

        return addr;
    }

    function createGenericEdition() public returns (SoundEditionV1) {
        return
            SoundEditionV1(
                soundCreator.createSound(
                    SONG_NAME,
                    SONG_SYMBOL,
                    METADATA_MODULE,
                    BASE_URI,
                    CONTRACT_URI,
                    EDITION_MAX_MINTABLE,
                    EDITION_MAX_MINTABLE,
                    RANDOMNESS_LOCKED_TIMESTAMP
                )
            );
    }
}
