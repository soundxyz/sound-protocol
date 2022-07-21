// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.5;

import "forge-std/Test.sol";

import "../contracts/SoundCreator/SoundCreatorV1.sol";
import "../contracts/SoundEdition/SoundEditionV1.sol";
import "../contracts/SoundRegistry/SoundRegistryV1.sol";

contract TestConfig is Test {
    // Artist contract creation vars
    string constant SONG_NAME = "Never Gonna Give You Up";
    string constant SONG_SYMBOL = "NEVER";

    SoundCreatorV1 soundCreator;

    // Set up called  before each test
    function setUp() public {
        // Deploy SoundEdition implementation
        SoundEditionV1 soundEditionImplementation = new SoundEditionV1();

        // todo: deploy registry here
        address soundRegistry = address(123);

        soundCreator = new SoundCreatorV1(
            address(soundEditionImplementation),
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

    // Creates signature needed for registering a Sound NFT
    function getRegistrationSignature(
        SoundRegistryV1 soundRegistry,
        uint256 signerPrivateKey,
        address nftAddress
    ) public returns (bytes memory signature) {
        // Build auth signature
        // (equivalent to ethers.js wallet._signTypedData())
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                soundRegistry.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(soundRegistry.SIGNATURE_TYPEHASH(), nftAddress)
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
