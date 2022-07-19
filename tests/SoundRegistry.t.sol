pragma solidity ^0.8.15;

import "./TestConfig.sol";
import "../contracts/SoundNft/SoundNftV1.sol";
import "../contracts/SoundCreator/SoundCreatorV1.sol";

contract SoundRegistryTests is TestConfig {
    // Tests that the registry is initialized with the correct owner.
    function test_initializedWithOwner() public {}

    // Tests that unauthorized accounts can't change the signing authority.
    function test_unauthorizedChangeSigningAuthority() public {}

    // Tests that the signing authority can be changed.
    function test_changeSigningAuthority() public {}

    // Tests that unauthorized accounts can't register a Sound NFT.
    function test_unauthorizedRegisterSoundNft() public {}

    // Tests registering a Sound NFT.
    function test_registerSoundNft() public {}

    // Tests registering multiple Sound NFTs.
    function test_registerSoundNfts() public {}

    // Tests that unauthorized accounts can't unregister a Sound NFT.
    function test_unauthorizedUnregisterSoundNft() public {}

    // Tests unregistering a Sound NFT.
    function test_unregisterSoundNft() public {}

    // Tests unregistering multiple Sound NFTs.
    function test_unregisterSoundNfts() public {}
}
