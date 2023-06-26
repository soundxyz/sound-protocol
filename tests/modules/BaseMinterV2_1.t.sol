// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IERC721AUpgradeable } from "chiru-labs/ERC721A-Upgradeable/IERC721AUpgradeable.sol";
import { SoundEditionV1_2 } from "@core/SoundEditionV1_2.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { TestConfig } from "../TestConfig.sol";
import { MockMinterV2_1, MintInfo } from "../mocks/MockMinterV2_1.sol";
import { ISoundEditionV1_2 } from "@core/interfaces/ISoundEditionV1_2.sol";
import { IMinterModuleV2 } from "@core/interfaces/IMinterModuleV2.sol";
import { IMinterModuleV2_1 } from "@core/interfaces/IMinterModuleV2_1.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { Merkle } from "murky/Merkle.sol";

contract MintControllerBaseV2Tests is TestConfig {
    event MintConfigCreated(
        address indexed edition,
        address indexed creator,
        uint128 mintId,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS
    );

    event TimeRangeSet(address indexed edition, uint128 mintId, uint32 startTime, uint32 endTime);

    event MintPausedSet(address indexed edition, uint128 mintId, bool paused);

    event AffiliateFeeSet(address indexed edition, uint128 mintId, uint16 affiliateFeeBPS);

    event PlatformFeeSet(uint16 bps);

    event PlatformFlatFeeSet(uint96 flatFee);

    event PlatformPerTxFlatFeeSet(uint96 perTxFlatFee);

    event PlatformFeeAddressSet(address addr);

    event Minted(
        address indexed edition,
        uint128 mintId,
        address indexed buyer,
        uint32 fromTokenId,
        uint32 quantity,
        uint128 requiredEtherValue,
        uint128 platformFee,
        uint128 affiliateFee,
        address affiliate,
        bool affiliated,
        uint256 indexed attributionId
    );

    MockMinterV2_1 public minter;

    uint32 constant START_TIME = 0;
    uint32 constant END_TIME = type(uint32).max;
    uint16 constant AFFILIATE_FEE_BPS = 0;

    function setUp() public override {
        super.setUp();

        minter = new MockMinterV2_1();
    }

    function _createEdition(uint32 editionMaxMintable) internal returns (SoundEditionV1_2 edition) {
        edition = SoundEditionV1_2(
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
        SoundEditionV1_2 edition = _createEdition(EDITION_MAX_MINTABLE);
        address attacker = getFundedAccount(1);

        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(attacker);
        minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);
    }

    function test_createEditionMintRevertsIfAffiliateFeeBPSTooHigh() external {
        SoundEditionV1_2 edition = _createEdition(EDITION_MAX_MINTABLE);
        uint16 affiliateFeeBPS = minter.MAX_AFFILIATE_FEE_BPS() + 1;

        vm.expectRevert(IMinterModuleV2_1.InvalidAffiliateFeeBPS.selector);
        minter.createEditionMint(address(edition), START_TIME, END_TIME, affiliateFeeBPS);
    }

    function test_createEditionMintViaOwner() external {
        SoundEditionV1_2 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint128 mintId = 0;

        address owner = address(this);

        vm.expectEmit(false, false, false, true);
        emit MintConfigCreated(address(edition), owner, mintId, START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);
    }

    function test_createEditionMintViaAdmin() external {
        SoundEditionV1_2 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint128 mintId = 0;
        address admin = address(1037037);

        edition.grantRoles(admin, edition.ADMIN_ROLE());

        vm.expectEmit(false, false, false, true);
        emit MintConfigCreated(address(edition), admin, mintId, START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        vm.prank(admin);
        minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);
    }

    function test_createEditionMintIncremenetsNextMintId() external {
        SoundEditionV1_2 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint256 prevMintId = minter.nextMintId();
        minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);
        uint256 currentMintId = minter.nextMintId();
        assertEq(currentMintId, prevMintId + 1);

        prevMintId = currentMintId;
        minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);
        currentMintId = minter.nextMintId();
        assertEq(currentMintId, prevMintId + 1);
    }

    function test_mintRevertsForWrongPayment() public {
        SoundEditionV1_2 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        uint96 price = 1;
        minter.setPrice(price);

        vm.expectRevert(abi.encodeWithSelector(IMinterModuleV2_1.WrongPayment.selector, price * 2 - 1, price * 2));
        minter.mint{ value: price * 2 - 1 }(address(edition), mintId, 2, address(0));

        vm.expectRevert(abi.encodeWithSelector(IMinterModuleV2_1.WrongPayment.selector, price * 2 + 1, price * 2));
        minter.mint{ value: price * 2 + 1 }(address(edition), mintId, 2, address(0));

        minter.mint{ value: price * 2 }(address(edition), mintId, 2, address(0));
    }

    function test_mintAcceptsExactPayment() public {
        SoundEditionV1_2 edition = _createEdition(EDITION_MAX_MINTABLE);

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
        SoundEditionV1_2 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        minter.setEditionMintPaused(address(edition), mintId, true);

        uint96 price = 1;
        minter.setPrice(price);

        vm.expectRevert(IMinterModuleV2_1.MintPaused.selector);

        minter.mint{ value: price * 2 }(address(edition), mintId, 2, address(0));

        minter.setEditionMintPaused(address(edition), mintId, false);

        minter.mint{ value: price * 2 }(address(edition), mintId, 2, address(0));
    }

    function test_mintRevertsWithZeroQuantity() public {
        minter.setPrice(0);

        SoundEditionV1_2 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        vm.expectRevert(IERC721AUpgradeable.MintZeroQuantity.selector);

        minter.mint{ value: 0 }(address(edition), mintId, 0, address(0));
    }

    function test_createEditionMintMultipleTimes() external {
        SoundEditionV1_2 edition = _createEdition(EDITION_MAX_MINTABLE);

        for (uint256 i; i < 3; ++i) {
            uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);
            assertEq(mintId, i);
        }
    }

    function test_cantMintPastEditionMaxMintable() external {
        minter.setPrice(0);

        uint32 maxSupply = 50;
        SoundEditionV1_2 edition1 = _createEdition(maxSupply);

        uint128 mintId1 = minter.createEditionMint(address(edition1), START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        // Mint all of the supply except for 1 token
        minter.mint(address(edition1), mintId1, maxSupply - 1, address(0));

        // try minting 2 more - should fail and tell us there is only 1 available
        vm.expectRevert(abi.encodeWithSelector(ISoundEditionV1_2.ExceedsEditionAvailableSupply.selector, 1));
        minter.mint(address(edition1), mintId1, 2, address(0));

        // try minting 1 more - should succeed
        minter.mint(address(edition1), mintId1, 1, address(0));
    }

    function test_setTimeRange(address nonController) public {
        vm.assume(nonController != address(this));

        SoundEditionV1_2 edition = _createEdition(1);

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
        vm.expectRevert(Ownable.Unauthorized.selector);
        minter.setTimeRange(address(edition), mintId, 456, 789);
    }

    function test_isAffilatedReturnsFalseForZeroAddress() public {
        SoundEditionV1_2 edition = _createEdition(1);
        uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        assertEq(minter.isAffiliated(address(edition), mintId, address(0)), false);
        assertEq(minter.isAffiliated(address(edition), mintId, address(1)), true);
    }

    function test_setAffiliateFee() public {
        SoundEditionV1_2 edition = _createEdition(EDITION_MAX_MINTABLE);
        uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);
        uint16 affiliateFeeBPS = 10;
        _test_setAffiliateFee(edition, mintId, affiliateFeeBPS);
    }

    function test_mintWithWrongAffiliateProofReverts() public {
        SoundEditionV1_2 edition = _createEdition(EDITION_MAX_MINTABLE);
        uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        address affiliate = getFundedAccount(123456789);

        Merkle m = new Merkle();

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encodePacked(affiliate));
        leaves[1] = keccak256(abi.encodePacked(getFundedAccount(987654321)));

        minter.setAffiliateMerkleRoot(address(edition), mintId, m.getRoot(leaves));

        uint32 quantity = 1;
        uint256 requiredEtherValue = minter.totalPrice(address(edition), mintId, address(this), quantity);

        bytes32[] memory affiliateProof = m.getProof(leaves, 1);
        vm.expectRevert(IMinterModuleV2_1.InvalidAffiliate.selector);
        minter.mintTo{ value: requiredEtherValue }(
            address(edition),
            mintId,
            address(this),
            quantity,
            affiliate,
            affiliateProof,
            0
        );

        affiliateProof = m.getProof(leaves, 0);
        minter.mintTo{ value: requiredEtherValue }(
            address(edition),
            mintId,
            address(this),
            quantity,
            affiliate,
            affiliateProof,
            0
        );
    }

    function test_withdrawAffiliateFeesAccrued(uint16 affiliateFeeBPS) public {
        SoundEditionV1_2 edition = _createEdition(EDITION_MAX_MINTABLE);
        uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        uint96 price = 1 ether;
        minter.setPrice(price);
        minter.setPlatformFee(0);
        minter.setPlatformFeeAddress(SOUND_FEE_ADDRESS);

        affiliateFeeBPS = affiliateFeeBPS % minter.MAX_AFFILIATE_FEE_BPS();
        _test_setAffiliateFee(edition, mintId, affiliateFeeBPS);

        uint32 quantity = 1;
        uint256 requiredEtherValue = minter.totalPrice(address(edition), mintId, address(this), quantity);

        address affiliate = getFundedAccount(123456789);

        minter.mint{ value: requiredEtherValue }(address(edition), mintId, quantity, affiliate);

        uint256 expectedAffiliateFees = (requiredEtherValue * affiliateFeeBPS) / minter.BPS_DENOMINATOR();

        _test_withdrawAffiliateFeesAccrued(affiliate, expectedAffiliateFees);
    }

    function test_withdrawAffiliateFeesAccrued() public {
        uint16 affiliateFeeBPS = 10;
        test_withdrawAffiliateFeesAccrued(affiliateFeeBPS);
    }

    function test_withdrawPlatformFeesAccrued(uint256) public {
        SoundEditionV1_2 edition = _createEdition(EDITION_MAX_MINTABLE);
        uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        uint96 price = 1 ether;
        minter.setPrice(price);

        uint16 platformFeeBPS = uint16(_bound(_random(), 0, minter.MAX_PLATFORM_FEE_BPS()));
        minter.setPlatformFee(platformFeeBPS);
        minter.setPlatformFeeAddress(SOUND_FEE_ADDRESS);

        uint32 quantity = 1;
        uint256 requiredEtherValue = minter.totalPrice(address(edition), mintId, address(this), quantity);

        address affiliate = getFundedAccount(123456789);

        minter.mint{ value: requiredEtherValue }(address(edition), mintId, quantity, affiliate);

        uint256 expectedPlatformFees = (requiredEtherValue * platformFeeBPS) / minter.BPS_DENOMINATOR();

        _test_withdrawPlatformFeesAccrued(expectedPlatformFees);
    }

    struct _TestTemps {
        uint256 totalPrice;
        uint256 requiredEtherValue;
        bool affiliated;
        address affiliate;
        address buyer;
        uint256 quantity;
        uint256 price;
        uint256 expectedPlatformFees;
        uint256 expectedAffiliateFees;
        uint256 platformFeeBPS;
        uint256 platformFlatFee;
        uint256 platformPerTxFlatFee;
        uint256 affiliateFeeBPS;
    }

    // This is an integration test to ensure that all the functions work together properly.
    function test_mintAndWithdrawlWithAffiliateAndPlatformFee(uint256) public {
        _TestTemps memory t;

        (t.buyer, ) = _randomSigner();

        t.price = _bound(_random(), 0, type(uint96).max);
        t.quantity = _bound(_random(), 1, 8);

        minter.setPrice(uint96(t.price));

        SoundEditionV1_2 edition = _createEdition(EDITION_MAX_MINTABLE);

        (t.affiliate, ) = _randomSigner();
        if (_random() % 2 == 0) {
            t.affiliate = address(0);
        } else {
            vm.deal(t.affiliate, type(uint192).max);
        }

        uint128 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME, AFFILIATE_FEE_BPS);

        t.platformFeeBPS = _bound(_random(), 0, minter.MAX_PLATFORM_FEE_BPS());
        vm.expectEmit(true, true, true, true);
        emit PlatformFeeSet(uint16(t.platformFeeBPS));
        minter.setPlatformFee(uint16(t.platformFeeBPS));
        vm.expectEmit(true, true, true, true);
        emit PlatformFeeAddressSet(SOUND_FEE_ADDRESS);
        minter.setPlatformFeeAddress(SOUND_FEE_ADDRESS);
        if (_random() % 2 == 0) {
            t.platformFlatFee = _bound(_random(), 1, minter.MAX_PLATFORM_FLAT_FEE());
            vm.expectEmit(true, true, true, true);
            emit PlatformFlatFeeSet(uint96(t.platformFlatFee));
            minter.setPlatformFlatFee(uint96(t.platformFlatFee));
        }
        if (_random() % 2 == 0) {
            t.platformPerTxFlatFee = _bound(_random(), 1, minter.MAX_PLATFORM_PER_TX_FLAT_FEE());
            vm.expectEmit(true, true, true, true);
            emit PlatformPerTxFlatFeeSet(uint96(t.platformPerTxFlatFee));
            minter.setPlatformPerTxFlatFee(uint96(t.platformPerTxFlatFee));
        }

        t.affiliateFeeBPS = _bound(_random(), 0, minter.MAX_AFFILIATE_FEE_BPS() * 2);
        if (!_test_setAffiliateFee(edition, mintId, uint16(t.affiliateFeeBPS))) return;

        t.totalPrice = minter.totalPrice(address(edition), mintId, address(this), uint32(t.quantity));
        t.requiredEtherValue = t.totalPrice;

        t.expectedPlatformFees = (t.totalPrice * t.platformFeeBPS) / minter.BPS_DENOMINATOR();
        if (t.platformFlatFee != 0) {
            t.expectedPlatformFees += t.platformFlatFee * t.quantity;
            t.requiredEtherValue += t.platformFlatFee * t.quantity;
        }
        if (t.platformPerTxFlatFee != 0) {
            t.expectedPlatformFees += t.platformPerTxFlatFee;
            t.requiredEtherValue += t.platformPerTxFlatFee;
        }

        t.affiliated = minter.isAffiliated(address(edition), mintId, t.affiliate);
        if (t.affiliated) {
            t.expectedAffiliateFees = (t.totalPrice * t.affiliateFeeBPS) / minter.BPS_DENOMINATOR();
        }
        // Expect an event.
        uint32 fromTokenId = uint32(edition.nextTokenId());
        vm.expectEmit(true, true, true, true);
        emit Minted(
            address(edition),
            mintId,
            t.buyer,
            fromTokenId,
            uint32(t.quantity),
            uint128(t.requiredEtherValue),
            uint128(t.expectedPlatformFees),
            uint128(t.expectedAffiliateFees),
            t.affiliate,
            t.affiliated,
            0
        );

        vm.deal(t.buyer, t.requiredEtherValue);
        vm.prank(t.buyer);
        minter.mint{ value: t.requiredEtherValue }(address(edition), mintId, uint32(t.quantity), t.affiliate);

        _test_withdrawAffiliateFeesAccrued(t.affiliate, t.expectedAffiliateFees);
        _test_withdrawPlatformFeesAccrued(t.expectedPlatformFees);
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
        SoundEditionV1_2 edition,
        uint128 mintId,
        uint16 affiliateFeeBPS
    ) internal returns (bool) {
        if (affiliateFeeBPS > minter.MAX_AFFILIATE_FEE_BPS()) {
            vm.expectRevert(IMinterModuleV2_1.InvalidAffiliateFeeBPS.selector);
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
        assertTrue(minter.supportsInterface(type(IMinterModuleV2).interfaceId));
        assertTrue(minter.supportsInterface(type(IMinterModuleV2_1).interfaceId));
        assertTrue(minter.supportsInterface(type(IERC165).interfaceId));
        assertFalse(minter.supportsInterface(bytes4(0)));
    }
}
