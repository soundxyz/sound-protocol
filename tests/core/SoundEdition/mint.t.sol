// SPDX-License-Identifier: GPL-3.0-or-later
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
    event EditionMaxMintableSet(uint32 newMax);

    function test_adminMintRevertsIfNotAuthorized(address nonAdminOrOwner) public {
        vm.assume(nonAdminOrOwner != address(this));
        vm.assume(nonAdminOrOwner != address(0));

        SoundEditionV1 edition = createGenericEdition();

        vm.expectRevert(OwnableRoles.Unauthorized.selector);

        vm.prank(nonAdminOrOwner);
        edition.mint(nonAdminOrOwner, 1);
    }

    function test_adminMintCantMintPastMax() public {
        uint32 maxQuantity = 5000;

        SoundEditionV1 edition = SoundEditionV1(
            createSound(
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
        edition.mint(admin, 420);

        assert(edition.balanceOf(admin) == 420);

        // Test an admin can mint to a recipient address
        address recipient2 = address(837802);
        vm.prank(admin);
        edition.mint(recipient2, quantity);

        assert(edition.balanceOf(recipient2) == quantity);
    }

    function test_mintWithOverflowReverts() public {
        SoundEditionV1 edition = createGenericEdition();
        edition.mint(address(this), 1);
        vm.expectRevert();
        edition.mint(address(this), type(uint256).max);
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
            createSound(
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
            createSound(
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
        edition.grantRoles(admin, edition.ADMIN_ROLE());

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

        vm.expectRevert(OwnableRoles.Unauthorized.selector);
        vm.prank(attacker);
        edition.reduceEditionMaxMintable(1);
    }

    function test_reduceEditionMaxMintableRevertsIfValueInvalid() external {
        SoundEditionV1 edition = createGenericEdition();

        edition.reduceEditionMaxMintable(10);

        // Attempt to increase max mintable above current max - should fail
        vm.expectRevert(ISoundEditionV1.InvalidAmount.selector);
        edition.reduceEditionMaxMintable(11);

        // Mint some tokens
        edition.mint(address(this), 5);

        // Attempt to lower max mintable below current minted count - should set to current minted count
        edition.reduceEditionMaxMintable(4);

        assert(edition.editionMaxMintable() == 5);

        // Attempt to lower again - should revert
        vm.expectRevert(ISoundEditionV1.MaximumHasAlreadyBeenReached.selector);
        edition.reduceEditionMaxMintable(4);
    }

    function test_airdropSuccess() external {
        SoundEditionV1 edition = createGenericEdition();

        address[] memory to = new address[](3);
        to[0] = address(10000000);
        to[1] = address(10000001);
        to[2] = address(10000002);

        uint256 quantity = 10;
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
        uint32 editionMaxMintable = 9;
        edition.reduceEditionMaxMintable(editionMaxMintable);

        address[] memory to = new address[](3);
        to[0] = address(10000000);
        to[1] = address(10000001);
        to[2] = address(10000002);

        uint256 quantity = 4;
        // Reverts if the `quantity * to.length > editionMaxMintable`.
        vm.expectRevert(
            abi.encodeWithSelector(ISoundEditionV1.ExceedsEditionAvailableSupply.selector, editionMaxMintable)
        );
        edition.airdrop(to, quantity);

        // Otherwise, succeeds.
        quantity = 3;
        edition.airdrop(to, quantity);
    }

    function test_airdropSetsMintRandomness() external {
        SoundEditionV1 edition = createGenericEdition();

        address[] memory to = new address[](3);
        to[0] = address(10000000);
        to[1] = address(10000001);
        to[2] = address(10000002);

        bytes9 mintRandomnessBefore = edition.mintRandomness();
        edition.airdrop(to, 1);
        bytes9 mintRandomnessAfter = edition.mintRandomness();
        // Super unlikely to be the same.
        assertTrue(mintRandomnessBefore != mintRandomnessAfter);
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
}
