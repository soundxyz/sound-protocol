// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IERC721AUpgradeable } from "chiru-labs/ERC721A-Upgradeable/IERC721AUpgradeable.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { TestConfig } from "../../TestConfig.sol";
import { stdError } from "forge-std/Test.sol";

/**
 * @dev Tests base minting functionality directly from edition.
 */
contract SoundEdition_mint is TestConfig {
    event EditionMaxMintableRangeSet(uint32 editionMaxMintableLower_, uint32 editionMaxMintableUpper_);

    event MintRandomnessEnabledSet(bool mintRandomnessEnabled_);

    function test_adminMintRevertsIfNotAuthorized(address nonAdminOrOwner) public {
        vm.assume(nonAdminOrOwner != address(this));
        vm.assume(nonAdminOrOwner != address(0));

        SoundEditionV1 edition = createGenericEdition();

        vm.expectRevert(OwnableRoles.Unauthorized.selector);

        vm.prank(nonAdminOrOwner);
        edition.mint(nonAdminOrOwner, 1);
    }

    function test_adminMintCantMintPastMax() public {
        uint32 editionMaxMintableUpper = 50;

        SoundEditionV1 edition = SoundEditionV1(
            createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                0, // editionMaxMintableLower
                editionMaxMintableUpper,
                EDITION_CUTOFF_TIME,
                FLAGS
            )
        );

        edition.mint(address(this), editionMaxMintableUpper);

        vm.expectRevert(abi.encodeWithSelector(ISoundEditionV1.ExceedsEditionAvailableSupply.selector, 0));

        edition.mint(address(this), 1);
    }

    function test_adminMintSuccess() public {
        SoundEditionV1 edition = createGenericEdition();

        // Test owner can mint to own address
        address owner = address(12345);
        edition.transferOwnership(owner);

        uint32 quantity = 10;

        vm.prank(owner);
        edition.mint(owner, quantity);

        assert(edition.balanceOf(owner) == quantity);

        // Test owner can mint to a recipient address
        address recipient1 = address(39730);

        vm.prank(owner);
        edition.mint(recipient1, quantity);

        assert(edition.balanceOf(recipient1) == quantity);

        // Test an admin can mint to own address
        address admin = address(54321);

        vm.startPrank(owner);
        edition.grantRoles(admin, edition.ADMIN_ROLE());
        vm.stopPrank();

        vm.prank(admin);
        edition.mint(admin, 69);

        assert(edition.balanceOf(admin) == 69);

        // Test an admin can mint to a recipient address
        address recipient2 = address(837802);
        vm.prank(admin);
        edition.mint(recipient2, quantity);

        assert(edition.balanceOf(recipient2) == quantity);
    }

    function test_burn(address attacker) public {
        vm.assume(attacker != address(this));

        uint256 ONE_TOKEN = 1;
        uint256 TOKEN1_ID = 1;
        uint256 TOKEN2_ID = 1;

        SoundEditionV1 edition = createGenericEdition();

        // Assert that the token owner can burn

        edition.mint(address(this), ONE_TOKEN);
        edition.burn(TOKEN1_ID);

        assert(edition.balanceOf(address(this)) == 0);
        assert(edition.numberBurned(address(this)) == ONE_TOKEN);
        assert(edition.totalSupply() == 0);

        // Mint another token and assert that the attacker can't burn

        edition.mint(address(this), ONE_TOKEN);

        vm.expectRevert(IERC721AUpgradeable.OwnerQueryForNonexistentToken.selector);

        vm.prank(attacker);
        edition.burn(TOKEN2_ID);
    }

    function test_setEditionMaxMintableRangeSuccessViaOwner() external {
        uint32 editionMaxMintableLower = 1;
        uint32 editionMaxMintableUpper = 3;

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
                EDITION_CUTOFF_TIME,
                FLAGS
            )
        );

        // Mint a token
        edition.mint(address(this), 1);

        // Set new max mintable
        editionMaxMintableUpper -= 1;
        vm.expectEmit(true, true, true, true);
        emit EditionMaxMintableRangeSet(editionMaxMintableLower, editionMaxMintableUpper);

        edition.setEditionMaxMintableRange(editionMaxMintableLower, editionMaxMintableUpper);
        assertEq(edition.editionMaxMintableUpper(), editionMaxMintableUpper);

        // Mint another token
        edition.mint(address(this), 1);

        // We're now at editionMaxMintable
        assertEq(edition.totalMinted(), edition.editionMaxMintable());
    }

    function test_setEditionMaxMintableRangeSuccessViaAdmin() external {
        uint32 editionMaxMintableLower = 1;
        uint32 editionMaxMintableUpper = 3;

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
                EDITION_CUTOFF_TIME,
                FLAGS
            )
        );

        address admin = address(1203701);
        edition.grantRoles(admin, edition.ADMIN_ROLE());

        // Mint a token
        edition.mint(address(this), 1);

        // Set new max mintable
        editionMaxMintableUpper -= 1;
        vm.expectEmit(true, true, true, true);
        emit EditionMaxMintableRangeSet(editionMaxMintableLower, editionMaxMintableUpper);

        vm.prank(admin);
        edition.setEditionMaxMintableRange(editionMaxMintableLower, editionMaxMintableUpper);
        assertEq(edition.editionMaxMintableUpper(), editionMaxMintableUpper);

        // Mint another token
        edition.mint(address(this), 1);

        // We're now at editionMaxMintable
        assertEq(edition.totalMinted(), edition.editionMaxMintable());
    }

    function test_setEditionMaxMintableRangeRevertsIfNotAuthorized(address attacker) external {
        SoundEditionV1 edition = createGenericEdition();
        vm.assume(attacker != address(this));

        vm.expectRevert(OwnableRoles.Unauthorized.selector);
        vm.prank(attacker);
        edition.setEditionMaxMintableRange(0, 0);
    }

    function test_setEditionMaxMintableRangeRevertsIfValueInvalid() external {
        SoundEditionV1 edition = createGenericEdition();

        edition.setEditionMaxMintableRange(0, 10);

        // We can freely set the range, as long no tokens have been minted.
        edition.setEditionMaxMintableRange(3, 100);
        edition.setEditionMaxMintableRange(1, 2);
        edition.setEditionMaxMintableRange(0, 10);

        // Mint some tokens
        edition.mint(address(this), 5);

        // Attempt to increase max mintable above current max - should fail,
        // as we have already minted tokens.
        vm.expectRevert(ISoundEditionV1.InvalidEditionMaxMintableRange.selector);
        edition.setEditionMaxMintableRange(0, 11);

        // Attempt to lower max mintable below current minted count - should set to current minted count
        edition.setEditionMaxMintableRange(0, 4);

        assertEq(edition.editionMaxMintableUpper(), 5);

        // Attempt to lower again - should revert
        vm.expectRevert(ISoundEditionV1.MintHasConcluded.selector);
        edition.setEditionMaxMintableRange(0, 4);
    }

    function test_airdropSuccess() external {
        SoundEditionV1 edition = createGenericEdition();

        address[] memory to = new address[](3);
        to[0] = address(10000000);
        to[1] = address(10000001);
        to[2] = address(10000002);

        uint256 quantity = 10;

        assertEq(edition.balanceOf(to[0]), 0);
        assertEq(edition.balanceOf(to[1]), 0);
        assertEq(edition.balanceOf(to[2]), 0);

        uint256 expectedFromTokenId = edition.nextTokenId();
        uint256 fromTokenId = edition.airdrop(to, quantity);

        assertEq(expectedFromTokenId, fromTokenId);

        assertEq(edition.balanceOf(to[0]), quantity);
        assertEq(edition.balanceOf(to[1]), quantity);
        assertEq(edition.balanceOf(to[2]), quantity);

        // Grant some new address the `ADMIN` role.
        address admin = address(20000000);
        edition.grantRoles(admin, edition.ADMIN_ROLE());

        expectedFromTokenId = edition.nextTokenId();
        vm.prank(admin);
        fromTokenId = edition.airdrop(to, quantity);

        assertEq(expectedFromTokenId, fromTokenId);

        assertEq(edition.balanceOf(to[0]), quantity * 2);
        assertEq(edition.balanceOf(to[1]), quantity * 2);
        assertEq(edition.balanceOf(to[2]), quantity * 2);
    }

    function test_airdropRevertsIfExceedsEditionMaxMintable() external {
        SoundEditionV1 edition = createGenericEdition();
        uint32 editionMaxMintableLower = 0;
        uint32 editionMaxMintableUpper = 9;
        edition.setEditionMaxMintableRange(editionMaxMintableLower, editionMaxMintableUpper);

        address[] memory to = new address[](3);
        to[0] = address(10000000);
        to[1] = address(10000001);
        to[2] = address(10000002);

        uint256 quantity = 4;
        // Reverts if the `quantity * to.length > editionMaxMintableUpper`.
        vm.expectRevert(
            abi.encodeWithSelector(ISoundEditionV1.ExceedsEditionAvailableSupply.selector, editionMaxMintableUpper)
        );
        edition.airdrop(to, quantity);

        // Otherwise, succeeds.
        quantity = 3;
        edition.airdrop(to, quantity);
    }

    function test_airdropRevertsForNoAddresses() external {
        SoundEditionV1 edition = createGenericEdition();

        address[] memory to;

        vm.expectRevert(ISoundEditionV1.NoAddressesToAirdrop.selector);
        edition.airdrop(to, 1);
    }

    function test_airdropSetsMintRandomness() external {
        SoundEditionV1 edition = createGenericEdition();

        uint256 timeThreshold = block.timestamp + 10;
        edition.setEditionMaxMintableRange(1, EDITION_MAX_MINTABLE);
        edition.setEditionCutoffTime(uint32(timeThreshold));

        address[] memory to = new address[](3);
        to[0] = address(10000000);
        to[1] = address(10000001);
        to[2] = address(10000002);

        assertTrue(edition.mintRandomness() == 0);

        edition.airdrop(to, 1);

        vm.warp(timeThreshold);

        assertTrue(edition.mintRandomness() != 0);
    }

    function test_airdropRevertsIfNotAuthorized(address nonAdminOrOwner) public {
        vm.assume(nonAdminOrOwner != address(this));
        vm.assume(nonAdminOrOwner != address(0));

        SoundEditionV1 edition = createGenericEdition();

        address[] memory to;

        vm.prank(nonAdminOrOwner);
        vm.expectRevert(OwnableRoles.Unauthorized.selector);
        edition.airdrop(to, 1);
    }

    function test_setMintRandomessEnabled(bool mintRandomnessEnabled0, bool mintRandomnessEnabled1) public {
        SoundEditionV1 edition = createGenericEdition();

        vm.expectEmit(true, true, true, true);
        emit MintRandomnessEnabledSet(mintRandomnessEnabled0);
        edition.setMintRandomnessEnabled(mintRandomnessEnabled0);

        assertEq(edition.mintRandomnessEnabled(), mintRandomnessEnabled0);

        vm.expectEmit(true, true, true, true);
        emit MintRandomnessEnabledSet(mintRandomnessEnabled1);
        edition.setMintRandomnessEnabled(mintRandomnessEnabled1);

        assertEq(edition.mintRandomnessEnabled(), mintRandomnessEnabled1);
    }

    function test_setMintRandomessEnabled() public {
        test_setMintRandomessEnabled(true, false);
        test_setMintRandomessEnabled(false, true);
    }

    function test_setMintRandomessEnabledRevertsWhenThereAreMints(uint32 quantity, bool mintRandomnessEnabled) public {
        SoundEditionV1 edition = createGenericEdition();

        edition.mint(address(this), bound(quantity, 1, 10));

        vm.expectRevert(ISoundEditionV1.MintsAlreadyExist.selector);
        edition.setMintRandomnessEnabled(mintRandomnessEnabled);
    }

    function test_setMintRandomessEnabledRevertsWhenThereAreMints() public {
        test_setMintRandomessEnabledRevertsWhenThereAreMints(1, true);
        test_setMintRandomessEnabledRevertsWhenThereAreMints(1, false);
    }

    function test_mintRandomessEnabledUpdatesRandomness(bool mintRandomnessEnabled) public {
        SoundEditionV1 edition = createGenericEdition();

        uint256 timeThreshold = block.timestamp + 10;
        edition.setEditionMaxMintableRange(1, EDITION_MAX_MINTABLE);
        edition.setEditionCutoffTime(uint32(timeThreshold));

        edition.setMintRandomnessEnabled(mintRandomnessEnabled);

        edition.mint(address(this), 1);

        vm.warp(timeThreshold);

        if (mintRandomnessEnabled) {
            assertTrue(edition.mintRandomness() != 0);
        } else {
            assertTrue(edition.mintRandomness() == 0);
        }
    }

    function test_setEditionMaxMintableRangeRevertsIfMintHasConcluded() public {
        SoundEditionV1 edition = createGenericEdition();

        uint256 timeThreshold = block.timestamp + 10;
        edition.setEditionMaxMintableRange(1, EDITION_MAX_MINTABLE);
        edition.setEditionCutoffTime(uint32(timeThreshold));

        vm.warp(timeThreshold);

        edition.mint(address(this), 1);

        vm.expectRevert(ISoundEditionV1.MintHasConcluded.selector);
        edition.setEditionMaxMintableRange(1, EDITION_MAX_MINTABLE);
    }

    function test_setEditionMaxMintableRangeRevertsIfInvalidRange() public {
        SoundEditionV1 edition = createGenericEdition();

        // We can freely set the range, as long no tokens have been minted.
        edition.setEditionMaxMintableRange(1, 9);
        edition.setEditionMaxMintableRange(122, 122);
        edition.setEditionMaxMintableRange(111, 1111);
        edition.setEditionMaxMintableRange(1, 11);

        uint32 editionMaxMintableLower = 5;
        uint32 editionMaxMintableUpper = 3;

        // However, we cannot the lower bound to be greater than the upper bound.
        vm.expectRevert(ISoundEditionV1.InvalidEditionMaxMintableRange.selector);
        edition.setEditionMaxMintableRange(editionMaxMintableLower, editionMaxMintableUpper);

        // Change the upper bound.
        edition.setEditionMaxMintableRange(0, editionMaxMintableUpper);

        edition.mint(address(this), 1);

        // Checks reverts if the upper bound exceeds the previous upper bound.
        vm.expectRevert(ISoundEditionV1.InvalidEditionMaxMintableRange.selector);
        edition.setEditionMaxMintableRange(0, editionMaxMintableUpper + 1);
    }

    function test_setEditionCutoffTimeRevertsIfMintHasConcluded() public {
        SoundEditionV1 edition = createGenericEdition();

        uint256 timeThreshold = block.timestamp + 10;
        edition.setEditionMaxMintableRange(1, EDITION_MAX_MINTABLE);
        edition.setEditionCutoffTime(uint32(timeThreshold));

        vm.warp(timeThreshold);

        edition.mint(address(this), 1);

        vm.expectRevert(ISoundEditionV1.MintHasConcluded.selector);
        edition.setEditionCutoffTime(uint32(timeThreshold));
    }

    function test_mintWithQuantityOverLimitReverts() public {
        SoundEditionV1 edition = createGenericEdition();
        uint256 limit = edition.ADDRESS_BATCH_MINT_LIMIT();
        // Minting one more than the limit will revert.
        vm.expectRevert(ISoundEditionV1.ExceedsAddressBatchMintLimit.selector);
        edition.mint(address(this), limit + 1);
        // Minting right at the limit is ok.
        edition.mint(address(this), limit);
    }

    function test_airdropWithQuantityOverLimitReverts() public {
        SoundEditionV1 edition = createGenericEdition();
        uint256 limit = edition.ADDRESS_BATCH_MINT_LIMIT();
        address[] memory to = new address[](1);
        to[0] = address(10000000);
        // Airdrop with `quantity` one more than the limit will revert.
        vm.expectRevert(ISoundEditionV1.ExceedsAddressBatchMintLimit.selector);
        edition.airdrop(to, limit + 1);
        // Airdrop with `quantity` right at the limit is ok.
        edition.airdrop(to, limit);
    }

    function test_numberMintedReturnsExpectedValue() public {
        SoundEditionV1 edition = createGenericEdition();

        address owner = address(12345);
        edition.transferOwnership(owner);

        assertTrue(edition.numberMinted(owner) == 0);

        vm.prank(owner);
        uint32 quantity = 10;
        edition.mint(owner, quantity);

        assertTrue(edition.numberMinted(owner) == quantity);
    }
}
