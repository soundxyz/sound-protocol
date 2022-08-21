pragma solidity ^0.8.16;

import "../../TestConfig.sol";
import "../../../contracts/SoundEdition/SoundEditionV1.sol";
import "../../../contracts/SoundCreator/SoundCreatorV1.sol";
import "../../../contracts/modules/Minters/RangeEditionMinter.sol";
import "../../../contracts/interfaces/IBaseMinter.sol";
import "../../../contracts/interfaces/IStandardMint.sol";
import { BaseData, StandardMintData } from "../../../contracts/interfaces/MinterStructs.sol";

contract RangeEditionMinterTests is TestConfig {
    uint256 constant PRICE = 1;

    uint32 constant START_TIME = 100;

    uint32 constant CLOSING_TIME = 200;

    uint32 constant END_TIME = 300;

    uint32 constant MAX_MINTABLE_LOWER = 5;

    uint32 constant MAX_MINTABLE_UPPER = 10;

    uint256 constant MINT_ID = 0;

    uint32 constant MAX_ALLOWED_PER_WALLET = 0;

    // prettier-ignore
    event RangeEditionMintCreated(
        address indexed edition,
        uint256 indexed mintId,
        uint256 price,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime,
        uint32 maxMintableLower,
        uint32 maxMintableUpper,
        uint32 maxAllowedPerWallet
    );

    event ClosingTimeSet(address indexed edition, uint256 indexed mintId, uint32 closingTime);

    event MaxMintableRangeSet(
        address indexed edition,
        uint256 indexed mintId,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    );

    function _createEditionAndMinter(uint32 _maxAllowedPerWallet)
        internal
        returns (SoundEditionV1 edition, RangeEditionMinter minter)
    {
        edition = createGenericEdition();

        minter = new RangeEditionMinter();

        edition.grantRole(edition.MINTER_ROLE(), address(minter));

        minter.createEditionMint(
            address(edition),
            PRICE,
            START_TIME,
            CLOSING_TIME,
            END_TIME,
            MAX_MINTABLE_LOWER,
            MAX_MINTABLE_UPPER,
            _maxAllowedPerWallet
        );
    }

    function test_createEditionMint(
        uint256 price,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime,
        uint32 maxMintableLower,
        uint32 maxMintableUpper,
        uint32 maxAllowedPerWallet
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

        RangeEditionMinter minter = new RangeEditionMinter();

        bool hasRevert;

        if (!(startTime < closingTime && closingTime < endTime)) {
            vm.expectRevert(BaseMinter.InvalidTimeRange.selector);
            hasRevert = true;
        } else if (!(maxMintableLower < maxMintableUpper)) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    RangeEditionMinter.InvalidMaxMintableRange.selector,
                    maxMintableLower,
                    maxMintableUpper
                )
            );
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
                maxMintableLower,
                maxMintableUpper,
                maxAllowedPerWallet
            );
        }

        minter.createEditionMint(
            address(edition),
            price,
            startTime,
            closingTime,
            endTime,
            maxMintableLower,
            maxMintableUpper,
            maxAllowedPerWallet
        );

        if (!hasRevert) {
            RangeEditionMinter.EditionMintData memory data = minter.editionMintData(address(edition), MINT_ID);
            BaseData memory baseData = minter.baseMintData(address(edition), MINT_ID);

            assertEq(data.price, price);
            assertEq(baseData.startTime, startTime);
            assertEq(data.closingTime, closingTime);
            assertEq(baseData.endTime, endTime);
            assertEq(data.totalMinted, uint32(0));
            assertEq(data.maxMintableLower, maxMintableLower);
            assertEq(data.maxMintableUpper, maxMintableUpper);
        }
    }

    function test_createEditionMintEmitsEvent() public {
        SoundEditionV1 edition = createGenericEdition();

        RangeEditionMinter minter = new RangeEditionMinter();

        vm.expectEmit(false, false, false, true);

        emit RangeEditionMintCreated(
            address(edition),
            MINT_ID,
            PRICE,
            START_TIME,
            CLOSING_TIME,
            END_TIME,
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
            MAX_MINTABLE_UPPER,
            EDITION_MAX_MINTABLE,
            0
        );
    }

    function test_mintWhenOverMaxAllowedPerWalletReverts() public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(1);
        vm.warp(START_TIME);

        address caller = getFundedAccount(1);
        vm.prank(caller);
        vm.expectRevert(RangeEditionMinter.ExceedsMaxPerWallet.selector);
        minter.mint{ value: PRICE * 2 }(address(edition), MINT_ID, 2);
    }

    function test_mintWhenAllowedPerWalletIsSetAndSatisfied() public {
        // Set max allowed per wallet to 2
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(2);

        // Ensure we can mint the max allowed of 2 tokens
        address caller = getFundedAccount(1);
        vm.warp(START_TIME);
        vm.prank(caller);
        minter.mint{ value: PRICE * 2 }(address(edition), MINT_ID, 2);

        assertEq(edition.balanceOf(caller), 2);

        RangeEditionMinter.EditionMintData memory data = minter.editionMintData(address(edition), MINT_ID);
        assertEq(data.totalMinted, 2);
    }

    function test_mintUpdatesValuesAndMintsCorrectly() public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(0);

        vm.warp(START_TIME);

        address caller = getFundedAccount(1);

        uint32 quantity = 2;

        RangeEditionMinter.EditionMintData memory data = minter.editionMintData(address(edition), MINT_ID);

        assertEq(data.totalMinted, 0);

        vm.prank(caller);
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity);

        assertEq(edition.balanceOf(caller), uint256(quantity));

        data = minter.editionMintData(address(edition), MINT_ID);

        assertEq(data.totalMinted, quantity);
    }

    function test_mintRevertForWrongEtherValue() public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(0);

        uint32 quantity = 2;

        vm.warp(START_TIME);

        uint256 requiredPayment = quantity * PRICE;

        bytes memory expectedRevert = abi.encodeWithSelector(
            BaseMinter.WrongEtherValue.selector,
            requiredPayment - 1,
            requiredPayment
        );

        vm.expectRevert(expectedRevert);
        minter.mint{ value: requiredPayment - 1 }(address(edition), MINT_ID, quantity);
    }

    function test_mintRevertsForMintNotOpen() public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(0);

        uint32 quantity = 1;

        vm.warp(START_TIME - 1);
        vm.expectRevert(abi.encodeWithSelector(BaseMinter.MintNotOpen.selector, block.timestamp, START_TIME, END_TIME));
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity);

        vm.warp(START_TIME);
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity);

        vm.warp(END_TIME + 1);
        vm.expectRevert(abi.encodeWithSelector(BaseMinter.MintNotOpen.selector, block.timestamp, START_TIME, END_TIME));
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity);

        vm.warp(END_TIME);
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity);

        vm.warp(CLOSING_TIME);
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity);
    }

    function test_mintRevertsForSoldOut(uint32 quantityToBuyBeforeClosing, uint32 quantityToBuyAfterClosing) public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(0);

        quantityToBuyBeforeClosing = uint32((quantityToBuyBeforeClosing % uint256(MAX_MINTABLE_UPPER * 2)) + 1);
        quantityToBuyAfterClosing = uint32((quantityToBuyAfterClosing % uint256(MAX_MINTABLE_UPPER * 2)) + 1);

        uint32 totalMinted;

        if (quantityToBuyBeforeClosing > MAX_MINTABLE_UPPER) {
            vm.expectRevert(abi.encodeWithSelector(BaseMinter.MaxMintableReached.selector, MAX_MINTABLE_UPPER));
        } else {
            totalMinted = quantityToBuyBeforeClosing;
        }
        vm.warp(START_TIME);
        minter.mint{ value: quantityToBuyBeforeClosing * PRICE }(address(edition), MINT_ID, quantityToBuyBeforeClosing);

        if (totalMinted + quantityToBuyAfterClosing > MAX_MINTABLE_LOWER) {
            vm.expectRevert(abi.encodeWithSelector(BaseMinter.MaxMintableReached.selector, MAX_MINTABLE_LOWER));
        }
        vm.warp(CLOSING_TIME);
        minter.mint{ value: quantityToBuyAfterClosing * PRICE }(address(edition), MINT_ID, quantityToBuyAfterClosing);
    }

    function test_mintBeforeAndAfterClosingTimeBaseCase() public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(0);
        uint32 maxMintableLower = 0;
        uint32 maxMintableUpper = 1;
        minter.setMaxMintableRange(address(edition), MINT_ID, maxMintableLower, maxMintableUpper);

        uint32 quantity = 1;

        vm.warp(START_TIME);
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity);

        vm.warp(CLOSING_TIME);
        vm.expectRevert(abi.encodeWithSelector(BaseMinter.MaxMintableReached.selector, maxMintableLower));
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity);
    }

    function test_setTimeRange(
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime
    ) public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(0);

        bool hasRevert;
        if (!(startTime < closingTime && closingTime < endTime)) {
            vm.expectRevert(BaseMinter.InvalidTimeRange.selector);
            hasRevert = true;
        }

        if (!hasRevert) {
            vm.expectEmit(false, false, false, true);
            emit ClosingTimeSet(address(edition), MINT_ID, closingTime);
        }

        minter.setTimeRange(address(edition), MINT_ID, startTime, closingTime, endTime);

        if (!hasRevert) {
            RangeEditionMinter.EditionMintData memory data = minter.editionMintData(address(edition), MINT_ID);
            BaseData memory baseData = minter.baseMintData(address(edition), MINT_ID);

            assertEq(baseData.startTime, startTime);
            assertEq(data.closingTime, closingTime);
            assertEq(baseData.endTime, endTime);
        }
    }

    function test_setMaxMintableRange(uint32 maxMintableLower, uint32 maxMintableUpper) public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter(0);

        bool hasRevert;

        if (!(maxMintableLower < maxMintableUpper)) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    RangeEditionMinter.InvalidMaxMintableRange.selector,
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
            RangeEditionMinter.EditionMintData memory data = minter.editionMintData(address(edition), MINT_ID);
            assertEq(data.maxMintableLower, maxMintableLower);
            assertEq(data.maxMintableUpper, maxMintableUpper);
        }
    }

    function test_supportsInterface() public {
        (, RangeEditionMinter minter) = _createEditionAndMinter(0);

        bool supportsIBaseMinter = minter.supportsInterface(type(IBaseMinter).interfaceId);
        bool supportsIStandardMint = minter.supportsInterface(type(IStandardMint).interfaceId);

        assertTrue(supportsIBaseMinter);
        assertTrue(supportsIStandardMint);
    }

    function test_standardMintData() public {
        SoundEditionV1 edition = createGenericEdition();

        RangeEditionMinter minter = new RangeEditionMinter();

        edition.grantRole(edition.MINTER_ROLE(), address(minter));

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
            MAX_MINTABLE_LOWER,
            MAX_MINTABLE_UPPER,
            expectedMaxAllowedPerWallet
        );

        StandardMintData memory mintData = minter.standardMintData(address(edition), MINT_ID);

        assertEq(mintData.startTime, expectedStartTime);
        assertEq(mintData.endTime, expectedEndTime);
        assertEq(mintData.mintPaused, false);
        assertEq(mintData.price, expectedPrice);
        assertEq(mintData.maxAllowedPerWallet, expectedMaxAllowedPerWallet);
        assertEq(mintData.maxMintable, MAX_MINTABLE_UPPER);
        assertEq(mintData.totalMinted, 0);

        // Warp to closing time & mint some tokens to test that maxMintable & totalMinted changed
        vm.warp(CLOSING_TIME);
        minter.mint{ value: mintData.price * 4 }(address(edition), MINT_ID, 4);

        mintData = minter.standardMintData(address(edition), MINT_ID);

        assertEq(mintData.maxMintable, MAX_MINTABLE_LOWER);
        assertEq(mintData.totalMinted, 4);
    }
}
