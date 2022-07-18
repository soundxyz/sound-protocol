pragma solidity ^0.8.15;

import "./TestConfig.sol";
import "../contracts/SoundNft/SoundNftV1.sol";
import "../contracts/SoundCreator/SoundCreatorV1.sol";

contract SoundCreatorTests is TestConfig {
    // Tests that the factory deploys
    function test_deploysSoundCreator() public {
        SoundNftV1 soundNftImplementation = new SoundNftV1();
        address soundRegistry = address(123);
        SoundCreatorV1 _soundCreator = new SoundCreatorV1(
            address(soundNftImplementation),
            soundRegistry
        );

        assert(address(_soundCreator) != address(0));

        assertEq(address(_soundCreator.soundRegistry()), soundRegistry);
        assertEq(
            address(_soundCreator.nftImplementation()),
            address(soundNftImplementation)
        );
    }

    // Tests that the factory creates a new sound NFT
    function test_createSoundNft() public {
        SoundNftV1 soundNft = SoundNftV1(
            soundCreator.createSoundNft(SONG_NAME, SONG_SYMBOL)
        );

        assert(address(soundNft) != address(0));
        assertEq(soundNft.name(), SONG_NAME);
        assertEq(soundNft.symbol(), SONG_SYMBOL);
    }
}
