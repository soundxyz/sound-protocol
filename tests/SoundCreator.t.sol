// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "./TestConfig.sol";
import "../contracts/SoundEdition/SoundEditionV1.sol";
import "../contracts/SoundCreator/SoundCreatorV1.sol";

contract SoundCreatorTests is TestConfig {
    // Tests that the factory deploys
    function test_deploysSoundCreator() public {
        SoundEditionV1 soundEditionImplementation = new SoundEditionV1();
        address soundRegistry = address(123);
        SoundCreatorV1 _soundCreator = new SoundCreatorV1(payable(soundEditionImplementation), soundRegistry);

        assert(address(_soundCreator) != address(0));

        assertEq(address(_soundCreator.soundRegistry()), soundRegistry);
        assertEq(address(_soundCreator.nftImplementation()), address(soundEditionImplementation));
    }

    // Tests that the factory creates a new sound NFT
    function test_createSound() public {
        SoundEditionV1 soundEdition = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                MASTER_MAX_MINTABLE,
                MASTER_MAX_MINTABLE,
                RANDOMNESS_LOCKED_TIMESTAMP
            )
        );

        assert(address(soundEdition) != address(0));
        assertEq(soundEdition.name(), SONG_NAME);
        assertEq(soundEdition.symbol(), SONG_SYMBOL);
    }
}
