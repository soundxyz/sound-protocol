// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IERC721AUpgradeable } from "chiru-labs/ERC721A-Upgradeable/IERC721AUpgradeable.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { TestConfig } from "../TestConfig.sol";
import { MockMinter, MintInfo } from "../mocks/MockMinter.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";

contract MintControllerBaseTests is TestConfig {
    event MintConfigCreated(
        address indexed edition,
        address indexed creator,
        uint128 mintId,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS
    );

    event TimeRangeSet(address indexed edition, uint128 indexed mintId, uint32 startTime, uint32 endTime);

    event MintPausedSet(address indexed edition, uint128 mintId, bool paused);

    event AffiliateFeeSet(address indexed edition, uint128 indexed mintId, uint16 affiliateFeeBPS);

    event Minted(
        address indexed edition,
        uint128 indexed mintId,
        address indexed buyer,
        uint32 fromTokenId,
        uint32 quantity,
        uint128 requiredEtherValue,
        uint128 platformFee,
        uint128 affiliateFee,
        address affiliate,
        bool affiliated
    );

    MockMinter public minter;

    uint32 constant START_TIME = 0;
    uint32 constant END_TIME = type(uint32).max;
    uint16 constant AFFILIATE_FEE_BPS = 0;

    function setUp() public override {
        super.setUp();

        minter = new MockMinter(feeRegistry);
    }

    function _createEdition(uint32 editionMaxMintable) internal returns (SoundEditionV1 edition) {
        edition = SoundEditionV1(
            createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                editionMaxMintable,
                editionMaxMintable,
                EDITION_CUTOFF_TIME,
                FLAGS
            )
        );

        edition.grantRoles(address(minter), edition.MINTER_ROLE());
    }

    function test_createEditionMintRevertsIfCallerNotEditionOwnerOrAdmin() external {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);
        address attacker = getFundedAccount(1);

        vm.expectRevert(IMinterModule.Unauthorized.selector);
        vm.prank(attacker);
        minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);
    }

    function test_createEditionMintRevertsIfAffiliateFeeBPSTooHigh() external {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);
        uint16 affiliateFeeBPS = minter.MAX_BPS() + 1;

        vm.expectRevert(IMinterModule.InvalidAffiliateFeeBPS.selector);
        minter.createEditionMint(address(edition), START_TIME, END_TIME, affiliateFeeBPS);
    }

    function test_createEditionMintViaOwner() external {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint128 mintId = 0;

        address owner = address(this);

        vm.expectEmit(false, false, false, true);
        emit MintConfigCreated(address(edition), owner, mintId, START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);
    }

    function test_createEditionMintViaAdmin() external {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint128 mintId = 0;
        address admin = address(1037037);

        edition.grantRoles(admin, edition.ADMIN_ROLE());

        vm.expectEmit(false, false, false, true);
        emit MintConfigCreated(address(edition), admin, mintId, START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        vm.prank(admin);
        minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);
    }

    function test_createEditionMintIncremenetsNextMintId() external {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint256 prevMintId = minter.nextMintId();
        minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);
        uint256 currentMintId = minter.nextMintId();
        assertEq(currentMintId, prevMintId + 1);

        prevMintId = currentMintId;
        minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);
        currentMintId = minter.nextMintId();
        assertEq(currentMintId, prevMintId + 1);
    }

    function test_mintRevertsForUnderpaid() public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        uint96 price = 1;
        minter.setPrice(price);

        vm.expectRevert(abi.encodeWithSelector(IMinterModule.Underpaid.selector, price * 2 - 1, price * 2));
        minter.mint{ value: price * 2 - 1 }(address(edition), mintId, 2, address(0));

        minter.mint{ value: price * 2 }(address(edition), mintId, 2, address(0));
    }

    function test_mintRefundsForOverpaid() public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        uint96 price = 1;
        minter.setPrice(price);

        uint32 quantity = 2;

        address buyer = getFundedAccount(123456789);

        uint256 balanceBefore = buyer.balance;

        vm.prank(buyer);
        minter.mint{ value: price * (quantity + 1) }(address(edition), mintId, quantity, address(0));

        uint256 balanceAfter = buyer.balance;

        assertEq(balanceBefore - balanceAfter, price * quantity);
    }

    function test_mintAcceptsExactPayment() public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        uint96 price = 1;
        minter.setPrice(price);

        uint32 quantity = 2;

        address buyer = getFundedAccount(123456789);

        uint256 balanceBefore = buyer.balance;

        vm.prank(buyer);
        minter.mint{ value: price * quantity }(address(edition), mintId, quantity, address(0));

        uint256 balanceAfter = buyer.balance;

        assertEq(balanceBefore - balanceAfter, price * quantity);
    }

    function test_mintRevertsWhenPaused() public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        minter.setEditionMintPaused(address(edition), mintId, true);

        uint96 price = 1;
        minter.setPrice(price);

        vm.expectRevert(IMinterModule.MintPaused.selector);

        minter.mint{ value: price * 2 }(address(edition), mintId, 2, address(0));

        minter.setEditionMintPaused(address(edition), mintId, false);

        minter.mint{ value: price * 2 }(address(edition), mintId, 2, address(0));
    }

    function test_mintRevertsWithZeroQuantity() public {
        minter.setPrice(0);

        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        vm.expectRevert(IERC721AUpgradeable.MintZeroQuantity.selector);

        minter.mint{ value: 0 }(address(edition), mintId, 0, address(0));
    }

    function test_createEditionMintMultipleTimes() external {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        for (uint256 i; i < 3; ++i) {
            uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);
            assertEq(mintId, i);
        }
    }

    function test_cantMintPastEditionMaxMintable() external {
        minter.setPrice(0);

        uint32 maxSupply = 50;
        SoundEditionV1 edition1 = _createEdition(maxSupply);

        uint128 mintId1 = minter.createEditionMint(address(edition1), START_TIME, END_TIME, AFFILIATE_FEE_BPS);

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

        uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        MintInfo memory mintInfo = minter.mintInfo(address(edition), mintId);

        // Check initial values are correct
        assertEq(mintInfo.startTime, 0);
        assertEq(mintInfo.endTime, type(uint32).max);

        // Set new values
        vm.expectEmit(true, true, true, true);
        emit TimeRangeSet(address(edition), mintId, 123, 456);
        minter.setTimeRange(address(edition), mintId, 123, 456);

        mintInfo = minter.mintInfo(address(edition), mintId);

        // Check new values
        assertEq(mintInfo.startTime, 123);
        assertEq(mintInfo.endTime, 456);

        // Ensure only controller can set time range
        vm.prank(nonController);
        vm.expectRevert(IMinterModule.Unauthorized.selector);
        minter.setTimeRange(address(edition), mintId, 456, 789);
    }

    function test_isAffilatedReturnsFalseForZeroAddress(
        address edition,
        uint128 mintId,
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
        uint16 affiliateFeeBPS = 10;
        uint16 platformFeeBPS = 10;
        uint96 price = 1 ether;
        uint32 quantity = 2;

        test_mintAndWithdrawlWithAffiliateAndPlatformFee(
            affiliateIsZeroAddress,
            affiliateSeed,
            affiliateFeeBPS,
            platformFeeBPS,
            price,
            quantity,
            address(this)
        );

        affiliateIsZeroAddress = false;
        affiliateSeed = 2;

        test_mintAndWithdrawlWithAffiliateAndPlatformFee(
            affiliateIsZeroAddress,
            affiliateSeed,
            affiliateFeeBPS,
            platformFeeBPS,
            price,
            quantity,
            address(this)
        );
    }

    function test_setAffiliateFee() public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);
        uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);
        uint16 affiliateFeeBPS = 10;
        _test_setAffiliateFee(edition, mintId, affiliateFeeBPS);
    }

    function test_withdrawAffiliateFeesAccrued(uint16 affiliateFeeBPS) public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);
        uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        uint96 price = 1 ether;
        minter.setPrice(price);
        feeRegistry.setPlatformFeeBPS(0);

        affiliateFeeBPS = affiliateFeeBPS % minter.MAX_BPS();
        _test_setAffiliateFee(edition, mintId, affiliateFeeBPS);

        uint32 quantity = 1;
        uint256 requiredEtherValue = minter.totalPrice(address(edition), mintId, address(this), quantity);

        address affiliate = getFundedAccount(123456789);

        minter.mint{ value: requiredEtherValue }(address(edition), mintId, quantity, affiliate);

        uint256 expectedAffiliateFees = (requiredEtherValue * affiliateFeeBPS) / minter.MAX_BPS();

        _test_withdrawAffiliateFeesAccrued(affiliate, expectedAffiliateFees);
    }

    function test_withdrawAffiliateFeesAccrued() public {
        uint16 affiliateFeeBPS = 10;
        test_withdrawAffiliateFeesAccrued(affiliateFeeBPS);
    }

    function test_withdrawPlatformFeesAccrued(uint16 platformFeeBPS) public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);
        uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        uint96 price = 1 ether;
        minter.setPrice(price);

        platformFeeBPS = platformFeeBPS % minter.MAX_BPS();
        feeRegistry.setPlatformFeeBPS(platformFeeBPS);

        uint32 quantity = 1;
        uint256 requiredEtherValue = minter.totalPrice(address(edition), mintId, address(this), quantity);

        address affiliate = getFundedAccount(123456789);

        minter.mint{ value: requiredEtherValue }(address(edition), mintId, quantity, affiliate);

        uint256 expectedPlatformFees = (requiredEtherValue * platformFeeBPS) / minter.MAX_BPS();

        _test_withdrawPlatformFeesAccrued(expectedPlatformFees);
    }

    function test_withdrawPlatformFeesAccrued() public {
        uint16 platformFeeBPS = 10;
        test_withdrawPlatformFeesAccrued(platformFeeBPS);
    }

    // This is an integration test to ensure that all the functions work together properly.
    function test_mintAndWithdrawlWithAffiliateAndPlatformFee(
        bool affiliateIsZeroAddress,
        uint256 affiliateSeed,
        uint16 affiliateFeeBPS,
        uint16 platformFeeBPS,
        uint96 price,
        uint32 quantity,
        address buyer
    ) public {
        vm.assume(buyer != address(0));
        price = price % 1e19;
        quantity = 1 + (quantity % 8);

        minter.setPrice(price);

        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        address affiliate = affiliateIsZeroAddress
            ? address(0)
            : getFundedAccount(uint256(keccak256(abi.encode(affiliateSeed))));

        uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        if (platformFeeBPS > MAX_BPS) return;
        feeRegistry.setPlatformFeeBPS(platformFeeBPS);
        if (!_test_setAffiliateFee(edition, mintId, affiliateFeeBPS)) return;

        uint256 expectedPlatformFees;
        uint256 expectedAffiliateFees;

        uint256 requiredEtherValue = minter.totalPrice(address(edition), mintId, address(this), quantity);

        expectedPlatformFees = (requiredEtherValue * platformFeeBPS) / minter.MAX_BPS();

        bool affiliated = minter.isAffiliated(address(edition), mintId, affiliate);
        if (affiliated) {
            // The affiliate fees are deducted after the platform fees.
            expectedAffiliateFees = ((requiredEtherValue - expectedPlatformFees) * affiliateFeeBPS) / minter.MAX_BPS();
        }
        // Expect an event.
        uint32 fromTokenId = uint32(edition.nextTokenId());
        vm.expectEmit(true, true, true, true);
        emit Minted(
            address(edition),
            mintId,
            buyer,
            fromTokenId,
            quantity,
            uint128(requiredEtherValue),
            uint128(expectedPlatformFees),
            uint128(expectedAffiliateFees),
            affiliate,
            affiliated
        );

        vm.deal(buyer, requiredEtherValue);
        vm.prank(buyer);
        minter.mint{ value: requiredEtherValue }(address(edition), mintId, quantity, affiliate);

        _test_withdrawAffiliateFeesAccrued(affiliate, expectedAffiliateFees);
        _test_withdrawPlatformFeesAccrued(expectedPlatformFees);
    }

    function test_revertsIfFeeRegistryIsZero() external {
        vm.expectRevert(IMinterModule.FeeRegistryIsZeroAddress.selector);
        new MockMinter(ISoundFeeRegistry(address(0)));
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
        uint128 mintId,
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
        assertEq(minter.mintInfo(address(edition), mintId).affiliateFeeBPS, affiliateFeeBPS);
        return true;
    }

    function test_supportsInterface() external {
        assertTrue(minter.supportsInterface(type(IMinterModule).interfaceId));
        assertTrue(minter.supportsInterface(type(IERC165).interfaceId));
        assertFalse(minter.supportsInterface(bytes4(0)));
    }
}
