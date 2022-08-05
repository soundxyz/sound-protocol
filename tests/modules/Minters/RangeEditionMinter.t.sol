pragma solidity ^0.8.15;

import "../../TestConfig.sol";
import "../../utils/InvariantTest.sol";
import "../../../contracts/SoundEdition/SoundEditionV1.sol";
import "../../../contracts/SoundCreator/SoundCreatorV1.sol";
import "../../../contracts/modules/Minters/RangeEditionMinter.sol";

contract RangeEditionMinterTests is TestConfig {
    uint256 constant PRICE = 1;

    uint32 constant START_TIME = 100;

    uint32 constant CLOSING_TIME = 200;

    uint32 constant END_TIME = 300;

    uint32 constant MAX_MINTABLE_LOWER = 5;

    uint32 constant MAX_MINTABLE_UPPER = 10;

    // prettier-ignore
    event RangeEditionMintCreated(
        address indexed edition,
        uint256 price,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    );

    event TimeRangeSet(address indexed edition, uint32 startTime, uint32 closingTime, uint32 endTime);

    event MaxMintableRangeSet(address indexed edition, uint32 maxMintableLower, uint32 maxMintableUpper);

    event PausedSet(address indexed edition, bool paused);

    event Locked(address indexed edition);

    function _createEditionAndMinter() internal returns (SoundEditionV1 edition, RangeEditionMinter minter) {
        edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        minter = new RangeEditionMinter();

        edition.grantRole(edition.MINTER_ROLE(), address(minter));

        minter.createEditionMint(
            address(edition),
            PRICE,
            START_TIME,
            CLOSING_TIME,
            END_TIME,
            MAX_MINTABLE_LOWER,
            MAX_MINTABLE_UPPER
        );
    }

    function test_createEditionMint(
        uint256 price,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    ) public {
        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        RangeEditionMinter minter = new RangeEditionMinter();

        bool hasRevert;

        if (!(startTime < closingTime && closingTime < endTime)) {
            vm.expectRevert(
                abi.encodeWithSelector(RangeEditionMinter.InvalidTimeRange.selector, startTime, closingTime, endTime)
            );
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
                price,
                startTime,
                closingTime,
                endTime,
                maxMintableLower,
                maxMintableUpper
            );
        }

        minter.createEditionMint(
            address(edition),
            price,
            startTime,
            closingTime,
            endTime,
            maxMintableLower,
            maxMintableUpper
        );

        if (!hasRevert) {
            RangeEditionMinter.EditionMintData memory data = minter.editionMintData(address(edition));
            assertEq(data.price, price);
            assertEq(data.startTime, startTime);
            assertEq(data.closingTime, closingTime);
            assertEq(data.endTime, endTime);
            assertEq(data.totalMinted, uint32(0));
            assertEq(data.maxMintableLower, maxMintableLower);
            assertEq(data.maxMintableUpper, maxMintableUpper);
            assertEq(data.paused, false);
        }
    }

    function test_mintUpdatesValuesAndMintsCorrectly() public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter();

        vm.warp(START_TIME);

        address caller = getRandomAccount(1);

        uint32 quantity = 2;

        RangeEditionMinter.EditionMintData memory data = minter.editionMintData(address(edition));

        assertEq(data.totalMinted, 0);

        vm.prank(caller);
        minter.mint{ value: PRICE * quantity }(address(edition), quantity);

        assertEq(edition.balanceOf(caller), uint256(quantity));

        data = minter.editionMintData(address(edition));

        assertEq(data.totalMinted, quantity);
    }

    function test_mintRevertForWrongEtherValue() public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter();

        uint32 quantity = 2;

        vm.warp(START_TIME);

        uint256 requiredPayment = quantity * PRICE;

        bytes memory expectedRevert = abi.encodeWithSelector(
            MintControllerBase.WrongEtherValue.selector,
            requiredPayment - 1,
            requiredPayment
        );

        vm.expectRevert(expectedRevert);
        minter.mint{ value: requiredPayment - 1 }(address(edition), quantity);
    }

    function test_mintRevertsForMintNotOpen() public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter();

        uint32 quantity = 1;

        vm.warp(START_TIME - 1);

        bytes memory expectedRevert = abi.encodeWithSelector(
            RangeEditionMinter.MintNotOpen.selector,
            START_TIME,
            END_TIME
        );

        vm.expectRevert(expectedRevert);
        minter.mint{ value: quantity * PRICE }(address(edition), quantity);

        vm.warp(START_TIME);
        minter.mint{ value: quantity * PRICE }(address(edition), quantity);

        vm.warp(END_TIME + 1);
        vm.expectRevert(expectedRevert);
        minter.mint{ value: quantity * PRICE }(address(edition), quantity);

        vm.warp(END_TIME);
        minter.mint{ value: quantity * PRICE }(address(edition), quantity);

        vm.warp(CLOSING_TIME);
        minter.mint{ value: quantity * PRICE }(address(edition), quantity);
    }

    function test_mintRevertsForSoldOut(uint32 quantityToBuyBeforeClosing, uint32 quantityToBuyAfterClosing) public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter();

        quantityToBuyBeforeClosing = uint32((quantityToBuyBeforeClosing % uint256(MAX_MINTABLE_UPPER * 2)) + 1);
        quantityToBuyAfterClosing = uint32((quantityToBuyAfterClosing % uint256(MAX_MINTABLE_UPPER * 2)) + 1);

        uint32 totalMinted;

        if (quantityToBuyBeforeClosing > MAX_MINTABLE_UPPER) {
            vm.expectRevert(abi.encodeWithSelector(RangeEditionMinter.SoldOut.selector, MAX_MINTABLE_UPPER));
        } else {
            totalMinted = quantityToBuyBeforeClosing;
        }
        vm.warp(START_TIME);
        minter.mint{ value: quantityToBuyBeforeClosing * PRICE }(address(edition), quantityToBuyBeforeClosing);

        if (totalMinted + quantityToBuyAfterClosing > MAX_MINTABLE_LOWER) {
            vm.expectRevert(abi.encodeWithSelector(RangeEditionMinter.SoldOut.selector, MAX_MINTABLE_LOWER));
        }
        vm.warp(CLOSING_TIME);
        minter.mint{ value: quantityToBuyAfterClosing * PRICE }(address(edition), quantityToBuyAfterClosing);
    }

    function test_setTime(
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime
    ) public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter();

        bool hasRevert;

        if (!(startTime < closingTime && closingTime < endTime)) {
            vm.expectRevert(
                abi.encodeWithSelector(RangeEditionMinter.InvalidTimeRange.selector, startTime, closingTime, endTime)
            );
            hasRevert = true;
        }

        if (!hasRevert) {
            vm.expectEmit(false, false, false, true);
            emit TimeRangeSet(address(edition), startTime, closingTime, endTime);
        }

        minter.setTimeRange(address(edition), startTime, closingTime, endTime);

        if (!hasRevert) {
            RangeEditionMinter.EditionMintData memory data = minter.editionMintData(address(edition));
            assertEq(data.startTime, startTime);
            assertEq(data.closingTime, closingTime);
            assertEq(data.endTime, endTime);
        }
    }

    function test_setMaxMintableRange(
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    ) public {
        (SoundEditionV1 edition, RangeEditionMinter minter) = _createEditionAndMinter();

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
            emit MaxMintableRangeSet(address(edition), maxMintableLower, maxMintableUpper);
        }

        minter.setMaxMintableRange(address(edition), maxMintableLower, maxMintableUpper);

        if (!hasRevert) {
            RangeEditionMinter.EditionMintData memory data = minter.editionMintData(address(edition));
            assertEq(data.maxMintableLower, maxMintableLower);
            assertEq(data.maxMintableUpper, maxMintableUpper);
        }
    }
}

contract RangeEditionMinterInvariants is RangeEditionMinterTests, InvariantTest {
    RangeEditionMinterUpdater minterUpdater;
    RangeEditionMinter minter;
    SoundEditionV1 edition;

    function setUp() public override {
        super.setUp();

        edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        minter = new RangeEditionMinter();

        edition.grantRole(edition.MINTER_ROLE(), address(minter));

        minter.createEditionMint(
            address(edition),
            PRICE,
            START_TIME,
            CLOSING_TIME,
            END_TIME,
            MAX_MINTABLE_LOWER,
            MAX_MINTABLE_UPPER
        );

        minterUpdater = new RangeEditionMinterUpdater(edition, minter);

        addTargetContract(address(minter));
    }

    function invariant_maxMintableRange() public {
        RangeEditionMinter.EditionMintData memory data = minter.editionMintData(address(edition));
        assertTrue(data.maxMintableLower < data.maxMintableUpper);
    }

    function invariant_timeRange() public {
        RangeEditionMinter.EditionMintData memory data = minter.editionMintData(address(edition));
        assertTrue(data.startTime < data.closingTime && data.closingTime < data.endTime);
    }
}

contract RangeEditionMinterUpdater {
    SoundEditionV1 edition;
    RangeEditionMinter minter;

    constructor(SoundEditionV1 _edition, RangeEditionMinter _minter) {
        edition = _edition;
        minter = _minter;
    }

    function setTimeRange(uint32 startTime, uint32 closingTime, uint32 endTime) public {
        minter.setTimeRange(address(edition), startTime, closingTime, endTime);
    }

    function setMaxMintableRange(uint32 maxMintableLower, uint32 maxMintableUpper) public {
        minter.setMaxMintableRange(address(edition), maxMintableLower, maxMintableUpper);
    }
}
