// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { TestConfig } from "../../TestConfig.sol";

contract SoundEdition_payments is TestConfig {
    event FundingRecipientSet(address fundingRecipient);
    event RoyaltySet(uint16 royaltyBPS);

    function test_initializeRevertsForInvalidRoyaltyBPS(uint16 royaltyBPS) public {
        vm.assume(royaltyBPS > MAX_BPS);

        vm.expectRevert(ISoundEditionV1.InvalidRoyaltyBPS.selector);
        createSound(
            SONG_NAME,
            SONG_SYMBOL,
            METADATA_MODULE,
            BASE_URI,
            CONTRACT_URI,
            FUNDING_RECIPIENT,
            royaltyBPS,
            EDITION_MAX_MINTABLE,
            EDITION_MAX_MINTABLE,
            EDITION_CUTOFF_TIME,
            FLAGS
        );
    }

    function test_initializeRevertsForInvalidFundingRecipient() public {
        vm.expectRevert(ISoundEditionV1.InvalidFundingRecipient.selector);
        createSound(
            SONG_NAME,
            SONG_SYMBOL,
            METADATA_MODULE,
            BASE_URI,
            CONTRACT_URI,
            address(0),
            ROYALTY_BPS,
            EDITION_MAX_MINTABLE,
            EDITION_MAX_MINTABLE,
            EDITION_CUTOFF_TIME,
            FLAGS
        );
    }

    function test_withdrawETHSuccess() public {
        SoundEditionV1 edition = createGenericEdition();

        // mint with ETH
        uint256 primaryETHSales = 10 ether;
        edition.mint{ value: primaryETHSales }(address(this), 1);

        uint256 totalETHSales = primaryETHSales;

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
        SoundEditionV1 edition = createGenericEdition();

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
        SoundEditionV1 edition = createGenericEdition();

        address caller = getFundedAccount(1);
        vm.prank(caller);
        vm.expectRevert(OwnableRoles.Unauthorized.selector);
        edition.setFundingRecipient(getFundedAccount(2));
    }

    function test_setFundingRecipientRevertsForZeroAddress() public {
        SoundEditionV1 edition = createGenericEdition();

        vm.expectRevert(ISoundEditionV1.InvalidFundingRecipient.selector);
        edition.setFundingRecipient(address(0));
    }

    function test_setFundingRecipientSuccess() public {
        SoundEditionV1 edition = createGenericEdition();

        address newFundingRecipient = getFundedAccount(1);
        edition.setFundingRecipient(newFundingRecipient);

        assertEq(edition.fundingRecipient(), newFundingRecipient);
    }

    function test_setFundingRecipientEmitsEvent() public {
        SoundEditionV1 edition = createGenericEdition();

        address newFundingRecipient = getFundedAccount(1);

        vm.expectEmit(false, false, false, true);
        emit FundingRecipientSet(newFundingRecipient);
        edition.setFundingRecipient(newFundingRecipient);
    }

    // ================================
    // setRoyalty()
    // ================================

    function test_setRoyaltyRevertsForNonOwner() public {
        SoundEditionV1 edition = createGenericEdition();

        address caller = getFundedAccount(1);
        vm.prank(caller);
        vm.expectRevert(OwnableRoles.Unauthorized.selector);
        edition.setRoyalty(500);
    }

    function test_setRoyaltyRevertsForInvalidValue(uint16 royaltyBPS) public {
        vm.assume(royaltyBPS > MAX_BPS);
        SoundEditionV1 edition = createGenericEdition();

        vm.expectRevert(ISoundEditionV1.InvalidRoyaltyBPS.selector);
        edition.setRoyalty(royaltyBPS);
    }

    function test_setRoyaltySuccess(uint16 royaltyBPS) public {
        vm.assume(royaltyBPS <= MAX_BPS);
        SoundEditionV1 edition = createGenericEdition();

        edition.setRoyalty(royaltyBPS);

        assertEq(edition.royaltyBPS(), royaltyBPS);
    }

    function test_setRoyaltyEmitsEvent(uint16 royaltyBPS) public {
        vm.assume(royaltyBPS <= MAX_BPS);
        SoundEditionV1 edition = createGenericEdition();

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

        SoundEditionV1 edition = createGenericEdition();

        (address fundingRecipient, uint256 royaltyAmount) = edition.royaltyInfo(tokenId, salePrice);

        uint256 expectedRoyaltyAmount = (salePrice * ROYALTY_BPS) / MAX_BPS;

        assertEq(fundingRecipient, FUNDING_RECIPIENT);
        assertEq(royaltyAmount, expectedRoyaltyAmount);
    }

    function test_supportsERC2981Interface() public {
        bytes4 _INTERFACE_ID_ERC2981 = 0x2a55205a;

        SoundEditionV1 edition = createGenericEdition();
        bool supportsERC2981 = edition.supportsInterface(_INTERFACE_ID_ERC2981);
        assertTrue(supportsERC2981);
    }
}
