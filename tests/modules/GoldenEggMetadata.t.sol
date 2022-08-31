// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { Strings } from "openzeppelin/utils/Strings.sol";
import "forge-std/console.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { RangeEditionMinter } from "@modules/RangeEditionMinter.sol";
import { GoldenEggMetadata } from "@modules/GoldenEggMetadata.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { TestConfig } from "../TestConfig.sol";

contract GoldenEggMetadataTests is TestConfig {
    uint96 constant PRICE = 1 ether;

    uint32 constant START_TIME = 100;

    uint32 constant END_TIME = 200;

    uint16 constant AFFILIATE_FEE_BPS = 0;

    uint32 constant MAX_MINTABLE = 5;

    uint32 constant MINT_ID = 0;

    uint32 constant MAX_MINTABLE_PER_ACCOUNT_PUBLIC_SALE = 5;

    function _createEdition()
        internal
        returns (
            SoundEditionV1 edition,
            RangeEditionMinter minter,
            GoldenEggMetadata goldenEggModule
        )
    {
        minter = new RangeEditionMinter(feeRegistry);
        goldenEggModule = new GoldenEggMetadata();

        edition = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                goldenEggModule,
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                MAX_MINTABLE,
                MAX_MINTABLE,
                RANDOMNESS_LOCKED_TIMESTAMP
            )
        );

        edition.grantRoles(address(minter), edition.MINTER_ROLE());

        minter.createEditionMint(
            address(edition),
            PRICE,
            START_TIME,
            END_TIME - 1,
            END_TIME,
            0,
            AFFILIATE_FEE_BPS,
            MAX_MINTABLE,
            MAX_MINTABLE_PER_ACCOUNT_PUBLIC_SALE
        );
    }

    function test_getGoldenEggTokenId(
        uint32 maxMintable,
        uint32 mintRandomnessTimeThreshold,
        uint32 mintRandomnessTokenThreshold,
        uint32 mintQuantity
    ) external {
        vm.assume(maxMintable > 0 && maxMintable < 5000);
        vm.assume(mintQuantity > 0 && mintQuantity <= maxMintable);

        GoldenEggMetadata eggModule = new GoldenEggMetadata();

        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                eggModule,
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                maxMintable,
                mintRandomnessTimeThreshold,
                mintRandomnessTokenThreshold
            )
        );

        _createMintInstanceAndMint(edition, maxMintable, mintQuantity);

        bool isRandomnessLocked = mintQuantity >= mintRandomnessTokenThreshold ||
            block.timestamp >= mintRandomnessTimeThreshold;

        uint256 expectedGoldenEggId = mintRandomnessTokenThreshold == 0 ? 0 : isRandomnessLocked
            ? (uint256(uint72(edition.mintRandomness())) % mintRandomnessTokenThreshold) + 1
            : 0;

        assertEq(eggModule.getGoldenEggTokenId(edition), expectedGoldenEggId);
    }

    function _createMintInstanceAndMint(
        SoundEditionV1 edition,
        uint32 maxMintable,
        uint32 mintQuantity
    ) public {
        RangeEditionMinter minter = new RangeEditionMinter(feeRegistry);

        edition.grantRoles(address(minter), edition.MINTER_ROLE());

        minter.createEditionMint(
            address(edition),
            PRICE,
            0,
            END_TIME - 1,
            END_TIME,
            AFFILIATE_FEE_BPS,
            maxMintable, // max mintable lower
            maxMintable, // max mintable upper
            maxMintable // max mintable per account
        );

        minter.mint{ value: PRICE * mintQuantity }(address(edition), MINT_ID, mintQuantity, address(0));
    }

    // Test if tokenURI returns default metadata using baseURI, if auction is still active
    function test_getTokenURIBeforeAuctionEnded() external {
        (SoundEditionV1 edition, RangeEditionMinter minter, GoldenEggMetadata goldenEggModule) = _createEdition();

        vm.warp(START_TIME);
        minter.mint{ value: PRICE }(address(edition), MINT_ID, 1, address(0));
        uint256 tokenId = 1;

        uint256 goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        string memory expectedTokenURI = string.concat(BASE_URI, Strings.toString(tokenId));

        assertEq(goldenEggTokenId, 0);
        assertEq(edition.tokenURI(tokenId), expectedTokenURI);
    }

    // Test if tokenURI returns goldenEgg uri, when max tokens minted
    function test_getTokenURIAfterMaxMinted() external {
        (SoundEditionV1 edition, RangeEditionMinter minter, GoldenEggMetadata goldenEggModule) = _createEdition();

        vm.warp(START_TIME);
        uint32 quantity = MAX_MINTABLE;
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, address(0));

        uint256 goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        string memory expectedTokenURI = string.concat(BASE_URI, "goldenEgg");

        assertEq(edition.tokenURI(goldenEggTokenId), expectedTokenURI);
    }

    // Test if tokenURI returns goldenEgg uri, when mintRandomnessTimeThreshold is passed
    function test_getTokenURIAfterRandomnessLockedTimestamp() external {
        (SoundEditionV1 edition, RangeEditionMinter minter, GoldenEggMetadata goldenEggModule) = _createEdition();

        vm.warp(START_TIME);
        uint32 quantity = MAX_MINTABLE - 1;
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, address(0));

        // check golden egg has not been generated after minting one less than the max
        uint256 goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        assertEq(goldenEggTokenId, 0);

        vm.warp(RANDOMNESS_LOCKED_TIMESTAMP);
        goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        string memory expectedTokenURI = string.concat(BASE_URI, "goldenEgg");

        assertEq(edition.tokenURI(goldenEggTokenId), expectedTokenURI);
    }

    // ================================
    // setMintRandomnessLock()
    // ================================

    // Test if setMintRandomnessLock only callable by Edition's owner
    function test_setMintRandomnessRevertsForNonOwner() external {
        (SoundEditionV1 edition, RangeEditionMinter minter, ) = _createEdition();

        vm.warp(START_TIME);
        uint32 quantity = MAX_MINTABLE - 1;
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, address(0));

        address caller = getFundedAccount(1);
        vm.prank(caller);
        vm.expectRevert(OwnableRoles.Unauthorized.selector);
        edition.setMintRandomnessLock(quantity);
    }

    // Test if setMintRandomnessLock reverts when new value is lower than totalMinted
    function test_setMintRandomnessRevertsForLowValue() external {
        (SoundEditionV1 edition, RangeEditionMinter minter, ) = _createEdition();

        vm.warp(START_TIME);
        uint32 quantity = MAX_MINTABLE - 1;
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, address(0));

        vm.expectRevert(ISoundEditionV1.InvalidRandomnessLock.selector);
        edition.setMintRandomnessLock(quantity - 1);
    }

    // Test when owner lowering mintRandomnessLockAfter for insufficient sales, it generates the golden egg
    function test_setMintRandomnessLockViaOwnerSuccess() external {
        (SoundEditionV1 edition, RangeEditionMinter minter, GoldenEggMetadata goldenEggModule) = _createEdition();

        vm.warp(START_TIME);
        uint32 quantity = MAX_MINTABLE - 1;
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, address(0));

        uint256 goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        // golden egg not generated
        assertEq(goldenEggTokenId, 0);

        edition.setMintRandomnessLock(quantity);

        goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        string memory expectedTokenURI = string.concat(BASE_URI, "goldenEgg");
        assertEq(edition.tokenURI(goldenEggTokenId), expectedTokenURI);
    }

    // Test when admin lowering mintRandomnessLockAfter for insufficient sales, it generates the golden egg
    function test_setMintRandomnessLockViaAdminSuccess() external {
        (SoundEditionV1 edition, RangeEditionMinter minter, GoldenEggMetadata goldenEggModule) = _createEdition();

        address admin = address(789);
        edition.grantRoles(admin, edition.ADMIN_ROLE());

        vm.warp(START_TIME);
        uint32 quantity = MAX_MINTABLE - 1;
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, address(0));

        uint256 goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        // golden egg not generated
        assertEq(goldenEggTokenId, 0);

        vm.prank(admin);
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

        address caller = getFundedAccount(1);
        vm.prank(caller);
        vm.expectRevert(OwnableRoles.Unauthorized.selector);
        edition.setRandomnessLockedTimestamp(START_TIME);
    }

    // Test when owner lowering mintRandomnessTimeThreshold, it generates the golden egg
    function test_setRandomnessLockedTimestampViaOwnerSuccess() external {
        (SoundEditionV1 edition, RangeEditionMinter minter, GoldenEggMetadata goldenEggModule) = _createEdition();

        vm.warp(START_TIME);
        uint32 quantity = MAX_MINTABLE - 1;
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, address(0));

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

    // Test when admin lowering mintRandomnessTimeThreshold, it generates the golden egg
    function test_setRandomnessLockedTimestampViaAdminSuccess() external {
        (SoundEditionV1 edition, RangeEditionMinter minter, GoldenEggMetadata goldenEggModule) = _createEdition();

        address admin = address(789);
        edition.grantRoles(admin, edition.ADMIN_ROLE());

        vm.warp(START_TIME);
        uint32 quantity = MAX_MINTABLE - 1;
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, address(0));

        uint256 goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        // golden egg not generated
        assertEq(goldenEggTokenId, 0);

        uint32 newTimestamp = END_TIME - 1;
        vm.warp(newTimestamp);

        vm.prank(admin);
        edition.setRandomnessLockedTimestamp(newTimestamp);

        goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        string memory expectedTokenURI = string.concat(BASE_URI, "goldenEgg");
        assertEq(edition.tokenURI(goldenEggTokenId), expectedTokenURI);
    }
}
