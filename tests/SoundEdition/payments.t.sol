// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "../TestConfig.sol";

contract SoundEdition_payments is TestConfig {
    uint256 constant MAX_BPS = 10_000;

    event FundingRecipientSet(address fundingRecipient);
    event RoyaltySet(uint32 royaltyBPS);

    error InvalidRoyaltyBPS();

    function _createEdition() internal returns (MockSoundEditionV1 soundEdition) {
        soundEdition = MockSoundEditionV1(
            payable(
                soundCreator.createSound(
                    SONG_NAME,
                    SONG_SYMBOL,
                    METADATA_MODULE,
                    BASE_URI,
                    CONTRACT_URI,
                    FUNDING_RECIPIENT,
                    ROYALTY_BPS
                )
            )
        );
    }

    function test_initializeRevertsForInvalidRoyaltyBPS(uint32 royaltyBPS) public {
        vm.assume(royaltyBPS > MAX_BPS);

        vm.expectRevert(InvalidRoyaltyBPS.selector);
        soundCreator.createSound(
            SONG_NAME,
            SONG_SYMBOL,
            METADATA_MODULE,
            BASE_URI,
            CONTRACT_URI,
            FUNDING_RECIPIENT,
            royaltyBPS
        );
    }

    function test_withdrawAllSuccess() public {
        MockSoundEditionV1 edition = _createEdition();

        // mint with ETH
        uint256 primarySales = 10 ether;
        edition.mint{ value: primarySales }(1);

        // secondary royalty
        uint256 secondarySales = 2 ether;
        (bool success, ) = address(edition).call{ value: secondarySales }("");
        require(success);

        uint256 totalSales = primarySales + secondarySales;

        uint256 preSoundFeeAddressBal = soundFeeAddress.balance;
        uint256 preFundingRecipitentBal = FUNDING_RECIPIENT.balance;

        edition.withdrawAll();

        uint256 postSoundFeeAddressBal = soundFeeAddress.balance;
        uint256 postFundingRecipitentBal = FUNDING_RECIPIENT.balance;

        uint256 expectedPlatformFee = (totalSales * PLATFORM_FEE) / MAX_BPS;
        uint256 expectedSoundFeeAddressBal = preSoundFeeAddressBal + expectedPlatformFee;
        uint256 expectedFundingRecipitentBal = preFundingRecipitentBal + (totalSales - expectedPlatformFee);

        assertEq(postSoundFeeAddressBal, expectedSoundFeeAddressBal);
        assertEq(postFundingRecipitentBal, expectedFundingRecipitentBal);
    }

    // ================================
    // setFundingRecipient()
    // ================================

    function test_setFundingRecipientRevertsForNonOwner() public {
        MockSoundEditionV1 edition = _createEdition();

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        edition.setFundingRecipient(getRandomAccount(2));
    }

    function test_setFundingRecipientSuccess() public {
        MockSoundEditionV1 edition = _createEdition();

        address newFundingRecipient = getRandomAccount(1);
        edition.setFundingRecipient(newFundingRecipient);

        assertEq(edition.fundingRecipient(), newFundingRecipient);
    }

    function test_setFundingRecipientEmitsEvent() public {
        MockSoundEditionV1 edition = _createEdition();

        address newFundingRecipient = getRandomAccount(1);

        vm.expectEmit(false, false, false, true);
        emit FundingRecipientSet(newFundingRecipient);
        edition.setFundingRecipient(newFundingRecipient);
    }

    // ================================
    // setRoyalty()
    // ================================

    function test_setRoyaltyRevertsForNonOwner() public {
        MockSoundEditionV1 edition = _createEdition();

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        edition.setRoyalty(500);
    }

    function test_setRoyaltyRevertsForInvalidValue(uint32 royaltyBPS) public {
        vm.assume(royaltyBPS > MAX_BPS);
        MockSoundEditionV1 edition = _createEdition();

        vm.expectRevert(InvalidRoyaltyBPS.selector);
        edition.setRoyalty(royaltyBPS);
    }

    function test_setRoyaltySuccess(uint32 royaltyBPS) public {
        vm.assume(royaltyBPS <= MAX_BPS);
        MockSoundEditionV1 edition = _createEdition();

        edition.setRoyalty(royaltyBPS);

        assertEq(edition.royaltyBPS(), royaltyBPS);
    }

    function test_setRoyaltyEmitsEvent(uint32 royaltyBPS) public {
        vm.assume(royaltyBPS <= MAX_BPS);
        MockSoundEditionV1 edition = _createEdition();

        vm.expectEmit(false, false, false, true);
        emit RoyaltySet(royaltyBPS);
        edition.setRoyalty(royaltyBPS);
    }

    // ================================
    // royaltyInfo()
    // ================================

    function test_RoyaltyInfo(uint256 tokenId, uint256 salePrice) public {
        // avoid overflow
        vm.assume(salePrice < 2**128);

        MockSoundEditionV1 edition = _createEdition();

        (address fundingRecipient, uint256 royaltyAmount) = edition.royaltyInfo(tokenId, salePrice);

        uint256 expectedRoyaltyAmount = (salePrice * ROYALTY_BPS) / MAX_BPS;

        assertEq(fundingRecipient, address(edition));
        assertEq(royaltyAmount, expectedRoyaltyAmount);
    }
}
