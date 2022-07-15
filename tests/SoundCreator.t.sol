pragma solidity ^0.8.15;

import "./TestConfig.sol";
import "../contracts/SoundNft/SoundNftV1.sol";
import "../contracts/SoundCreator/SoundCreatorV1.sol";

contract SoundCreatorTests is TestConfig {
    function test_deploysSoundCreator() public {
        // Deploy SoundNft implementation
        SoundNftV1 soundNftImplementation = new SoundNftV1();
        address soundRegistry = address(123);
        SoundCreatorV1 soundCreator = new SoundCreatorV1(
            address(soundNftImplementation),
            soundRegistry
        );

        assert(address(soundCreator) != address(0));

        assertEq(address(soundCreator.soundRegistry()), soundRegistry);
        assertEq(
            address(soundCreator.nftImplementation()),
            address(soundNftImplementation)
        );
    }

    function test_createSoundNft() public {
        SoundNftV1 soundNft = SoundNftV1(
            soundCreator.createSoundNft(SONG_NAME, SONG_SYMBOL)
        );

        assert(address(soundNft) != address(0));
        assertEq(soundNft.name(), SONG_NAME);
        assertEq(soundNft.symbol(), SONG_SYMBOL);
    }
}
