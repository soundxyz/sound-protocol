pragma solidity ^0.8.16;

import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { EditionMaxMinter } from "@modules/EditionMaxMinter.sol";
import { IEditionMaxMinter, MintInfo } from "@modules/interfaces/IEditionMaxMinter.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { BaseMinter } from "@modules/BaseMinter.sol";
import { TestConfig } from "../TestConfig.sol";

contract EditionMaxMinterTests is TestConfig {
    uint96 constant PRICE = 1;

    uint32 constant START_TIME = 100;

    uint32 constant CUTOFF_TIME = 200;

    uint32 constant END_TIME = 300;

    uint16 constant AFFILIATE_FEE_BPS = 0;

    uint32 constant MAX_MINTABLE_LOWER = 5;

    uint32 constant MAX_MINTABLE_UPPER = 10;

    uint128 constant MINT_ID = 0;

    uint32 constant MAX_MINTABLE_PER_ACCOUNT = type(uint32).max;

    // prettier-ignore
    event EditionMaxMintCreated(
        address indexed edition,
        uint128 indexed mintId,
        uint96 price,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBps,
        uint32 maxMintablePerAccount
    );

    // prettier-ignore
    event PriceSet(
        address indexed edition,
        uint128 indexed mintId,
        uint96 price
    );

    // prettier-ignore
    event MaxMintablePerAccountSet(
        address indexed edition,
        uint128 indexed mintId,
        uint32 maxMintablePerAccount
    );

    // prettier-ignore
    event TimeRangeSet(
        address indexed edition,
        uint128 indexed mintId,
        uint32 startTime,
        uint32 endTime
    );

    function _createEditionAndMinter(uint32 _maxMintablePerAccount)
        internal
        returns (SoundEditionV1 edition, EditionMaxMinter minter)
    {
        edition = createGenericEdition();

        edition.setEditionMaxMintableRange(MAX_MINTABLE_LOWER, MAX_MINTABLE_UPPER);
        edition.setEditionCutoffTime(CUTOFF_TIME);

        minter = new EditionMaxMinter(feeRegistry);

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
                EDITION_MAX_MINTABLE,
                EDITION_MAX_MINTABLE,
                EDITION_CUTOFF_TIME,
                FLAGS
            )
        );

        EditionMaxMinter minter = new EditionMaxMinter(feeRegistry);

        bool hasRevert;

        if (maxMintablePerAccount == 0) {
            vm.expectRevert(IEditionMaxMinter.MaxMintablePerAccountIsZero.selector);
            hasRevert = true;
        } else if (!(startTime < endTime)) {
            vm.expectRevert(IMinterModule.InvalidTimeRange.selector);
            hasRevert = true;
        } else if (affiliateFeeBPS > minter.MAX_BPS()) {
            vm.expectRevert(IMinterModule.InvalidAffiliateFeeBPS.selector);
            hasRevert = true;
        }

        if (!hasRevert) {
            vm.expectEmit(true, true, true, true);
            emit EditionMaxMintCreated(
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

        EditionMaxMinter minter = new EditionMaxMinter(feeRegistry);

        vm.expectEmit(true, true, true, true);

        emit EditionMaxMintCreated(
            address(edition),
            MINT_ID,
            PRICE,
            START_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS,
            type(uint32).max
        );

        minter.createEditionMint(address(edition), PRICE, START_TIME, END_TIME, AFFILIATE_FEE_BPS, type(uint32).max);
    }

    function test_mintWhenOverMaxMintablePerAccountReverts() public {
        (SoundEditionV1 edition, EditionMaxMinter minter) = _createEditionAndMinter(1);
        vm.warp(START_TIME);

        address caller = getFundedAccount(1);
        vm.prank(caller);
        vm.expectRevert(IEditionMaxMinter.ExceedsMaxPerAccount.selector);
        minter.mint{ value: PRICE * 2 }(address(edition), MINT_ID, 2, address(0));
    }

    function test_mintWhenOverMaxMintableDueToPreviousMintedReverts() public {
        (SoundEditionV1 edition, EditionMaxMinter minter) = _createEditionAndMinter(3);
        vm.warp(START_TIME);

        address caller = getFundedAccount(1);

        // have 2 previously minted
        address owner = address(12345);
        edition.transferOwnership(owner);
        vm.prank(owner);
        edition.mint(caller, 2);

        // attempting to mint 2 more reverts
        vm.prank(caller);
        vm.expectRevert(IEditionMaxMinter.ExceedsMaxPerAccount.selector);
        minter.mint{ value: PRICE * 2 }(address(edition), MINT_ID, 2, address(0));
    }

    function test_mintWhenMintablePerAccountIsSetAndSatisfied() public {
        // Set max allowed per account to 3
        (SoundEditionV1 edition, EditionMaxMinter minter) = _createEditionAndMinter(3);

        address caller = getFundedAccount(1);

        // Set 1 previous mint
        address owner = address(12345);
        edition.transferOwnership(owner);
        vm.prank(owner);
        edition.mint(caller, 1);

        // Ensure we can mint the max allowed of 2 tokens
        vm.warp(START_TIME);
        vm.prank(caller);
        minter.mint{ value: PRICE * 2 }(address(edition), MINT_ID, 2, address(0));

        assertEq(edition.balanceOf(caller), 3);

        assertEq(edition.totalMinted(), 3);
    }

    function test_mintUpdatesValuesAndMintsCorrectly() public {
        (SoundEditionV1 edition, EditionMaxMinter minter) = _createEditionAndMinter(type(uint32).max);

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
        (SoundEditionV1 edition, EditionMaxMinter minter) = _createEditionAndMinter(quantity);

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
        (SoundEditionV1 edition, EditionMaxMinter minter) = _createEditionAndMinter(type(uint32).max);

        uint32 quantity = 1;

        vm.warp(START_TIME - 1);
        vm.expectRevert(
            abi.encodeWithSelector(IMinterModule.MintNotOpen.selector, block.timestamp, START_TIME, END_TIME)
        );
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity, address(0));

        vm.warp(START_TIME);
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity, address(0));

        vm.warp(CUTOFF_TIME);
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity, address(0));

        vm.warp(END_TIME);
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity, address(0));

        vm.warp(END_TIME + 1);
        vm.expectRevert(
            abi.encodeWithSelector(IMinterModule.MintNotOpen.selector, block.timestamp, START_TIME, END_TIME)
        );
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity, address(0));
    }

    function test_setPrice(uint96 price) public {
        (SoundEditionV1 edition, EditionMaxMinter minter) = _createEditionAndMinter(type(uint32).max);

        vm.expectEmit(true, true, true, true);
        emit PriceSet(address(edition), MINT_ID, price);
        minter.setPrice(address(edition), MINT_ID, price);

        assertEq(minter.mintInfo(address(edition), MINT_ID).price, price);
    }

    function test_setMaxMintablePerAccount(uint32 maxMintablePerAccount) public {
        vm.assume(maxMintablePerAccount != 0);
        (SoundEditionV1 edition, EditionMaxMinter minter) = _createEditionAndMinter(type(uint32).max);

        vm.expectEmit(true, true, true, true);
        emit MaxMintablePerAccountSet(address(edition), MINT_ID, maxMintablePerAccount);
        minter.setMaxMintablePerAccount(address(edition), MINT_ID, maxMintablePerAccount);

        assertEq(minter.mintInfo(address(edition), MINT_ID).maxMintablePerAccount, maxMintablePerAccount);
    }

    function test_setZeroMaxMintablePerAccountReverts() public {
        (SoundEditionV1 edition, EditionMaxMinter minter) = _createEditionAndMinter(type(uint32).max);

        vm.expectRevert(IEditionMaxMinter.MaxMintablePerAccountIsZero.selector);
        minter.setMaxMintablePerAccount(address(edition), MINT_ID, 0);
    }

    function test_createWithZeroMaxMintablePerAccountReverts() public {
        (SoundEditionV1 edition, EditionMaxMinter minter) = _createEditionAndMinter(type(uint32).max);

        vm.expectRevert(IEditionMaxMinter.MaxMintablePerAccountIsZero.selector);
        minter.createEditionMint(address(edition), PRICE, START_TIME, END_TIME, AFFILIATE_FEE_BPS, 0);
    }

    function test_supportsInterface() public {
        (, EditionMaxMinter minter) = _createEditionAndMinter(type(uint32).max);

        bool supportsIMinterModule = minter.supportsInterface(type(IMinterModule).interfaceId);
        bool supportsIEditionMaxMinter = minter.supportsInterface(type(IEditionMaxMinter).interfaceId);
        bool supports165 = minter.supportsInterface(type(IERC165).interfaceId);

        assertTrue(supports165);
        assertTrue(supportsIEditionMaxMinter);
        assertTrue(supportsIMinterModule);
    }

    function test_moduleInterfaceId() public {
        (, EditionMaxMinter minter) = _createEditionAndMinter(type(uint32).max);

        assertTrue(type(IEditionMaxMinter).interfaceId == minter.moduleInterfaceId());
    }

    function test_mintInfo(
        uint96 price,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS,
        uint32 maxMintablePerAccount,
        uint32 editionMaxMintableLower,
        uint32 editionMaxMintableUpper,
        uint32 editionCutOffTime
    ) public {
        vm.assume(startTime < endTime);
        vm.assume(editionMaxMintableLower <= editionMaxMintableUpper);

        affiliateFeeBPS = uint16(affiliateFeeBPS % MAX_BPS);

        uint32 quantity = 4;

        if (maxMintablePerAccount < quantity) maxMintablePerAccount = quantity;
        if (editionMaxMintableLower < quantity) editionMaxMintableLower = quantity;
        if (editionMaxMintableUpper < quantity) editionMaxMintableUpper = quantity;

        SoundEditionV1 edition = SoundEditionV1(
            createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                editionMaxMintableLower,
                editionMaxMintableUpper,
                editionCutOffTime,
                FLAGS
            )
        );

        EditionMaxMinter minter = new EditionMaxMinter(feeRegistry);

        edition.grantRoles(address(minter), edition.MINTER_ROLE());

        minter.createEditionMint(address(edition), price, startTime, endTime, affiliateFeeBPS, maxMintablePerAccount);

        MintInfo memory mintInfo = minter.mintInfo(address(edition), MINT_ID);

        assertEq(startTime, mintInfo.startTime);
        assertEq(endTime, mintInfo.endTime);
        assertEq(affiliateFeeBPS, mintInfo.affiliateFeeBPS);
        assertEq(false, mintInfo.mintPaused);
        assertEq(price, mintInfo.price);
        assertEq(maxMintablePerAccount, mintInfo.maxMintablePerAccount);
        assertEq(editionMaxMintableLower, mintInfo.maxMintableLower);
        assertEq(editionMaxMintableUpper, mintInfo.maxMintableUpper);
        assertEq(editionCutOffTime, mintInfo.cutoffTime);

        assertEq(0, edition.totalMinted());

        // Warp to start time & mint some tokens to test that totalMinted changed
        vm.warp(startTime);
        vm.deal(address(this), uint256(mintInfo.price) * uint256(quantity));
        minter.mint{ value: uint256(mintInfo.price) * uint256(quantity) }(
            address(edition),
            MINT_ID,
            quantity,
            address(0)
        );

        mintInfo = minter.mintInfo(address(edition), MINT_ID);

        assertEq(quantity, edition.totalMinted());
    }

    function test_mintInfo() public {
        test_mintInfo(
            123123, /* price */
            100, /* startTime */
            200, /* endTime */
            10, /* affiliateFeeBPS */
            100, /* maxMintablePerAccount */
            1111, /* editionMaxMintableLower */
            2222, /* editionMaxMintableUpper */
            150 /* editionCutOffTime*/
        );
    }
}
