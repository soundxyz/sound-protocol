// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.5;

import "forge-std/Test.sol";

import "../contracts/SoundCreator/SoundCreatorV1.sol";
import "../contracts/SoundEdition/SoundEditionV1.sol";

contract TestConfig is Test {
    // Artist contract creation vars
    string constant SONG_NAME = "Never Gonna Give You Up";
    string constant SONG_SYMBOL = "NEVER";

    SoundCreatorV1 soundCreator;

    // Set up called  before each test
    function setUp() public {
        // Deploy SoundEdition implementation
        SoundEditionV1 soundNftImplementation = new SoundEditionV1();

        // todo: deploy registry here
        address soundRegistry = address(123);

        soundCreator = new SoundCreatorV1(
            address(soundNftImplementation),
            soundRegistry
        );
    }

    // Returns a random address funded with ETH
    function getRandomAccount(uint256 num) public returns (address) {
        address addr = address(
            uint160(uint256(keccak256(abi.encodePacked(num))))
        );
        // Fund with some ETH
        vm.deal(addr, 1e19);

        return addr;
    }
}
