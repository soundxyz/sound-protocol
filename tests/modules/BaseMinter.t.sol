// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IERC721AUpgradeable } from "chiru-labs/ERC721A-Upgradeable/IERC721AUpgradeable.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { TestConfig } from "../TestConfig.sol";
import { MockMinter } from "../mocks/MockMinter.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";

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

    event PlatformFeeSet(uint16 platformFeeBPS);

    MockMinter public minter;

    uint32 constant START_TIME = 0;
    uint32 constant END_TIME = type(uint32).max;

    constructor() {
        minter = new MockMinter();
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
        minter.mint{ value: price * 2 - 1 }(address(edition), mintId, 2);

        minter.mint{ value: price * 2 }(address(edition), mintId, 2);
    }

    function test_mintRevertsWhenPaused() public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);

        minter.setEditionMintPaused(address(edition), mintId, true);

        uint256 price = 1;
        minter.setPrice(price);

        vm.expectRevert(IMinterModule.MintPaused.selector);

        minter.mint{ value: price * 2 }(address(edition), mintId, 2);

        minter.setEditionMintPaused(address(edition), mintId, false);

        minter.mint{ value: price * 2 }(address(edition), mintId, 2);
    }

    function test_mintRevertsWithZeroQuantity() public {
        minter.setPrice(0);

        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);

        vm.expectRevert(IERC721AUpgradeable.MintZeroQuantity.selector);

        minter.mint{ value: 0 }(address(edition), mintId, 0);
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
        minter.mint(address(edition1), mintId1, maxSupply - 1);

        // try minting 2 more - should fail and tell us there is only 1 available
        vm.expectRevert(abi.encodeWithSelector(ISoundEditionV1.ExceedsEditionAvailableSupply.selector, 1));
        minter.mint(address(edition1), mintId1, 2);

        // try minting 1 more - should succeed
        minter.mint(address(edition1), mintId1, 1);
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

    function test_isAffilatedReturnsFalseForZeroAddress(
        address edition,
        uint256 mintId,
        address affiliate
    ) public {
        vm.assume(affiliate != address(0));
        assertEq(minter.isAffiliated(edition, mintId, address(0)), false);
        assertEq(minter.isAffiliated(edition, mintId, affiliate), true);
    }

    function test_isAffilatedReturnsFalseForZeroAddress() public {
        test_isAffilatedReturnsFalseForZeroAddress(address(0), 0, address(1));
    }

    function test_mintAndWithdrawlWithAffiliateAndPlatformFee() public {
        bool affiliateIsZeroAddress = true;
        uint256 affiliateSeed = 1;
        uint16 affiliateDiscountBPS = 10;
        uint16 affiliateFeeBPS = 10;
        uint16 platformFeeBPS = 10;
        uint256 price = 1 ether;
        uint32 quantity = 2;

        test_mintAndWithdrawlWithAffiliateAndPlatformFee(
            affiliateIsZeroAddress,
            affiliateSeed,
            affiliateDiscountBPS,
            affiliateFeeBPS,
            platformFeeBPS,
            price,
            quantity
        );

        affiliateIsZeroAddress = false;
        affiliateSeed = 2;

        test_mintAndWithdrawlWithAffiliateAndPlatformFee(
            affiliateIsZeroAddress,
            affiliateSeed,
            affiliateDiscountBPS,
            affiliateFeeBPS,
            platformFeeBPS,
            price,
            quantity
        );
    }

    function test_setPlatformFee() public {
        uint16 platformFeeBPS = 0;
        _test_setPlatformFee(platformFeeBPS);
        platformFeeBPS = 10;
        _test_setPlatformFee(platformFeeBPS);
        platformFeeBPS = minter.MAX_BPS();
        _test_setPlatformFee(platformFeeBPS);
        platformFeeBPS = minter.MAX_BPS() + 1;
        _test_setPlatformFee(platformFeeBPS);
    }

    function test_setAffiliateFee() public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);
        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);
        uint16 affiliateFeeBPS = 10;
        _test_setAffiliateFee(edition, mintId, affiliateFeeBPS);
    }

    function test_setAffiliateDiscount() public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);
        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);
        uint16 affiliateDiscountBPS = 10;
        _test_setAffiliateDiscount(edition, mintId, affiliateDiscountBPS);
    }

    function test_withdrawAffiliateFeesAccrued(uint16 affiliateFeeBPS, uint16 affiliateDiscountBPS) public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);
        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);

        uint256 price = 1 ether;
        minter.setPrice(price);

        affiliateFeeBPS = affiliateFeeBPS % minter.MAX_BPS();
        _test_setAffiliateFee(edition, mintId, affiliateFeeBPS);

        uint32 quantity = 1;
        uint256 total = quantity * price;
        uint256 requiredEtherValue = total - ((total * affiliateDiscountBPS) / minter.MAX_BPS());

        address affiliate = getFundedAccount(123456789);

        minter.mint{ value: requiredEtherValue }(address(edition), mintId, quantity, affiliate);

        uint256 expectedAffiliateFees = (requiredEtherValue * affiliateFeeBPS) / minter.MAX_BPS();

        _test_withdrawAffiliateFeesAccrued(affiliate, expectedAffiliateFees);
    }

    function test_withdrawAffiliateFeesAccrued() public {
        uint16 affiliateFeeBPS = 10;
        uint16 affiliateDiscountBPS = 10;
        test_withdrawAffiliateFeesAccrued(affiliateFeeBPS, affiliateDiscountBPS);
    }

    function test_withdrawPlatformFeesAccrued(uint16 platformFeeBPS, uint16 affiliateDiscountBPS) public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);
        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);

        uint256 price = 1 ether;
        minter.setPrice(price);

        platformFeeBPS = platformFeeBPS % minter.MAX_BPS();
        _test_setPlatformFee(platformFeeBPS);

        uint32 quantity = 1;
        uint256 total = quantity * price;
        uint256 requiredEtherValue = total - ((total * affiliateDiscountBPS) / minter.MAX_BPS());

        address affiliate = getFundedAccount(123456789);

        minter.mint{ value: requiredEtherValue }(address(edition), mintId, quantity, affiliate);

        uint256 expectedPlatformFees = (requiredEtherValue * platformFeeBPS) / minter.MAX_BPS();

        _test_withdrawPlatformFeesAccrued(expectedPlatformFees);
    }

    function test_withdrawPlatformFeesAccrued() public {
        uint16 platformFeeBPS = 10;
        uint16 affiliateDiscountBPS = 10;

        test_withdrawPlatformFeesAccrued(platformFeeBPS, affiliateDiscountBPS);
    }

    // This is an integration test to ensure that all the functions work together properly.
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

        // Set the various BPS, and if any reverts, return.
        if (!_test_setPlatformFee(platformFeeBPS)) return;
        if (!_test_setAffiliateFee(edition, mintId, affiliateFeeBPS)) return;
        if (!_test_setAffiliateDiscount(edition, mintId, affiliateDiscountBPS)) return;

        uint256 expectedPlatformFees;
        uint256 expectedAffiliateFees;

        bool affiliated = minter.isAffiliated(address(edition), mintId, affiliate);
        uint256 total = quantity * price;
        uint256 requiredEtherValue = affiliated ? total : total - ((total * affiliateDiscountBPS) / minter.MAX_BPS());

        expectedPlatformFees = (requiredEtherValue * platformFeeBPS) / minter.MAX_BPS();

        if (affiliated) {
            // The affiliate fees are deducted after the platform fees.
            expectedAffiliateFees = ((requiredEtherValue - expectedPlatformFees) * affiliateFeeBPS) / minter.MAX_BPS();
            minter.mint{ value: requiredEtherValue }(address(edition), mintId, quantity, affiliate);
        } else {
            minter.mint{ value: requiredEtherValue }(address(edition), mintId, quantity);
        }

        _test_withdrawAffiliateFeesAccrued(affiliate, expectedAffiliateFees);
        _test_withdrawPlatformFeesAccrued(expectedPlatformFees);
    }

    // Test helper for withdrawing the affiliate fees and testing the expected effects.
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

    // Test helper for withdrawing the platform fees and testing the expected effects.
    function _test_withdrawPlatformFeesAccrued(uint256 expectedDifference) internal {
        assertEq(minter.platformFeesAccrued(), expectedDifference);

        uint256 balanceBefore = address(1).balance;
        minter.withdrawForPlatform(address(1));
        uint256 balanceAfter = address(1).balance;
        assertEq(expectedDifference, balanceAfter - balanceBefore);

        // Ensure that a repeated withdrawal doesn't cause a double refund.
        minter.withdrawForPlatform(address(1));
        uint256 balanceAfter2 = address(1).balance;
        assertEq(balanceAfter2, balanceAfter);

        assertEq(minter.platformFeesAccrued(), 0);
    }

    // Test helper for `platformFeeBPS` and testing the expected effects.
    // Returns whether setting the value is successful.
    function _test_setPlatformFee(uint16 platformFeeBPS) internal returns (bool) {
        if (platformFeeBPS > minter.MAX_BPS()) {
            vm.expectRevert(IMinterModule.InvalidPlatformFeeBPS.selector);
            minter.setPlatformFee(platformFeeBPS);
            return false;
        }
        vm.expectEmit(true, true, true, true);
        emit PlatformFeeSet(platformFeeBPS);
        minter.setPlatformFee(platformFeeBPS);
        assertEq(minter.platformFeeBPS(), platformFeeBPS);
        return true;
    }

    // Test helper for setting `affiliateFeeBPS` and testing the expected effects.
    // Returns whether setting the value is successful.
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

    // Test helper for setting `affiliateDiscountBPS` and testing the expected effects.
    // Returns whether setting the value is successful.
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

    function test_supportsInterface() external {
        assertTrue(minter.supportsInterface(type(IMinterModule).interfaceId));
        assertTrue(minter.supportsInterface(type(IERC165).interfaceId));
        assertFalse(minter.supportsInterface(bytes4(0)));
    }
}
