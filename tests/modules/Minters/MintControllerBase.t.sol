pragma solidity ^0.8.16;

import "../../TestConfig.sol";
import "../../mocks/MockMinter.sol";
import "../../../contracts/SoundEdition/SoundEditionV1.sol";
import "../../../contracts/SoundCreator/SoundCreatorV1.sol";

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

        vm.expectRevert(BaseMinter.Unauthorized.selector);
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

        vm.expectRevert(abi.encodeWithSelector(BaseMinter.WrongEtherValue.selector, price * 2 - 1, price * 2));
        minter.mint{ value: price * 2 - 1 }(address(edition), mintId, 2, price, address(0));

        minter.mint{ value: price * 2 }(address(edition), mintId, 2, price, address(0));
    }

    function test_mintPaused() public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);

        vm.expectEmit(true, true, true, true);
        emit MintPausedSet(address(edition), mintId, true);
        minter.setEditionMintPaused(address(edition), mintId, true);

        uint256 price = 1;
        vm.expectRevert(BaseMinter.MintPaused.selector);

        minter.mint{ value: price * 2 }(address(edition), mintId, 2, price, address(0));

        vm.expectEmit(true, true, true, true);
        emit MintPausedSet(address(edition), mintId, false);
        minter.setEditionMintPaused(address(edition), mintId, false);

        minter.mint{ value: price * 2 }(address(edition), mintId, 2, price, address(0));
    }

    function test_mintRevertsWithZeroQuantity() public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);

        vm.expectRevert(IERC721AUpgradeable.MintZeroQuantity.selector);

        minter.mint{ value: 0 }(address(edition), mintId, 0, 0, address(0));
    }

    function test_createEditionMintMultipleTimes() external {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        for (uint256 i; i < 3; ++i) {
            uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);
            assertEq(mintId, i);
        }
    }

    function test_cantMintPastEditionMaxMintable() external {
        uint32 maxSupply = 5000;

        SoundEditionV1 edition1 = _createEdition(maxSupply);

        uint256 mintId1 = minter.createEditionMint(address(edition1), START_TIME, END_TIME);

        // Mint the max supply
        minter.mint(address(edition1), mintId1, maxSupply, 0, address(0));

        // try minting 1 more
        vm.expectRevert(SoundEditionV1.EditionMaxMintableReached.selector);
        minter.mint(address(edition1), mintId1, 1, 0, address(0));
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
        vm.expectRevert(BaseMinter.Unauthorized.selector);
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

    function test_setPlatformFee() public {
        _test_setPlatformFee(10);
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

        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        address affiliate = affiliateIsZeroAddress
            ? address(0)
            : getFundedAccount(uint256(keccak256(abi.encode(affiliateSeed))));

        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);

        if (!_test_setPlatformFee(platformFeeBPS)) return;
        if (!_test_setAffiliateFee(edition, mintId, affiliateFeeBPS)) return;
        if (!_test_setAffiliateDiscount(edition, mintId, affiliateDiscountBPS)) return;

        uint256 requiredEtherValue = price * quantity;
        uint256 expectedAffiliateFees;
        uint256 expectedPlatformFees;

        if (minter.isAffiliated(address(edition), mintId, affiliate)) {
            requiredEtherValue = minter.affiliatedPrice(address(edition), mintId, requiredEtherValue, affiliate);
            expectedAffiliateFees = (requiredEtherValue * affiliateFeeBPS) / minter.MAX_BPS();
        }

        expectedPlatformFees = (requiredEtherValue * platformFeeBPS) / minter.MAX_BPS();

        if (expectedAffiliateFees + expectedPlatformFees > requiredEtherValue) {
            vm.expectRevert(stdError.arithmeticError);
            minter.mint{ value: requiredEtherValue }(address(edition), mintId, quantity, price, affiliate);
            return;
        }
        minter.mint{ value: requiredEtherValue }(address(edition), mintId, quantity, price, affiliate);

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

    function _test_setPlatformFee(uint16 platformFeeBPS) internal returns (bool) {
        if (platformFeeBPS > minter.MAX_BPS()) {
            vm.expectRevert(BaseMinter.InvalidPlatformFeeBPS.selector);
            minter.setPlatformFee(platformFeeBPS);
            return false;
        }
        vm.expectEmit(true, true, true, true);
        emit PlatformFeeSet(platformFeeBPS);
        minter.setPlatformFee(platformFeeBPS);
        assertEq(minter.platformFeeBPS(), platformFeeBPS);
        return true;
    }

    function _test_setAffiliateFee(
        SoundEditionV1 edition,
        uint256 mintId,
        uint16 affiliateFeeBPS
    ) internal returns (bool) {
        if (affiliateFeeBPS > minter.MAX_BPS()) {
            vm.expectRevert(BaseMinter.InvalidAffiliateFeeBPS.selector);
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
            vm.expectRevert(BaseMinter.InvalidAffiliateDiscountBPS.selector);
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
