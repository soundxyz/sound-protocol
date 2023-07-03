pragma solidity ^0.8.16;

import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { SoundEditionV1_2 } from "@core/SoundEditionV1_2.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { EditionMaxMinterV2_1 } from "@modules/EditionMaxMinterV2_1.sol";
import { IEditionMaxMinterV2_1, MintInfo } from "@modules/interfaces/IEditionMaxMinterV2_1.sol";
import { IMinterModuleV2_1 } from "@core/interfaces/IMinterModuleV2_1.sol";
import { BaseMinterV2_1 } from "@modules/BaseMinterV2_1.sol";
import { TestConfig } from "../TestConfig.sol";

contract EditionMaxMinterV2_1Tests is TestConfig {
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
        uint128 mintId,
        uint96 price,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBps,
        uint32 maxMintablePerAccount
    );

    // prettier-ignore
    event PriceSet(
        address indexed edition,
        uint128 mintId,
        uint96 price
    );

    // prettier-ignore
    event MaxMintablePerAccountSet(
        address indexed edition,
        uint128 mintId,
        uint32 maxMintablePerAccount
    );

    // prettier-ignore
    event TimeRangeSet(
        address indexed edition,
        uint128 mintId,
        uint32 startTime,
        uint32 endTime
    );

    function _createEditionAndMinter(uint32 _maxMintablePerAccount)
        internal
        returns (SoundEditionV1_2 edition, EditionMaxMinterV2_1 minter)
    {
        edition = createGenericEdition();

        edition.setEditionMaxMintableRange(MAX_MINTABLE_LOWER, MAX_MINTABLE_UPPER);
        edition.setEditionCutoffTime(CUTOFF_TIME);

        minter = new EditionMaxMinterV2_1();

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
        SoundEditionV1_2 edition = SoundEditionV1_2(
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

        EditionMaxMinterV2_1 minter = new EditionMaxMinterV2_1();

        bool hasRevert;

        if (maxMintablePerAccount == 0) {
            vm.expectRevert(IEditionMaxMinterV2_1.MaxMintablePerAccountIsZero.selector);
            hasRevert = true;
        } else if (!(startTime < endTime)) {
            vm.expectRevert(IMinterModuleV2_1.InvalidTimeRange.selector);
            hasRevert = true;
        } else if (affiliateFeeBPS > minter.MAX_AFFILIATE_FEE_BPS()) {
            vm.expectRevert(IMinterModuleV2_1.InvalidAffiliateFeeBPS.selector);
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
        SoundEditionV1_2 edition = createGenericEdition();

        EditionMaxMinterV2_1 minter = new EditionMaxMinterV2_1();

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
        (SoundEditionV1_2 edition, EditionMaxMinterV2_1 minter) = _createEditionAndMinter(1);
        vm.warp(START_TIME);

        address caller = getFundedAccount(1);
        vm.prank(caller);
        vm.expectRevert(IEditionMaxMinterV2_1.ExceedsMaxPerAccount.selector);
        minter.mint{ value: PRICE * 2 }(address(edition), MINT_ID, 2, address(0));
    }

    function test_mintWhenOverMaxMintableDueToPreviousMintedReverts() public {
        (SoundEditionV1_2 edition, EditionMaxMinterV2_1 minter) = _createEditionAndMinter(3);
        vm.warp(START_TIME);

        address caller = getFundedAccount(1);

        // have 2 previously minted
        address owner = address(12345);
        edition.transferOwnership(owner);
        vm.prank(owner);
        edition.mint(caller, 2);

        // attempting to mint 2 more reverts
        vm.prank(caller);
        vm.expectRevert(IEditionMaxMinterV2_1.ExceedsMaxPerAccount.selector);
        minter.mint{ value: PRICE * 2 }(address(edition), MINT_ID, 2, address(0));
    }

    function test_mintWhenMintablePerAccountIsSetAndSatisfied() public {
        // Set max allowed per account to 3
        (SoundEditionV1_2 edition, EditionMaxMinterV2_1 minter) = _createEditionAndMinter(3);

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
        (SoundEditionV1_2 edition, EditionMaxMinterV2_1 minter) = _createEditionAndMinter(type(uint32).max);

        vm.warp(START_TIME);

        address caller = getFundedAccount(1);

        uint32 quantity = 2;

        assertEq(edition.totalMinted(), 0);

        vm.prank(caller);
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, address(0));

        assertEq(edition.balanceOf(caller), uint256(quantity));

        assertEq(edition.totalMinted(), quantity);
    }

    function test_mintRevertForWrongPayment() public {
        uint32 quantity = 2;
        (SoundEditionV1_2 edition, EditionMaxMinterV2_1 minter) = _createEditionAndMinter(quantity);

        vm.warp(START_TIME);

        uint256 requiredPayment = quantity * PRICE;

        vm.expectRevert(
            abi.encodeWithSelector(IMinterModuleV2_1.WrongPayment.selector, requiredPayment - 1, requiredPayment)
        );
        minter.mint{ value: requiredPayment - 1 }(address(edition), MINT_ID, quantity, address(0));

        vm.expectRevert(
            abi.encodeWithSelector(IMinterModuleV2_1.WrongPayment.selector, requiredPayment + 1, requiredPayment)
        );
        minter.mint{ value: requiredPayment + 1 }(address(edition), MINT_ID, quantity, address(0));
    }

    function test_mintRevertsForMintNotOpen() public {
        (SoundEditionV1_2 edition, EditionMaxMinterV2_1 minter) = _createEditionAndMinter(type(uint32).max);

        uint32 quantity = 1;

        vm.warp(START_TIME - 1);
        vm.expectRevert(
            abi.encodeWithSelector(IMinterModuleV2_1.MintNotOpen.selector, block.timestamp, START_TIME, END_TIME)
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
            abi.encodeWithSelector(IMinterModuleV2_1.MintNotOpen.selector, block.timestamp, START_TIME, END_TIME)
        );
        minter.mint{ value: quantity * PRICE }(address(edition), MINT_ID, quantity, address(0));
    }

    function test_setPrice(uint96 price) public {
        (SoundEditionV1_2 edition, EditionMaxMinterV2_1 minter) = _createEditionAndMinter(type(uint32).max);

        vm.expectEmit(true, true, true, true);
        emit PriceSet(address(edition), MINT_ID, price);
        minter.setPrice(address(edition), MINT_ID, price);

        assertEq(minter.mintInfo(address(edition), MINT_ID).price, price);
    }

    function test_setMaxMintablePerAccount(uint32 maxMintablePerAccount) public {
        vm.assume(maxMintablePerAccount != 0);
        (SoundEditionV1_2 edition, EditionMaxMinterV2_1 minter) = _createEditionAndMinter(type(uint32).max);

        vm.expectEmit(true, true, true, true);
        emit MaxMintablePerAccountSet(address(edition), MINT_ID, maxMintablePerAccount);
        minter.setMaxMintablePerAccount(address(edition), MINT_ID, maxMintablePerAccount);

        assertEq(minter.mintInfo(address(edition), MINT_ID).maxMintablePerAccount, maxMintablePerAccount);
    }

    function test_setZeroMaxMintablePerAccountReverts() public {
        (SoundEditionV1_2 edition, EditionMaxMinterV2_1 minter) = _createEditionAndMinter(type(uint32).max);

        vm.expectRevert(IEditionMaxMinterV2_1.MaxMintablePerAccountIsZero.selector);
        minter.setMaxMintablePerAccount(address(edition), MINT_ID, 0);
    }

    function test_createWithZeroMaxMintablePerAccountReverts() public {
        (SoundEditionV1_2 edition, EditionMaxMinterV2_1 minter) = _createEditionAndMinter(type(uint32).max);

        vm.expectRevert(IEditionMaxMinterV2_1.MaxMintablePerAccountIsZero.selector);
        minter.createEditionMint(address(edition), PRICE, START_TIME, END_TIME, AFFILIATE_FEE_BPS, 0);
    }

    function test_supportsInterface() public {
        (, EditionMaxMinterV2_1 minter) = _createEditionAndMinter(type(uint32).max);

        bool supportsIMinterModuleV2_1 = minter.supportsInterface(type(IMinterModuleV2_1).interfaceId);
        bool supportsIEditionMaxMinterV2_1 = minter.supportsInterface(type(IEditionMaxMinterV2_1).interfaceId);
        bool supports165 = minter.supportsInterface(type(IERC165).interfaceId);

        assertTrue(supports165);
        assertTrue(supportsIEditionMaxMinterV2_1);
        assertTrue(supportsIMinterModuleV2_1);
    }

    function test_moduleInterfaceId() public {
        (, EditionMaxMinterV2_1 minter) = _createEditionAndMinter(type(uint32).max);

        assertTrue(type(IEditionMaxMinterV2_1).interfaceId == minter.moduleInterfaceId());
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

        EditionMaxMinterV2_1 minter = new EditionMaxMinterV2_1();

        affiliateFeeBPS = uint16(affiliateFeeBPS % minter.MAX_AFFILIATE_FEE_BPS());

        uint32 quantity = 4;

        if (maxMintablePerAccount < quantity) maxMintablePerAccount = quantity;
        if (editionMaxMintableLower < quantity) editionMaxMintableLower = quantity;
        if (editionMaxMintableUpper < quantity) editionMaxMintableUpper = quantity;

        SoundEditionV1_2 edition = SoundEditionV1_2(
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
