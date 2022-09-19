// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { Strings } from "openzeppelin/utils/Strings.sol";

import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { RangeEditionMinter } from "@modules/RangeEditionMinter.sol";
import { GoldenEggMetadata } from "@modules/GoldenEggMetadata.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { TestConfig } from "../TestConfig.sol";

contract GoldenEggMetadataTests is TestConfig {
    uint96 constant PRICE = 1 ether;

    uint32 constant CUTOFF_TIME = 150;

    uint32 constant END_TIME = 200;

    uint16 constant AFFILIATE_FEE_BPS = 0;

    uint32 constant MAX_MINTABLE_LOWER = 42;

    uint32 constant MAX_MINTABLE_UPPER = 69;

    uint32 constant MINT_ID = 0;

    function _createEdition(uint32 editionCutoffTime)
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
            createSound(
                SONG_NAME,
                SONG_SYMBOL,
                address(goldenEggModule),
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                MAX_MINTABLE_LOWER,
                MAX_MINTABLE_UPPER,
                editionCutoffTime,
                FLAGS
            )
        );

        edition.grantRoles(address(minter), edition.MINTER_ROLE());

        minter.createEditionMint(
            address(edition),
            PRICE,
            0, // startTime
            CUTOFF_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS,
            MAX_MINTABLE_LOWER,
            MAX_MINTABLE_UPPER,
            type(uint32).max // maxMintablePerAccount
        );
    }

    function test_getGoldenEggTokenId(uint32 editionCutoffTime, uint32 mintQuantity) external {
        vm.assume(mintQuantity > 0 && mintQuantity < 10);
        vm.assume(editionCutoffTime > block.timestamp);

        GoldenEggMetadata eggModule = new GoldenEggMetadata();

        SoundEditionV1 edition = SoundEditionV1(
            createSound(
                SONG_NAME,
                SONG_SYMBOL,
                address(eggModule),
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                0, // maxMintableLower
                MAX_MINTABLE_UPPER,
                editionCutoffTime, // mintRandomnessTimeThreshold
                FLAGS
            )
        );

        RangeEditionMinter minter = new RangeEditionMinter(feeRegistry);

        edition.grantRoles(address(minter), edition.MINTER_ROLE());

        minter.createEditionMint(
            address(edition),
            PRICE,
            0, // startTime
            END_TIME - 1,
            END_TIME,
            AFFILIATE_FEE_BPS,
            EDITION_MAX_MINTABLE, // max mintable lower
            EDITION_MAX_MINTABLE, // max mintable upper
            EDITION_MAX_MINTABLE // max mintable per account
        );

        minter.mint{ value: PRICE * mintQuantity }(address(edition), MINT_ID, mintQuantity, address(0));

        vm.warp(editionCutoffTime);

        uint256 expectedGoldenEggId;
        uint256 mintRandomness = edition.mintRandomness();
        uint256 totalMinted = edition.totalMinted();
        if (mintRandomness != 0) {
            expectedGoldenEggId = (mintRandomness % totalMinted) + 1;
            assertTrue(edition.mintConcluded());
        } else {
            assertFalse(edition.mintConcluded());
        }

        assertEq(eggModule.getGoldenEggTokenId(edition), expectedGoldenEggId);
    }

    // Test if tokenURI returns default metadata using baseURI, if auction is still active
    function test_getTokenURIBeforeAuctionEnded() external {
        (SoundEditionV1 edition, RangeEditionMinter minter, GoldenEggMetadata goldenEggModule) = _createEdition(
            CUTOFF_TIME
        );

        minter.mint{ value: PRICE }(address(edition), MINT_ID, 1, address(0));
        uint256 tokenId = 1;

        uint256 goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        string memory expectedTokenURI = string.concat(BASE_URI, Strings.toString(tokenId));

        assertEq(goldenEggTokenId, 0);
        assertEq(edition.tokenURI(tokenId), expectedTokenURI);
    }

    // Test if tokenURI returns goldenEgg uri, when max tokens minted
    function test_getTokenURIAfterMaxMinted() external {
        (SoundEditionV1 edition, RangeEditionMinter minter, GoldenEggMetadata goldenEggModule) = _createEdition(
            CUTOFF_TIME
        );

        uint32 quantity = MAX_MINTABLE_UPPER;

        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, address(0));

        uint256 goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        string memory expectedTokenURI = string.concat(BASE_URI, "goldenEgg");

        assertEq(edition.tokenURI(goldenEggTokenId), expectedTokenURI);
    }

    // Test if tokenURI returns goldenEgg uri, when both randomnessLocked conditions have been met
    function test_getTokenURIAfterRandomnessLocked() external {
        uint32 quantity = MAX_MINTABLE_LOWER - 1;
        (SoundEditionV1 edition, RangeEditionMinter minter, GoldenEggMetadata goldenEggModule) = _createEdition(
            CUTOFF_TIME
        );

        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, address(0));

        // check golden egg has not been generated after minting one less than the max
        uint256 goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        assertEq(goldenEggTokenId, 0);

        // Mint one more to bring us to maxMintableLower
        minter.mint{ value: PRICE }(address(edition), MINT_ID, 1, address(0));

        // Warp to cutoff time, which is set to randomnessLockedTimeThreshold
        vm.warp(CUTOFF_TIME);
        goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        string memory expectedTokenURI = string.concat(BASE_URI, "goldenEgg");

        assertEq(edition.tokenURI(goldenEggTokenId), expectedTokenURI);
    }

    // =============================================================
    //              SET MINT RANDOMNESS TOKEN THRESHOLD
    // =============================================================

    // Test if setMintRandomnessTokenThreshold only callable by Edition's owner
    function test_setMintRandomnessRevertsForNonOwner() external {
        (SoundEditionV1 edition, RangeEditionMinter minter, ) = _createEdition(CUTOFF_TIME);

        uint32 quantity = MAX_MINTABLE_LOWER - 1;
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, address(0));

        address caller = getFundedAccount(1);
        vm.prank(caller);
        vm.expectRevert(OwnableRoles.Unauthorized.selector);
        edition.setEditionMaxMintableRange(quantity, MAX_MINTABLE_UPPER);
    }

    // Test when owner lowering mintRandomnessLockAfter for insufficient sales, it generates the golden egg
    function test_setMintRandomnessTokenThresholdViaOwnerSuccess() external {
        (SoundEditionV1 edition, RangeEditionMinter minter, GoldenEggMetadata goldenEggModule) = _createEdition(
            CUTOFF_TIME
        );

        uint32 quantity = MAX_MINTABLE_LOWER - 1;
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, address(0));

        uint256 goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        // golden egg not generated
        assertEq(goldenEggTokenId, 0);

        edition.setEditionMaxMintableRange(quantity, MAX_MINTABLE_UPPER);

        // Warp to cutoff time, which is set to randomnessLockedTimeThreshold
        vm.warp(CUTOFF_TIME);
        goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        string memory expectedTokenURI = string.concat(BASE_URI, "goldenEgg");
        assertEq(edition.tokenURI(goldenEggTokenId), expectedTokenURI);
    }

    // Test when admin lowering mintRandomnessLockAfter for insufficient sales, it generates the golden egg
    function test_setMintRandomnessTokenThresholdViaAdminSuccess() external {
        (SoundEditionV1 edition, RangeEditionMinter minter, GoldenEggMetadata goldenEggModule) = _createEdition(
            CUTOFF_TIME
        );

        address admin = address(789);
        edition.grantRoles(admin, edition.ADMIN_ROLE());

        uint32 quantity = MAX_MINTABLE_LOWER - 1;
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, address(0));

        uint256 goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        // golden egg not generated
        assertEq(goldenEggTokenId, 0);

        vm.prank(admin);
        edition.setEditionMaxMintableRange(quantity, MAX_MINTABLE_UPPER);

        // Warp to cutoff time, which is set to randomnessLockedTimeThreshold
        vm.warp(CUTOFF_TIME);
        goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        string memory expectedTokenURI = string.concat(BASE_URI, "goldenEgg");

        assertEq(edition.tokenURI(goldenEggTokenId), expectedTokenURI);
    }

    // =============================================================
    //              SET MINT RANDOMNESS TIME THRESHOLD
    // =============================================================

    // Test if setRandomnessTimeThreshold only callable by Edition's owner
    function test_setRandomnessTimeThresholdRevertsForNonOwner() external {
        (SoundEditionV1 edition, , ) = _createEdition(CUTOFF_TIME);

        address caller = getFundedAccount(1);
        vm.prank(caller);
        vm.expectRevert(OwnableRoles.Unauthorized.selector);
        edition.setEditionCutoffTime(666);
    }

    // Test when owner lowering mintRandomnessTimeThreshold, it generates the golden egg
    function test_setRandomnessTimeThresholdViaOwnerSuccess() external {
        uint32 randomnessTimeThreshold = type(uint32).max;
        (SoundEditionV1 edition, RangeEditionMinter minter, GoldenEggMetadata goldenEggModule) = _createEdition(
            randomnessTimeThreshold
        );

        uint32 quantity = MAX_MINTABLE_LOWER;
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, address(0));

        uint256 goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        // golden egg not generated
        assertEq(goldenEggTokenId, 0);

        edition.setEditionCutoffTime(CUTOFF_TIME);

        // Warp to cutoff time, which is set to randomnessLockedTimeThreshold
        vm.warp(CUTOFF_TIME);
        goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        string memory expectedTokenURI = string.concat(BASE_URI, "goldenEgg");

        assertEq(edition.tokenURI(goldenEggTokenId), expectedTokenURI);
    }

    // Test when admin lowering mintRandomnessTimeThreshold, it generates the golden egg
    function test_setRandomnessTimeThresholdViaAdminSuccess() external {
        uint32 randomnessTimeThreshold = type(uint32).max;
        (SoundEditionV1 edition, RangeEditionMinter minter, GoldenEggMetadata goldenEggModule) = _createEdition(
            randomnessTimeThreshold
        );

        address admin = address(789);
        edition.grantRoles(admin, edition.ADMIN_ROLE());

        uint32 quantity = MAX_MINTABLE_LOWER;
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, address(0));

        uint256 goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        // golden egg not generated
        assertEq(goldenEggTokenId, 0);

        vm.prank(admin);
        edition.setEditionCutoffTime(CUTOFF_TIME);

        // Warp to cutoff time, which is set to randomnessLockedTimeThreshold
        vm.warp(CUTOFF_TIME);
        goldenEggTokenId = goldenEggModule.getGoldenEggTokenId(edition);
        string memory expectedTokenURI = string.concat(BASE_URI, "goldenEgg");
        assertEq(edition.tokenURI(goldenEggTokenId), expectedTokenURI);
    }
}
