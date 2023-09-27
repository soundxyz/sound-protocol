// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./TestPlus.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { ISoundEditionV2, SoundEditionV2 } from "@core/SoundEditionV2.sol";

contract TestConfigV2 is TestPlus {
    uint256 internal _salt;

    SoundCreatorV1 soundCreator;

    function setUp() public virtual {
        soundCreator = new SoundCreatorV1(address(new SoundEditionV2()));
    }

    function createSoundEdition(ISoundEditionV2.EditionInitialization memory init) public returns (SoundEditionV2) {
        bytes memory initData = abi.encodeWithSelector(SoundEditionV2.initialize.selector, init);

        address[] memory contracts;
        bytes[] memory data;

        soundCreator.createSoundAndMints(bytes32(++_salt), initData, contracts, data);
        (address addr, ) = soundCreator.soundEditionAddress(address(this), bytes32(_salt));
        return SoundEditionV2(addr);
    }

    function genericEditionInitialization() public view returns (ISoundEditionV2.EditionInitialization memory init) {
        init.fundingRecipient = address(this);
        init.tierCreations = new ISoundEditionV2.TierCreation[](1);
    }
}
