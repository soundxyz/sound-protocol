// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IERC721AUpgradeable } from "chiru-labs/ERC721A-Upgradeable/IERC721AUpgradeable.sol";
import { ISoundEditionEventsAndErrors } from "@core/interfaces/edition/ISoundEditionEventsAndErrors.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { TestConfig } from "../../TestConfig.sol";

/**
 * @dev Tests base minting functionality directly from edition.
 */
contract SoundEdition_mint is TestConfig {
    event EditionMaxMintableSet(uint32 newMax);

    function test_adminMintRevertsIfNotAuthorized(address nonAdminOrOwner) public {
        vm.assume(nonAdminOrOwner != address(this));
        vm.assume(nonAdminOrOwner != address(0));

        SoundEditionV1 edition = createGenericEdition();

        vm.expectRevert(ISoundEditionEventsAndErrors.Unauthorized.selector);

        vm.prank(nonAdminOrOwner);
        edition.mint(nonAdminOrOwner, 1);
    }

    function test_adminMintCantMintPastMax() public {
        uint32 maxQuantity = 5000;

        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                maxQuantity,
                EDITION_MAX_MINTABLE,
                RANDOMNESS_LOCKED_TIMESTAMP
            )
        );

        edition.mint(address(this), maxQuantity);

        vm.expectRevert(abi.encodeWithSelector(ISoundEditionEventsAndErrors.ExceedsEditionAvailableSupply.selector, 0));

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

        edition.grantRole(edition.ADMIN_ROLE(), admin);

        vm.prank(admin);
        edition.mint(admin, 420);

        assert(edition.balanceOf(admin) == 420);

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
        assert(edition.totalSupply() == 0);

        // Mint another token and assert that the attacker can't burn

        edition.mint(address(this), ONE_TOKEN);

        vm.expectRevert(IERC721AUpgradeable.OwnerQueryForNonexistentToken.selector);

        vm.prank(attacker);
        edition.burn(TOKEN2_ID);
    }

    function test_reduceEditionMaxMintableSuccessViaOwner() external {
        uint32 MAX_3 = 3;
        uint32 MAX_2 = 2;

        vm.expectEmit(false, false, false, true);
        emit EditionMaxMintableSet(MAX_3);

        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                MAX_3,
                EDITION_MAX_MINTABLE,
                RANDOMNESS_LOCKED_TIMESTAMP
            )
        );

        // Mint a token
        edition.mint(address(this), 1);

        // Set new max mintable
        vm.expectEmit(false, false, false, true);
        emit EditionMaxMintableSet(MAX_2);

        edition.reduceEditionMaxMintable(MAX_2);
        assert(edition.editionMaxMintable() == MAX_2);

        // Mint another token
        edition.mint(address(this), 1);

        // We're now at editionMaxMintable
        assertEq(edition.totalMinted(), edition.editionMaxMintable());
    }

    function test_reduceEditionMaxMintableSuccessViaAdmin() external {
        uint32 MAX_3 = 3;
        uint32 MAX_2 = 2;

        vm.expectEmit(false, false, false, true);
        emit EditionMaxMintableSet(MAX_3);

        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                MAX_3,
                EDITION_MAX_MINTABLE,
                RANDOMNESS_LOCKED_TIMESTAMP
            )
        );

        address admin = address(1203701);
        edition.grantRole(edition.ADMIN_ROLE(), admin);

        // Mint a token
        edition.mint(address(this), 1);

        // Set new max mintable
        vm.expectEmit(false, false, false, true);
        emit EditionMaxMintableSet(MAX_2);

        vm.prank(admin);
        edition.reduceEditionMaxMintable(MAX_2);
        assert(edition.editionMaxMintable() == MAX_2);

        // Mint another token
        edition.mint(address(this), 1);

        // We're now at editionMaxMintable
        assertEq(edition.totalMinted(), edition.editionMaxMintable());
    }

    function test_reduceEditionMaxMintableRevertsIfNotAuthorized(address attacker) external {
        SoundEditionV1 edition = createGenericEdition();
        vm.assume(attacker != address(this));

        vm.expectRevert(ISoundEditionEventsAndErrors.Unauthorized.selector);
        vm.prank(attacker);
        edition.reduceEditionMaxMintable(1);
    }

    function test_reduceEditionMaxMintableRevertsIfValueInvalid() external {
        SoundEditionV1 edition = createGenericEdition();

        edition.reduceEditionMaxMintable(10);

        // Attempt to increase max mintable above current max - should fail
        vm.expectRevert(ISoundEditionEventsAndErrors.InvalidAmount.selector);
        edition.reduceEditionMaxMintable(11);

        // Mint some tokens
        edition.mint(address(this), 5);

        // Attempt to lower max mintable below current minted count - should set to current minted count
        edition.reduceEditionMaxMintable(4);

        assert(edition.editionMaxMintable() == 5);

        // Attempt to lower again - should revert
        vm.expectRevert(ISoundEditionEventsAndErrors.MaximumHasAlreadyBeenReached.selector);
        edition.reduceEditionMaxMintable(4);
    }
}
