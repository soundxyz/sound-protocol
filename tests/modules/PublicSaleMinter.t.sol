pragma solidity ^0.8.16;

import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { PublicSaleMinter } from "@modules/PublicSaleMinter.sol";
import { IPublicSaleMinter, MintInfo } from "@modules/interfaces/IPublicSaleMinter.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { BaseMinter } from "@modules/BaseMinter.sol";
import { TestConfig } from "../TestConfig.sol";

contract PublicSaleMinterTests is TestConfig {
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
    event PublicSaleMintCreated(
        address indexed edition,
        uint128 indexed mintId,
        uint96 price,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBps,
        uint32 maxMintablePerAccount
    );

    event TimeRangeSet(address indexed edition, uint128 indexed mintId, uint32 startTime, uint32 endTime);

    function _createEditionAndMinter(uint32 _maxMintablePerAccount)
        internal
        returns (SoundEditionV1 edition, PublicSaleMinter minter)
    {
        edition = createGenericEdition();

        edition.reduceEditionMaxMintable(MAX_MINTABLE_UPPER);
        edition.setMintRandomnessTokenThreshold(MAX_MINTABLE_LOWER);
        edition.setRandomnessTimeThreshold(CLOSING_TIME);

        minter = new PublicSaleMinter(feeRegistry);

        edition.grantRoles(address(minter), edition.MINTER_ROLE());

        minter.createEditionMint(
            address(edition),
            PRICE,
            START_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS,
            _maxMintablePerAccount
        );
    }

    function test_createEditionMint(
        uint96 price,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS,
        uint32 maxMintablePerAccount
    ) public {
        SoundEditionV1 edition = SoundEditionV1(
            createSound(
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

        PublicSaleMinter minter = new PublicSaleMinter(feeRegistry);

        bool hasRevert;

        if (!(startTime < endTime)) {
            vm.expectRevert(IMinterModule.InvalidTimeRange.selector);
            hasRevert = true;
        } else if (affiliateFeeBPS > minter.MAX_BPS()) {
            vm.expectRevert(IMinterModule.InvalidAffiliateFeeBPS.selector);
            hasRevert = true;
        }

        if (!hasRevert) {
            vm.expectEmit(false, false, false, true);
            emit PublicSaleMintCreated(
                address(edition),
                MINT_ID,
                price,
                startTime,
                endTime,
                affiliateFeeBPS,
                maxMintablePerAccount
            );
        }

        minter.createEditionMint(address(edition), price, startTime, endTime, affiliateFeeBPS, maxMintablePerAccount);

        if (!hasRevert) {
            MintInfo memory mintInfo = minter.mintInfo(address(edition), MINT_ID);

            assertEq(mintInfo.price, price);
            assertEq(mintInfo.startTime, startTime);
            assertEq(mintInfo.endTime, endTime);
        }
    }

    function test_createEditionMintEmitsEvent() public {
        SoundEditionV1 edition = createGenericEdition();

        PublicSaleMinter minter = new PublicSaleMinter(feeRegistry);

        vm.expectEmit(false, false, false, true);

        emit PublicSaleMintCreated(address(edition), MINT_ID, PRICE, START_TIME, END_TIME, AFFILIATE_FEE_BPS, 0);

        minter.createEditionMint(address(edition), PRICE, START_TIME, END_TIME, AFFILIATE_FEE_BPS, 0);
    }

    function test_mintWhenOverMaxMintablePerAccountReverts() public {
        (SoundEditionV1 edition, PublicSaleMinter minter) = _createEditionAndMinter(1);
        vm.warp(START_TIME);

        address caller = getFundedAccount(1);
        vm.prank(caller);
        vm.expectRevert(IPublicSaleMinter.ExceedsMaxPerAccount.selector);
        minter.mint{ value: PRICE * 2 }(address(edition), MINT_ID, 2, address(0));
    }

    function test_mintWhenMintablePerAccountIsSetAndSatisfied() public {
        // Set max allowed per account to 2
        (SoundEditionV1 edition, PublicSaleMinter minter) = _createEditionAndMinter(2);

        // Ensure we can mint the max allowed of 2 tokens
        address caller = getFundedAccount(1);
        vm.warp(START_TIME);
        vm.prank(caller);
        minter.mint{ value: PRICE * 2 }(address(edition), MINT_ID, 2, address(0));

        assertEq(edition.balanceOf(caller), 2);

        assertEq(edition.totalMinted(), 2);
    }

    function test_mintUpdatesValuesAndMintsCorrectly() public {
        (SoundEditionV1 edition, PublicSaleMinter minter) = _createEditionAndMinter(type(uint32).max);

        vm.warp(START_TIME);

        address caller = getFundedAccount(1);

        uint32 quantity = 2;

        assertEq(edition.totalMinted(), 0);

        vm.prank(caller);
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, address(0));

        assertEq(edition.balanceOf(caller), uint256(quantity));

        assertEq(edition.totalMinted(), quantity);
    }

    function test_mintRevertForUnderpaid() public {
        uint32 quantity = 2;
        (SoundEditionV1 edition, PublicSaleMinter minter) = _createEditionAndMinter(quantity);

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
        (SoundEditionV1 edition, PublicSaleMinter minter) = _createEditionAndMinter(type(uint32).max);

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
        (SoundEditionV1 edition, PublicSaleMinter minter) = _createEditionAndMinter(type(uint32).max);

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
        (SoundEditionV1 edition, PublicSaleMinter minter) = _createEditionAndMinter(quantity);
        uint32 maxMintableLower = 0;
        uint32 maxMintableUpper = 1;
        edition.setMintRandomnessTokenThreshold(maxMintableLower);
        edition.setMintRandomnessTokenThreshold(maxMintableUpper);

        vm.warp(START_TIME);
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity, address(0));

        vm.warp(CLOSING_TIME);
        vm.expectRevert(abi.encodeWithSelector(IMinterModule.ExceedsAvailableSupply.selector, maxMintableLower));
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity, address(0));
    }

    function test_supportsInterface() public {
        (, PublicSaleMinter minter) = _createEditionAndMinter(0);

        bool supportsIMinterModule = minter.supportsInterface(type(IMinterModule).interfaceId);
        bool supportsIPublicSaleMinter = minter.supportsInterface(type(IPublicSaleMinter).interfaceId);
        bool supports165 = minter.supportsInterface(type(IERC165).interfaceId);

        assertTrue(supports165);
        assertTrue(supportsIPublicSaleMinter);
        assertTrue(supportsIMinterModule);
    }

    function test_moduleInterfaceId() public {
        (, PublicSaleMinter minter) = _createEditionAndMinter(0);

        assertTrue(type(IPublicSaleMinter).interfaceId == minter.moduleInterfaceId());
    }

    function test_mintInfo() public {
        SoundEditionV1 edition = createGenericEdition();

        PublicSaleMinter minter = new PublicSaleMinter(feeRegistry);

        edition.grantRoles(address(minter), edition.MINTER_ROLE());

        uint32 expectedStartTime = 123;
        uint32 expectedEndTime = 502370;
        uint32 expectedPrice = 1234071;
        uint32 expectedMaxAllowedPerWallet = 937;

        minter.createEditionMint(
            address(edition),
            expectedPrice,
            expectedStartTime,
            expectedEndTime,
            AFFILIATE_FEE_BPS,
            expectedMaxAllowedPerWallet
        );

        MintInfo memory mintData = minter.mintInfo(address(edition), MINT_ID);

        assertEq(expectedStartTime, mintData.startTime);
        assertEq(expectedEndTime, mintData.endTime);
        assertEq(0, mintData.affiliateFeeBPS);
        assertEq(false, mintData.mintPaused);
        assertEq(expectedPrice, mintData.price);
        assertEq(expectedMaxAllowedPerWallet, mintData.maxMintablePerAccount);
        assertEq(0, edition.totalMinted());

        // Warp to start time & mint some tokens to test that totalMinted changed
        vm.warp(expectedStartTime);
        minter.mint{ value: mintData.price * 4 }(address(edition), MINT_ID, 4, address(0));

        mintData = minter.mintInfo(address(edition), MINT_ID);

        assertEq(4, edition.totalMinted());
    }
}
