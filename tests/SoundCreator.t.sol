// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "./TestConfig.sol";
import "../contracts/SoundEdition/SoundEditionV1.sol";
import "../contracts/SoundCreator/SoundCreatorV1.sol";

contract SoundCreatorTests is TestConfig {
    // Tests that the factory deploys
    function test_deploysSoundCreator() public {
        SoundEditionV1 soundNftImplementation = new SoundEditionV1();
        address soundRegistry = address(123);
        SoundCreatorV1 _soundCreator = new SoundCreatorV1(address(soundNftImplementation), soundRegistry);

        assert(address(_soundCreator) != address(0));

        assertEq(address(_soundCreator.soundRegistry()), soundRegistry);
        assertEq(address(_soundCreator.nftImplementation()), address(soundNftImplementation));
    }

    // Tests that the factory creates a new sound NFT
    function test_createSound() public {
        SoundEditionV1 soundNft = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI
            )
        );

        assert(address(soundNft) != address(0));
        assertEq(soundNft.name(), SONG_NAME);
        assertEq(soundNft.symbol(), SONG_SYMBOL);
    }
}
