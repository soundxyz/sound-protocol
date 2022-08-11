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

    uint32 constant MAX_MINTABLE = 5;

    uint32 constant MINT_ID = 0;

    error InvalidRandomnessLock();

    function _createEdition()
        internal
        returns (
            SoundEditionV1 edition,
            FixedPricePublicSaleMinter minter,
            GoldenEggMetadataModule goldenEggModule
        )
    {
        minter = new FixedPricePublicSaleMinter();
        goldenEggModule = new GoldenEggMetadataModule();

        edition = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                goldenEggModule,
                BASE_URI,
                CONTRACT_URI,
                MAX_MINTABLE,
                MAX_MINTABLE,
                RANDOMNESS_LOCKED_TIMESTAMP
            )
        );

        edition.grantRole(edition.MINTER_ROLE(), address(minter));

        minter.createEditionMint(address(edition), PRICE, START_TIME, END_TIME, MAX_MINTABLE, MAX_MINTABLE);
    }

    // Test if tokenURI returns default metadata using baseURI, if auction is still active
    function test_getTokenURIBeforeAuctionEnded() external {
        (
            SoundEditionV1 edition,
            FixedPricePublicSaleMinter minter,
            GoldenEggMetadataModule goldenEggModule
        ) = _createEdition();

        vm.warp(START_TIME);
        minter.mint{ value: PRICE }(address(edition), MINT_ID, 1);
        uint256 tokenId = 1;

        uint256 goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        string memory expectedTokenURI = string.concat(BASE_URI, Strings.toString(tokenId));

        assertEq(goldenEggTokenId, 0);
        assertEq(edition.tokenURI(tokenId), expectedTokenURI);
    }

    // Test if tokenURI returns goldenEgg uri, when max tokens minted
    function test_getTokenURIAfterMaxMinted() external {
        (
            SoundEditionV1 edition,
            FixedPricePublicSaleMinter minter,
            GoldenEggMetadataModule goldenEggModule
        ) = _createEdition();

        vm.warp(START_TIME);
        uint32 quantity = MAX_MINTABLE;
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity);

        uint256 goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        string memory expectedTokenURI = string.concat(BASE_URI, "goldenEgg");

        assertEq(edition.tokenURI(goldenEggTokenId), expectedTokenURI);
    }

    // Test if tokenURI returns goldenEgg uri, when randomnessLockedTimestamp is passed
    function test_getTokenURIAfterRandomnessLockedTimestamp() external {
        (
            SoundEditionV1 edition,
            FixedPricePublicSaleMinter minter,
            GoldenEggMetadataModule goldenEggModule
        ) = _createEdition();

        vm.warp(START_TIME);
        uint32 quantity = MAX_MINTABLE - 1;
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity);

        vm.warp(RANDOMNESS_LOCKED_TIMESTAMP);
        uint256 goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        string memory expectedTokenURI = string.concat(BASE_URI, "goldenEgg");

        assertEq(edition.tokenURI(goldenEggTokenId), expectedTokenURI);
    }

    // ================================
    // setMintRandomnessLock()
    // ================================

    // Test if setMintRandomnessLock only callable by Edition's owner
    function test_setMintRandomnessRevertsForNonOwner() external {
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter, ) = _createEdition();

        vm.warp(START_TIME);
        uint32 quantity = MAX_MINTABLE - 1;
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity);

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        edition.setMintRandomnessLock(quantity);
    }

    // Test if setMintRandomnessLock reverts when new value is lower than totalMinted
    function test_setMintRandomnessRevertsForLowValue() external {
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter, ) = _createEdition();

        vm.warp(START_TIME);
        uint32 quantity = MAX_MINTABLE - 1;
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity);

        vm.expectRevert(InvalidRandomnessLock.selector);
        edition.setMintRandomnessLock(quantity - 1);
    }

    // Test when lowering mintRandomnessLockAfter for insufficient sales, it generates the golden egg
    function test_setMintRandomnessLockSuccess() external {
        (
            SoundEditionV1 edition,
            FixedPricePublicSaleMinter minter,
            GoldenEggMetadataModule goldenEggModule
        ) = _createEdition();

        vm.warp(START_TIME);
        uint32 quantity = MAX_MINTABLE - 1;
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity);

        uint256 goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        // golden egg not generated
        assertEq(goldenEggTokenId, 0);

        edition.setMintRandomnessLock(quantity);

        goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        string memory expectedTokenURI = string.concat(BASE_URI, "goldenEgg");
        assertEq(edition.tokenURI(goldenEggTokenId), expectedTokenURI);
    }

    // ================================
    // setRandomnessLockedTimestamp()
    // ================================

    // Test if setRandomnessLockedTimestamp only callable by Edition's owner
    function test_setRandomnessLockedTimestampRevertsForNonOwner() external {
        (SoundEditionV1 edition, , ) = _createEdition();

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        edition.setRandomnessLockedTimestamp(START_TIME);
    }

    // Test when lowering randomnessLockedTimestamp, it generates the golden egg
    function test_setRandomnessLockedTimestampSuccess() external {
        (
            SoundEditionV1 edition,
            FixedPricePublicSaleMinter minter,
            GoldenEggMetadataModule goldenEggModule
        ) = _createEdition();

        vm.warp(START_TIME);
        uint32 quantity = MAX_MINTABLE - 1;
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity);

        uint256 goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        // golden egg not generated
        assertEq(goldenEggTokenId, 0);

        uint32 newTimestamp = END_TIME - 1;
        vm.warp(newTimestamp);
        edition.setRandomnessLockedTimestamp(newTimestamp);

        goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        string memory expectedTokenURI = string.concat(BASE_URI, "goldenEgg");
        assertEq(edition.tokenURI(goldenEggTokenId), expectedTokenURI);
    }
}
