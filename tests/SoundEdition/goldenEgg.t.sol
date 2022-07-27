// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "openzeppelin/utils/Strings.sol";

import "../TestConfig.sol";
import "../../contracts/modules/Minters/GoldenEggMinter.sol";
import "../../contracts/modules/Metadata/GoldenEggMetadataModule.sol";

contract SoundEdition_goldenEgg is TestConfig {
    uint256 constant PRICE = 1 ether;

    uint32 constant MAX_MINTED = 5;

    uint32 constant START_TIME = 100;

    uint32 constant END_TIME = 200;

    function _createEdition() internal returns (SoundEditionV1 edition, GoldenEggMinter minter) {
        minter = new GoldenEggMinter();
        GoldenEggMetadataModule goldenEggMetadataModule = new GoldenEggMetadataModule(minter);

        edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, goldenEggMetadataModule, BASE_URI, CONTRACT_URI)
        );

        edition.grantRole(edition.MINTER_ROLE(), address(minter));

        minter.createEditionMint(address(edition), PRICE, START_TIME, END_TIME, MAX_MINTED);
    }

    // Test if tokenURI returns default metadata using baseURI, if auction is still active
    function test_getTokenURIBeforeAuctionEnded() external {
        (SoundEditionV1 edition, GoldenEggMinter minter) = _createEdition();

        vm.warp(START_TIME);
        minter.mint{ value: PRICE }(address(edition), 1);
        uint256 tokenId = 1;

        uint256 goldenEggTokenId = minter.getGoldenEggTokenId(address(edition));
        string memory expectedTokenURI = string.concat(BASE_URI, Strings.toString(tokenId));

        assertEq(goldenEggTokenId, 0);
        assertEq(edition.tokenURI(tokenId), expectedTokenURI);
    }

    function test_getTokenURIAfterEndTime() external {
        (SoundEditionV1 edition, GoldenEggMinter minter) = _createEdition();

        vm.warp(START_TIME);
        uint32 quantity = 4;
        minter.mint{ value: PRICE * quantity }(address(edition), quantity);
        uint256 tokenId = 1;

        vm.warp(END_TIME + 1);
        uint256 goldenEggTokenId = minter.getGoldenEggTokenId(address(edition));
        string memory expectedTokenURI = string.concat(BASE_URI, "goldenEgg");

        assertEq(edition.tokenURI(goldenEggTokenId), expectedTokenURI);
    }

    function test_getTokenURIAfterMaxMinted() external {
        (SoundEditionV1 edition, GoldenEggMinter minter) = _createEdition();

        vm.warp(START_TIME);
        uint32 quantity = MAX_MINTED;
        minter.mint{ value: PRICE * quantity }(address(edition), quantity);
        uint256 tokenId = 1;

        uint256 goldenEggTokenId = minter.getGoldenEggTokenId(address(edition));
        string memory expectedTokenURI = string.concat(BASE_URI, "goldenEgg");

        assertEq(edition.tokenURI(goldenEggTokenId), expectedTokenURI);
    }
}
