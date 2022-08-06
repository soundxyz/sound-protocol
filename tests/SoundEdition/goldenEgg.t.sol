// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "openzeppelin/utils/Strings.sol";

import "../TestConfig.sol";
import "../../contracts/modules/Minters/FixedPricePublicSaleMinter.sol";
import "../../contracts/modules/Metadata/GoldenEggMetadataModule.sol";

contract SoundEdition_goldenEgg is TestConfig {
    uint256 constant PRICE = 1 ether;

    uint32 constant START_TIME = 100;

    uint32 constant END_TIME = 200;

    error InvalidRandomnessLock();

    function _createEdition() internal returns (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) {
        minter = new FixedPricePublicSaleMinter();
        GoldenEggMetadataModule goldenEggMetadataModule = new GoldenEggMetadataModule();

        edition = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                goldenEggMetadataModule,
                BASE_URI,
                CONTRACT_URI,
                MAX_MINTABLE
            )
        );

        edition.grantRole(edition.MINTER_ROLE(), address(minter));

        minter.createEditionMint(address(edition), PRICE, START_TIME, END_TIME, MAX_MINTABLE);
    }

    // Test if tokenURI returns default metadata using baseURI, if auction is still active
    function test_getTokenURIBeforeAuctionEnded() external {
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEdition();

        vm.warp(START_TIME);
        minter.mint{ value: PRICE }(address(edition), 1);
        uint256 tokenId = 1;

        uint256 goldenEggTokenId = edition.getGoldenEggTokenId();
        string memory expectedTokenURI = string.concat(BASE_URI, Strings.toString(tokenId));

        assertEq(goldenEggTokenId, 0);
        assertEq(edition.tokenURI(tokenId), expectedTokenURI);
    }

    // Test if tokenURI returns goldenEgg uri, when max tokens minted
    function test_getTokenURIAfterMaxMinted() external {
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEdition();

        vm.warp(START_TIME);
        uint32 quantity = MAX_MINTABLE;
        minter.mint{ value: PRICE * quantity }(address(edition), quantity);

        uint256 goldenEggTokenId = edition.getGoldenEggTokenId();
        string memory expectedTokenURI = string.concat(BASE_URI, "goldenEgg");

        assertEq(edition.tokenURI(goldenEggTokenId), expectedTokenURI);
    }

    // ================================
    // setMintRandomness()
    // ================================

    // Test if setMintRandomness only callable by Edition's owner
    function test_setMintRandomnessRevertsForNonOwner() external {
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEdition();

        vm.warp(START_TIME);
        uint32 quantity = MAX_MINTABLE - 1;
        minter.mint{ value: PRICE * quantity }(address(edition), quantity);

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        edition.setMintRandomnessLock(quantity);
    }

    // Test if setMintRandomness reverts when new value is lower than totalMinted
    function test_setMintRandomnessRevertsForLowValue() external {
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEdition();

        vm.warp(START_TIME);
        uint32 quantity = MAX_MINTABLE - 1;
        minter.mint{ value: PRICE * quantity }(address(edition), quantity);

        vm.expectRevert(InvalidRandomnessLock.selector);
        edition.setMintRandomnessLock(quantity - 1);
    }

    // Test when lowering mintRandomnessLockAfter for insufficient sales, it generates the golden egg
    function test_setMintRandomnessLockSuccess() external {
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEdition();

        vm.warp(START_TIME);
        uint32 quantity = MAX_MINTABLE - 1;
        minter.mint{ value: PRICE * quantity }(address(edition), quantity);

        uint256 goldenEggTokenId = edition.getGoldenEggTokenId();
        // golden egg not generated
        assertEq(goldenEggTokenId, 0);

        edition.setMintRandomnessLock(quantity);

        goldenEggTokenId = edition.getGoldenEggTokenId();
        string memory expectedTokenURI = string.concat(BASE_URI, "goldenEgg");
        assertEq(edition.tokenURI(goldenEggTokenId), expectedTokenURI);
    }
}
