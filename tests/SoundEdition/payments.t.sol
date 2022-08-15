// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "../TestConfig.sol";
import "../mocks/MockERC20.sol";

contract SoundEdition_payments is TestConfig {
    uint256 constant MAX_BPS = 10_000;

    event FundingRecipientSet(address fundingRecipient);
    event RoyaltySet(uint32 royaltyBPS);

    error InvalidRoyaltyBPS();

    function _createEdition() internal returns (MockSoundEditionV1 soundEdition) {
        soundEdition = MockSoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                MASTER_MAX_MINTABLE,
                MASTER_MAX_MINTABLE,
                RANDOMNESS_LOCKED_TIMESTAMP
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
            royaltyBPS,
            MASTER_MAX_MINTABLE,
            MASTER_MAX_MINTABLE,
            RANDOMNESS_LOCKED_TIMESTAMP
        );
    }

    function test_withdrawETHSuccess() public {
        MockSoundEditionV1 edition = _createEdition();

        // mint with ETH
        uint256 primaryETHSales = 10 ether;
        edition.mint{ value: primaryETHSales }(1);

        // secondary ETH royalty
        uint256 secondaryETHSales = 2 ether;
        (bool success, ) = address(edition).call{ value: secondaryETHSales }("");
        require(success);

        uint256 totalETHSales = primaryETHSales + secondaryETHSales;

        // withdraw
        uint256 preFundingRecipitentETHBal = FUNDING_RECIPIENT.balance;

        edition.withdrawETH();

        // post balances
        uint256 postFundingRecipitentETHBal = FUNDING_RECIPIENT.balance;

        // expected ETH
        uint256 expectedFundingRecipitentETHBal = preFundingRecipitentETHBal + totalETHSales;

        assertEq(postFundingRecipitentETHBal, expectedFundingRecipitentETHBal);
    }

    function test_withdrawERC20Success() public {
        MockSoundEditionV1 edition = _createEdition();

        // secondary ERC20 royalties
        MockERC20 tokenA = new MockERC20();
        MockERC20 tokenB = new MockERC20();

        uint256 tokenASales = 1_000 ether;
        uint256 tokenBSales = 5_000 ether;

        tokenA.transfer(address(edition), tokenASales);
        tokenB.transfer(address(edition), tokenBSales);

        // withdraw
        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        edition.withdrawERC20(tokens);

        _assertPostTokenBalances(tokens, [tokenASales, tokenBSales]);
    }

    function _assertPostTokenBalances(address[] memory tokens, uint256[2] memory sales) internal {
        for (uint256 i; i < tokens.length; i++) {
            uint256 postFundingRecipitentTokenBal = MockERC20(tokens[i]).balanceOf(FUNDING_RECIPIENT);
            uint256 expectedFundingRecipitentTokenBal = sales[i];

            assertEq(postFundingRecipitentTokenBal, expectedFundingRecipitentTokenBal);
        }
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
