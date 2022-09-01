pragma solidity ^0.8.16;

import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { RangeEditionMinter } from "@modules/RangeEditionMinter.sol";
import { IRangeEditionMinter, MintInfo } from "@modules/interfaces/IRangeEditionMinter.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { BaseMinter } from "@modules/BaseMinter.sol";
import { TestConfig } from "../TestConfig.sol";

contract RangeEditionMinterTests is TestConfig {
    uint96 constant PRICE = 1;

    uint32 constant START_TIME = 100;

    uint32 constant CLOSING_TIME = 200;

    uint32 constant END_TIME = 300;

    uint16 constant AFFILIATE_FEE_BPS = 0;

    uint32 constant MAX_MINTABLE_LOWER = 5;

    uint32 constant MAX_MINTABLE_UPPER = 10;

    uint128 constant MINT_ID = 0;

    uint32 constant MAX_MINTABLE_PER_ACCOUNT = 0;

    // prettier-ignore
    event RangeEditionMintCreated(
        address indexed edition,
        uint128 indexed mintId,
        uint96 price,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime,
        uint16 affiliateFeeBps,
        uint32 maxMintableLower,
        uint32 maxMintableUpper,
        uint32 maxMintablePerAccount
    );

    event ClosingTimeSet(address indexed edition, uint128 indexed mintId, uint32 closingTime);

    event MaxMintableRangeSet(
        address indexed edition,
        uint128 indexed mintId,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    );

    event TimeRangeSet(address indexed edition, uint128 indexed mintId, uint32 startTime, uint32 endTime);

    function _createEditionAndMinter(uint32 _maxMintablePerAccount)
        internal
        returns (SoundEditionV1 edition, RangeEditionMinter minter)
    {
        edition = createGenericEdition();

        minter = new RangeEditionMinter(feeRegistry);

        edition.grantRoles(address(minter), edition.MINTER_ROLE());

        minter.createEditionMint(
            address(edition),
            PRICE,
            START_TIME,
            CLOSING_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS,
            MAX_MINTABLE_LOWER,
            MAX_MINTABLE_UPPER,
            _maxMintablePerAccount
        );
    }

    function test_createEditionMint(
        uint96 price,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime,
        uint16 affiliateFeeBPS,
        uint32 maxMintableLower,
        uint32 maxMintableUpper,
        uint32 maxMintablePerAccount
    ) public {
        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                MAX_MINTABLE_UPPER,
                EDITION_MAX_MINTABLE,
                RANDOMNESS_LOCKED_TIMESTAMP
            )
        );

        RangeEditionMinter minter = new RangeEditionMinter(feeRegistry);

        bool hasRevert;

        if (!(startTime < closingTime && closingTime < endTime)) {
            vm.expectRevert(IMinterModule.InvalidTimeRange.selector);
            hasRevert = true;
        } else if (!(maxMintableLower <= maxMintableUpper)) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IRangeEditionMinter.InvalidMaxMintableRange.selector,
                    maxMintableLower,
                    maxMintableUpper
                )
            );
            hasRevert = true;
        } else if (affiliateFeeBPS > minter.MAX_BPS()) {
            vm.expectRevert(IMinterModule.InvalidAffiliateFeeBPS.selector);
            hasRevert = true;
        }

        if (!hasRevert) {
            vm.expectEmit(false, false, false, true);
            emit RangeEditionMintCreated(
                address(edition),
                MINT_ID,
                price,
                startTime,
                closingTime,
                endTime,
                affiliateFeeBPS,
                maxMintableLower,
                maxMintableUpper,
                maxMintablePerAccount
            );
        }

        minter.createEditionMint(
            address(edition),
            price,
            startTime,
            closingTime,
            endTime,
            affiliateFeeBPS,
            maxMintableLower,
            maxMintableUpper,
            maxMintablePerAccount
        );

        if (!hasRevert) {
            MintInfo memory mintInfo = minter.mintInfo(address(edition), MINT_ID);

            assertEq(mintInfo.price, price);
            assertEq(mintInfo.startTime, startTime);
            assertEq(mintInfo.closingTime, closingTime);
            assertEq(mintInfo.endTime, endTime);
            assertEq(mintInfo.totalMinted, uint32(0));
            assertEq(mintInfo.maxMintableLower, maxMintableLower);
            assertEq(mintInfo.maxMintableUpper, maxMintableUpper);
        }
    }

    function test_createEditionMintEmitsEvent() public {
        SoundEditionV1 edition = createGenericEdition();

        RangeEditionMinter minter = new RangeEditionMinter(feeRegistry);

        vm.expectEmit(false, false, false, true);

        emit RangeEditionMintCreated(
            address(edition),
            MINT_ID,
            PRICE,
            START_TIME,
            CLOSING_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS,
            MAX_MINTABLE_UPPER,
            EDITION_MAX_MINTABLE,
            0
        );

        minter.createEditionMint(
            address(edition),
            PRICE,
            START_TIME,
            CLOSING_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS,
            MAX_MINTABLE_UPPER,
            EDITION_MAX_MINTABLE,
            0
        );
    }

    function test_mintWhenOverMaxMintablePerAccountReverts() public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(1);
        vm.warp(START_TIME);

        address caller = getFundedAccount(1);
        vm.prank(caller);
        vm.expectRevert(IRangeEditionMinter.ExceedsMaxPerAccount.selector);
        minter.mint{ value: PRICE * 2 }(address(edition), MINT_ID, 2, address(0));
    }

    function test_mintWhenMintablePerAccountIsSetAndSatisfied() public {
        // Set max allowed per account to 2
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(2);

        // Ensure we can mint the max allowed of 2 tokens
        address caller = getFundedAccount(1);
        vm.warp(START_TIME);
        vm.prank(caller);
        minter.mint{ value: PRICE * 2 }(address(edition), MINT_ID, 2, address(0));

        assertEq(edition.balanceOf(caller), 2);

        MintInfo memory data = minter.mintInfo(address(edition), MINT_ID);
        assertEq(data.totalMinted, 2);
    }

    function test_mintUpdatesValuesAndMintsCorrectly() public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(type(uint32).max);

        vm.warp(START_TIME);

        address caller = getFundedAccount(1);

        uint32 quantity = 2;

        MintInfo memory data = minter.mintInfo(address(edition), MINT_ID);

        assertEq(data.totalMinted, 0);

        vm.prank(caller);
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, address(0));

        assertEq(edition.balanceOf(caller), uint256(quantity));

        data = minter.mintInfo(address(edition), MINT_ID);

        assertEq(data.totalMinted, quantity);
    }

    function test_mintRevertForUnderpaid() public {
        uint32 quantity = 2;
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(quantity);

        vm.warp(START_TIME);

        uint256 requiredPayment = quantity * PRICE;

        bytes memory expectedRevert = abi.encodeWithSelector(
            IMinterModule.Underpaid.selector,
            requiredPayment - 1,
            requiredPayment
        );

        vm.expectRevert(expectedRevert);
        minter.mint{ value: requiredPayment - 1 }(address(edition), MINT_ID, quantity, address(0));
    }

    function test_mintRevertsForMintNotOpen() public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(type(uint32).max);

        uint32 quantity = 1;

        vm.warp(START_TIME - 1);
        vm.expectRevert(
            abi.encodeWithSelector(IMinterModule.MintNotOpen.selector, block.timestamp, START_TIME, END_TIME)
        );
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity, address(0));

        vm.warp(START_TIME);
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity, address(0));

        vm.warp(END_TIME + 1);
        vm.expectRevert(
            abi.encodeWithSelector(IMinterModule.MintNotOpen.selector, block.timestamp, START_TIME, END_TIME)
        );
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity, address(0));

        vm.warp(END_TIME);
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity, address(0));

        vm.warp(CLOSING_TIME);
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity, address(0));
    }

    function test_mintRevertsForSoldOut(uint32 quantityToBuyBeforeClosing, uint32 quantityToBuyAfterClosing) public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(type(uint32).max);

        quantityToBuyBeforeClosing = uint32((quantityToBuyBeforeClosing % uint256(MAX_MINTABLE_UPPER * 2)) + 1);
        quantityToBuyAfterClosing = uint32((quantityToBuyAfterClosing % uint256(MAX_MINTABLE_UPPER * 2)) + 1);

        uint32 totalMinted;

        if (quantityToBuyBeforeClosing > MAX_MINTABLE_UPPER) {
            vm.expectRevert(
                abi.encodeWithSelector(IMinterModule.ExceedsAvailableSupply.selector, MAX_MINTABLE_UPPER - totalMinted)
            );
        } else {
            totalMinted = quantityToBuyBeforeClosing;
        }
        vm.warp(START_TIME);
        minter.mint{ value: quantityToBuyBeforeClosing * PRICE }(
            address(edition),
            MINT_ID,
            quantityToBuyBeforeClosing,
            address(0)
        );

        if (totalMinted + quantityToBuyAfterClosing > MAX_MINTABLE_LOWER) {
            uint32 available = MAX_MINTABLE_LOWER > totalMinted ? MAX_MINTABLE_LOWER - totalMinted : 0;
            vm.expectRevert(abi.encodeWithSelector(IMinterModule.ExceedsAvailableSupply.selector, available));
        }
        vm.warp(CLOSING_TIME);
        minter.mint{ value: quantityToBuyAfterClosing * PRICE }(
            address(edition),
            MINT_ID,
            quantityToBuyAfterClosing,
            address(0)
        );
    }

    function test_mintRevertsForSoldOut() public {
        test_mintRevertsForSoldOut(1, 1);
        test_mintRevertsForSoldOut(MAX_MINTABLE_UPPER, MAX_MINTABLE_LOWER);
        test_mintRevertsForSoldOut(MAX_MINTABLE_LOWER, MAX_MINTABLE_UPPER);
    }

    function test_mintBeforeAndAfterClosingTimeBaseCase() public {
        uint32 quantity = 1;
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(quantity);
        uint32 maxMintableLower = 0;
        uint32 maxMintableUpper = 1;
        minter.setMaxMintableRange(address(edition), MINT_ID, maxMintableLower, maxMintableUpper);

        vm.warp(START_TIME);
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity, address(0));

        vm.warp(CLOSING_TIME);
        vm.expectRevert(abi.encodeWithSelector(IMinterModule.ExceedsAvailableSupply.selector, maxMintableLower));
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity, address(0));
    }

    function test_canSetTimeRangeBaseMinter(address nonController) public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(0);

        vm.assume(nonController != address(this));

        // Set new values
        vm.expectEmit(true, true, true, true);
        emit TimeRangeSet(address(edition), MINT_ID, 123, 456);
        minter.setTimeRange(address(edition), MINT_ID, 123, 456);

        MintInfo memory mintInfo = minter.mintInfo(address(edition), MINT_ID);

        // Check new values
        assertEq(mintInfo.startTime, 123);
        assertEq(mintInfo.endTime, 456);

        // Ensure only controller can set time range
        vm.prank(nonController);
        vm.expectRevert(IMinterModule.Unauthorized.selector);
        minter.setTimeRange(address(edition), MINT_ID, 456, 789);
    }

    function test_cannotSetInvalidTimeRangeBaseMinter(uint32 startTime, uint32 endTime) public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(0);

        // Ensure startTime cannot be after closing time
        vm.assume(startTime > CLOSING_TIME);
        vm.expectRevert(IMinterModule.InvalidTimeRange.selector);
        minter.setTimeRange(address(edition), MINT_ID, startTime, endTime);

        // Ensure endTime cannot be before closing time
        vm.assume(endTime < CLOSING_TIME);
        vm.expectRevert(IMinterModule.InvalidTimeRange.selector);
        minter.setTimeRange(address(edition), MINT_ID, startTime, endTime);
    }

    function test_setTimeRange(
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime
    ) public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(0);

        bool hasRevert;
        if (!(startTime < closingTime && closingTime < endTime)) {
            vm.expectRevert(IMinterModule.InvalidTimeRange.selector);
            hasRevert = true;
        }

        if (!hasRevert) {
            vm.expectEmit(false, false, false, true);
            emit ClosingTimeSet(address(edition), MINT_ID, closingTime);
        }

        minter.setTimeRange(address(edition), MINT_ID, startTime, closingTime, endTime);

        if (!hasRevert) {
            MintInfo memory mintInfo = minter.mintInfo(address(edition), MINT_ID);

            assertEq(mintInfo.startTime, startTime);
            assertEq(mintInfo.closingTime, closingTime);
            assertEq(mintInfo.endTime, endTime);
        }
    }

    function test_setMaxMintableRange(uint32 maxMintableLower, uint32 maxMintableUpper) public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(0);

        bool hasRevert;

        if (!(maxMintableLower <= maxMintableUpper)) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IRangeEditionMinter.InvalidMaxMintableRange.selector,
                    maxMintableLower,
                    maxMintableUpper
                )
            );
            hasRevert = true;
        }

        if (!hasRevert) {
            vm.expectEmit(false, false, false, true);
            emit MaxMintableRangeSet(address(edition), MINT_ID, maxMintableLower, maxMintableUpper);
        }

        minter.setMaxMintableRange(address(edition), MINT_ID, maxMintableLower, maxMintableUpper);

        if (!hasRevert) {
            MintInfo memory data = minter.mintInfo(address(edition), MINT_ID);
            assertEq(data.maxMintableLower, maxMintableLower);
            assertEq(data.maxMintableUpper, maxMintableUpper);
        }
    }

    function test_supportsInterface() public {
        (, RangeEditionMinter minter) = _createEditionAndMinter(0);

        bool supportsIMinterModule = minter.supportsInterface(type(IMinterModule).interfaceId);
        bool supportsIRangeEditionMinter = minter.supportsInterface(type(IRangeEditionMinter).interfaceId);
        bool supports165 = minter.supportsInterface(type(IERC165).interfaceId);

        assertTrue(supports165);
        assertTrue(supportsIRangeEditionMinter);
        assertTrue(supportsIMinterModule);
    }

    function test_moduleInterfaceId() public {
        (, RangeEditionMinter minter) = _createEditionAndMinter(0);

        assertTrue(type(IRangeEditionMinter).interfaceId == minter.moduleInterfaceId());
    }

    function test_mintInfo() public {
        SoundEditionV1 edition = createGenericEdition();

        RangeEditionMinter minter = new RangeEditionMinter(feeRegistry);

        edition.grantRoles(address(minter), edition.MINTER_ROLE());

        uint32 expectedStartTime = 123;
        uint32 expectedEndTime = 502370;
        uint32 expectedPrice = 1234071;
        uint32 expectedMaxAllowedPerWallet = 937;

        minter.createEditionMint(
            address(edition),
            expectedPrice,
            expectedStartTime,
            CLOSING_TIME,
            expectedEndTime,
            AFFILIATE_FEE_BPS,
            MAX_MINTABLE_LOWER,
            MAX_MINTABLE_UPPER,
            expectedMaxAllowedPerWallet
        );

        MintInfo memory mintData = minter.mintInfo(address(edition), MINT_ID);

        assertEq(expectedStartTime, mintData.startTime);
        assertEq(expectedEndTime, mintData.endTime);
        assertEq(0, mintData.affiliateFeeBPS);
        assertEq(false, mintData.mintPaused);
        assertEq(expectedPrice, mintData.price);
        assertEq(expectedMaxAllowedPerWallet, mintData.maxMintablePerAccount);
        assertEq(MAX_MINTABLE_UPPER, mintData.maxMintableUpper);
        assertEq(MAX_MINTABLE_LOWER, mintData.maxMintableLower);
        assertEq(0, mintData.totalMinted);
        assertEq(CLOSING_TIME, mintData.closingTime);

        // Warp to start time & mint some tokens to test that totalMinted changed
        vm.warp(expectedStartTime);
        minter.mint{ value: mintData.price * 4 }(address(edition), MINT_ID, 4, address(0));

        mintData = minter.mintInfo(address(edition), MINT_ID);

        assertEq(4, mintData.totalMinted);
    }
}
