// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IERC721AUpgradeable } from "chiru-labs/ERC721A-Upgradeable/IERC721AUpgradeable.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { TestConfig } from "../TestConfig.sol";
import { MockMinter } from "../mocks/MockMinter.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

contract MintControllerBaseTests is TestConfig {
    event MintConfigCreated(
        address indexed edition,
        address indexed creator,
        uint256 mintId,
        uint32 startTime,
        uint32 endTime
    );

    event TimeRangeSet(address indexed edition, uint256 indexed mintId, uint32 startTime, uint32 endTime);

    event MintPausedSet(address indexed edition, uint256 mintId, bool paused);

    event AffiliateFeeSet(address indexed edition, uint256 indexed mintId, uint16 affiliateFeeBPS);

    event AffiliateDiscountSet(address indexed edition, uint256 indexed mintId, uint16 affiliateDiscountBPS);

    MockMinter public minter;

    uint32 constant START_TIME = 0;
    uint32 constant END_TIME = type(uint32).max;

    function setUp() public override {
        super.setUp();

        minter = new MockMinter(feeRegistry);
    }

    function _createEdition(uint32 editionMaxMintable) internal returns (SoundEditionV1 edition) {
        edition = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                editionMaxMintable,
                editionMaxMintable,
                RANDOMNESS_LOCKED_TIMESTAMP
            )
        );

        edition.grantRole(edition.MINTER_ROLE(), address(minter));
    }

    function test_createEditionMintRevertsIfCallerNotEditionOwnerOrAdmin() external {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);
        address attacker = getFundedAccount(1);

        vm.expectRevert(IMinterModule.Unauthorized.selector);
        vm.prank(attacker);
        minter.createEditionMint(address(edition), START_TIME, END_TIME);
    }

    function test_createEditionMintViaOwner() external {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint256 mintId = 0;

        address owner = address(this);

        vm.expectEmit(false, false, false, true);
        emit MintConfigCreated(address(edition), owner, mintId, START_TIME, END_TIME);

        minter.createEditionMint(address(edition), START_TIME, END_TIME);
    }

    function test_createEditionMintViaAdmin() external {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint256 mintId = 0;
        address admin = address(1037037);

        edition.grantRole(edition.ADMIN_ROLE(), admin);

        vm.expectEmit(false, false, false, true);
        emit MintConfigCreated(address(edition), admin, mintId, START_TIME, END_TIME);

        vm.prank(admin);
        minter.createEditionMint(address(edition), START_TIME, END_TIME);
    }

    function test_createEditionMintIncremenetsNextMintId() external {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint256 prevMintId = minter.nextMintId(address(edition));
        minter.createEditionMint(address(edition), START_TIME, END_TIME);
        uint256 currentMintId = minter.nextMintId(address(edition));
        assertEq(currentMintId, prevMintId + 1);

        prevMintId = currentMintId;
        minter.createEditionMint(address(edition), START_TIME, END_TIME);
        currentMintId = minter.nextMintId(address(edition));
        assertEq(currentMintId, prevMintId + 1);
    }

    function test_mintRevertsForWrongEtherValue() public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);

        uint256 price = 1;
        minter.setPrice(price);

        vm.expectRevert(abi.encodeWithSelector(IMinterModule.WrongEtherValue.selector, price * 2 - 1, price * 2));
        minter.mint{ value: price * 2 - 1 }(address(edition), mintId, 2, address(0));

        minter.mint{ value: price * 2 }(address(edition), mintId, 2, address(0));
    }

    function test_mintRevertsWhenPaused() public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);

        minter.setEditionMintPaused(address(edition), mintId, true);

        uint256 price = 1;
        minter.setPrice(price);

        vm.expectRevert(IMinterModule.MintPaused.selector);

        minter.mint{ value: price * 2 }(address(edition), mintId, 2, address(0));

        minter.setEditionMintPaused(address(edition), mintId, false);

        minter.mint{ value: price * 2 }(address(edition), mintId, 2, address(0));
    }

    function test_mintRevertsWithZeroQuantity() public {
        minter.setPrice(0);

        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);

        vm.expectRevert(IERC721AUpgradeable.MintZeroQuantity.selector);

        minter.mint{ value: 0 }(address(edition), mintId, 0, address(0));
    }

    function test_createEditionMintMultipleTimes() external {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        for (uint256 i; i < 3; ++i) {
            uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);
            assertEq(mintId, i);
        }
    }

    function test_cantMintPastEditionMaxMintable() external {
        minter.setPrice(0);

        uint32 maxSupply = 5000;
        SoundEditionV1 edition1 = _createEdition(maxSupply);

        uint256 mintId1 = minter.createEditionMint(address(edition1), START_TIME, END_TIME);

        // Mint all of the supply except for 1 token
        minter.mint(address(edition1), mintId1, maxSupply - 1, address(0));

        // try minting 2 more - should fail and tell us there is only 1 available
        vm.expectRevert(abi.encodeWithSelector(ISoundEditionV1.ExceedsEditionAvailableSupply.selector, 1));
        minter.mint(address(edition1), mintId1, 2, address(0));

        // try minting 1 more - should succeed
        minter.mint(address(edition1), mintId1, 1, address(0));
    }

    function test_setTimeRange(address nonController) public {
        vm.assume(nonController != address(this));

        SoundEditionV1 edition = _createEdition(1);

        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);

        MockMinter.BaseData memory baseData = minter.baseMintData(address(edition), mintId);

        // Check initial values are correct
        assertEq(baseData.startTime, 0);
        assertEq(baseData.endTime, type(uint32).max);

        // Set new values
        vm.expectEmit(true, true, true, true);
        emit TimeRangeSet(address(edition), mintId, 123, 456);
        minter.setTimeRange(address(edition), mintId, 123, 456);

        baseData = minter.baseMintData(address(edition), mintId);

        // Check new values
        assertEq(baseData.startTime, 123);
        assertEq(baseData.endTime, 456);

        // Ensure only controller can set time range
        vm.prank(nonController);
        vm.expectRevert(IMinterModule.Unauthorized.selector);
        minter.setTimeRange(address(edition), mintId, 456, 789);
    }

    function test_isAffilatedReturnsFalseForZeroAddress() public {
        assertEq(minter.isAffiliated(address(0), 0, address(0)), false);
        assertEq(minter.isAffiliated(address(0), 0, address(1)), true);
    }

    function test_mintAndWithdrawlWithAffiliateAndPlatformFee() public {
        test_mintAndWithdrawlWithAffiliateAndPlatformFee(true, 1, 10, 10, 10, 1 ether, 2);
        test_mintAndWithdrawlWithAffiliateAndPlatformFee(false, 2, 10, 10, 10, 1 ether, 2);
    }

    function test_setAffiliateFee() public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);
        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);
        _test_setAffiliateFee(edition, mintId, 10);
    }

    function test_setAffiliateDiscount() public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);
        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);
        _test_setAffiliateDiscount(edition, mintId, 10);
    }

    function test_withdrawAffiliateFeesAccrued() public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);
        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);

        minter.setPrice(1 ether);
        feeRegistry.setPlatformFeeBPS(0);

        uint16 affiliateFeeBPS = 11;
        _test_setAffiliateFee(edition, mintId, affiliateFeeBPS);

        uint32 quantity = 1;
        uint256 requiredEtherValue = minter.totalPrice(address(edition), mintId, address(this), 1, true);

        address affiliate = getFundedAccount(123456789);

        minter.mint{ value: requiredEtherValue }(address(edition), mintId, quantity, affiliate);

        uint256 expectedAffiliateFees = ((requiredEtherValue - 0) * affiliateFeeBPS) / minter.MAX_BPS();

        _test_withdrawAffiliateFeesAccrued(affiliate, expectedAffiliateFees);
    }

    function test_withdrawPlatformFeesAccrued() public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);
        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);

        minter.setPrice(1 ether);

        uint16 platformFeeBPS = 16;
        feeRegistry.setPlatformFeeBPS(platformFeeBPS);

        uint32 quantity = 1;
        uint256 requiredEtherValue = minter.totalPrice(address(edition), mintId, address(this), 1, true);

        address affiliate = getFundedAccount(123456789);

        minter.mint{ value: requiredEtherValue }(address(edition), mintId, quantity, affiliate);

        uint256 expectedPlatformFees = ((requiredEtherValue - 0) * platformFeeBPS) / minter.MAX_BPS();

        _test_withdrawPlatformFeesAccrued(expectedPlatformFees);
    }

    function test_mintAndWithdrawlWithAffiliateAndPlatformFee(
        bool affiliateIsZeroAddress,
        uint256 affiliateSeed,
        uint16 affiliateDiscountBPS,
        uint16 affiliateFeeBPS,
        uint16 platformFeeBPS,
        uint256 price,
        uint32 quantity
    ) public {
        price = price % 1e19;
        quantity = 1 + (quantity % 8);

        minter.setPrice(price);

        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        address affiliate = affiliateIsZeroAddress
            ? address(0)
            : getFundedAccount(uint256(keccak256(abi.encode(affiliateSeed))));

        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);

        if (platformFeeBPS > MAX_BPS) return;
        feeRegistry.setPlatformFeeBPS(platformFeeBPS);
        if (!_test_setAffiliateFee(edition, mintId, affiliateFeeBPS)) return;
        if (!_test_setAffiliateDiscount(edition, mintId, affiliateDiscountBPS)) return;

        uint256 expectedPlatformFees;
        uint256 expectedAffiliateFees;

        bool affiliated = minter.isAffiliated(address(edition), mintId, affiliate);
        uint256 requiredEtherValue = minter.totalPrice(address(edition), mintId, address(this), quantity, affiliated);

        expectedPlatformFees = (requiredEtherValue * platformFeeBPS) / minter.MAX_BPS();

        if (affiliated) {
            expectedAffiliateFees = ((requiredEtherValue - expectedPlatformFees) * affiliateFeeBPS) / minter.MAX_BPS();
        }

        minter.mint{ value: requiredEtherValue }(address(edition), mintId, quantity, affiliate);

        if (expectedAffiliateFees != 0) {
            _test_withdrawAffiliateFeesAccrued(affiliate, expectedAffiliateFees);
        }
        _test_withdrawPlatformFeesAccrued(expectedPlatformFees);
    }

    function _test_withdrawAffiliateFeesAccrued(address affiliate, uint256 expectedDifference) internal {
        assertEq(minter.affiliateFeesAccrued(affiliate), expectedDifference);

        uint256 balanceBefore = affiliate.balance;
        minter.withdrawForAffiliate(affiliate);
        uint256 balanceAfter = affiliate.balance;
        assertEq(expectedDifference, balanceAfter - balanceBefore);

        // Ensure that a repeated withdrawal doesn't cause a double refund.
        minter.withdrawForAffiliate(affiliate);
        uint256 balanceAfter2 = affiliate.balance;
        assertEq(balanceAfter2, balanceAfter);

        assertEq(minter.affiliateFeesAccrued(affiliate), 0);
    }

    function _test_withdrawPlatformFeesAccrued(uint256 expectedDifference) internal {
        assertEq(minter.platformFeesAccrued(), expectedDifference);

        uint256 balanceBefore = SOUND_FEE_ADDRESS.balance;
        minter.withdrawForPlatform();
        uint256 balanceAfter = SOUND_FEE_ADDRESS.balance;
        assertEq(expectedDifference, balanceAfter - balanceBefore);

        // Ensure that a repeated withdrawal doesn't cause a double refund.
        minter.withdrawForPlatform();
        uint256 balanceAfter2 = SOUND_FEE_ADDRESS.balance;
        assertEq(balanceAfter2, balanceAfter);

        assertEq(minter.platformFeesAccrued(), 0);
    }

    function _test_setAffiliateFee(
        SoundEditionV1 edition,
        uint256 mintId,
        uint16 affiliateFeeBPS
    ) internal returns (bool) {
        if (affiliateFeeBPS > minter.MAX_BPS()) {
            vm.expectRevert(IMinterModule.InvalidAffiliateFeeBPS.selector);
            minter.setAffiliateFee(address(edition), mintId, affiliateFeeBPS);
            return false;
        }
        vm.expectEmit(true, true, true, true);
        emit AffiliateFeeSet(address(edition), mintId, affiliateFeeBPS);
        minter.setAffiliateFee(address(edition), mintId, affiliateFeeBPS);
        assertEq(minter.baseMintData(address(edition), mintId).affiliateFeeBPS, affiliateFeeBPS);
        return true;
    }

    function _test_setAffiliateDiscount(
        SoundEditionV1 edition,
        uint256 mintId,
        uint16 affiliateDiscountBPS
    ) internal returns (bool) {
        if (affiliateDiscountBPS > minter.MAX_BPS()) {
            vm.expectRevert(IMinterModule.InvalidAffiliateDiscountBPS.selector);
            minter.setAffiliateDiscount(address(edition), mintId, affiliateDiscountBPS);
            return false;
        }
        vm.expectEmit(true, true, true, true);
        emit AffiliateDiscountSet(address(edition), mintId, affiliateDiscountBPS);
        minter.setAffiliateDiscount(address(edition), mintId, affiliateDiscountBPS);
        assertEq(minter.baseMintData(address(edition), mintId).affiliateDiscountBPS, affiliateDiscountBPS);
        return true;
    }
}
