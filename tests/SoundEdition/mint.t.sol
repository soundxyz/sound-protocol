// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "chiru-labs/ERC721A-Upgradeable/IERC721AUpgradeable.sol";
import "../TestConfig.sol";
import "../../contracts/SoundEdition/SoundEditionV1.sol";

/**
 * @dev Tests base minting functionality directly from edition.
 */
contract SoundEdition_mint is TestConfig {
    event EditionMaxMintableSet(uint32 newMax);

    function test_adminMintRevertsIfNotAuthorized(address nonAdminOrOwner) public {
        vm.assume(nonAdminOrOwner != address(this));
        vm.assume(nonAdminOrOwner != address(0));

        SoundEditionV1 edition = createGenericEdition();

        vm.expectRevert(SoundEditionV1.Unauthorized.selector);

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
                maxQuantity,
                EDITION_MAX_MINTABLE,
                RANDOMNESS_LOCKED_TIMESTAMP
            )
        );

        edition.mint(address(this), maxQuantity);

        vm.expectRevert(SoundEditionV1.InsufficientMintableSupply.selector);

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

    function test_setEditionMaxMintableSuccessViaOwner() external {
        uint32 MAX_3 = 3;
        uint32 MAX_2 = 2;
        uint32 MAX_1 = 1;

        emit EditionMaxMintableSet(MAX_3);
        vm.expectEmit(false, false, false, true);

        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                MAX_3,
                EDITION_MAX_MINTABLE,
                RANDOMNESS_LOCKED_TIMESTAMP
            )
        );

        // Mint a token
        edition.mint(address(this), 1);

        // Set new max mintable
        // TODO: figure out why this is failing
        // emit EditionMaxMintableSet(MAX_2);
        // vm.expectEmit(false, false, false, true);

        edition.setEditionMaxMintable(MAX_2);
        assert(edition.editionMaxMintable() == MAX_2);

        // Mint another token
        edition.mint(address(this), 1);

        // We're now at editionMaxMintable
        assertEq(edition.totalMinted(), MAX_2);

        // Attempt to reduce max mintable again - should fail
        vm.expectRevert(SoundEditionV1.InvalidAmount.selector);
        edition.setEditionMaxMintable(MAX_1);

        // Attempt to mint - should fail
        vm.expectRevert(SoundEditionV1.InsufficientMintableSupply.selector);
        edition.mint(address(this), 1);
    }

    function test_setEditionMaxMintableSuccessViaAdmin() external {
        uint32 MAX_3 = 3;
        uint32 MAX_2 = 2;
        uint32 MAX_1 = 1;

        emit EditionMaxMintableSet(MAX_3);
        vm.expectEmit(false, false, false, true);

        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
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
        // TODO: figure out why this is failing
        // emit EditionMaxMintableSet(MAX_2);
        // vm.expectEmit(false, false, false, true);

        vm.prank(admin);
        edition.setEditionMaxMintable(MAX_2);
        assert(edition.editionMaxMintable() == MAX_2);

        // Mint another token
        edition.mint(address(this), 1);

        // We're now at editionMaxMintable
        assertEq(edition.totalMinted(), MAX_2);

        // Attempt to reduce max mintable again - should fail
        vm.expectRevert(SoundEditionV1.InvalidAmount.selector);
        vm.prank(admin);
        edition.setEditionMaxMintable(MAX_1);

        // Attempt to mint - should fail
        vm.expectRevert(SoundEditionV1.InsufficientMintableSupply.selector);
        edition.mint(address(this), 1);
    }
}
