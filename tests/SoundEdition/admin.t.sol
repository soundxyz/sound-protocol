// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "../TestConfig.sol";
import "../../contracts/SoundEdition/SoundEditionV1.sol";

contract SoundEdition_admin is TestConfig {
    event EditionMaxMintableSet(uint32 editionMaxMintable);

    function test_adminMintRevertsIfNotAuthorized(address nonAdminOrOwner) public {
        vm.assume(nonAdminOrOwner != address(this));
        vm.assume(nonAdminOrOwner != address(0));

        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                MASTER_MAX_MINTABLE
            )
        );

        vm.expectRevert(SoundEditionV1.Unauthorized.selector);

        vm.prank(nonAdminOrOwner);
        edition.mint(nonAdminOrOwner, 1);
    }

    function test_adminMintCantMintPastMax() public {
        uint32 maxQuantity = 5000;

        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI, maxQuantity)
        );

        edition.mint(address(this), maxQuantity);

        vm.expectRevert(SoundEditionV1.MaxSupplyReached.selector);

        edition.mint(address(this), 1);
    }

    function test_adminMintSuccess() public {
        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                MASTER_MAX_MINTABLE
            )
        );

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

    // Tests that edition max supply can't be increased.
    function test_setMaxRevertsIfAmountInvalid() external {
        uint32 max = 10000;

        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI, max)
        );

        vm.expectRevert(SoundEditionV1.InvalidAmount.selector);
        edition.setMaxMintable(max + 1);
    }

    function test_setMaxRevertsIfCallerUnauthorized(address attacker) external {
        vm.assume(attacker != address(this));

        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                MASTER_MAX_MINTABLE
            )
        );

        vm.expectRevert(SoundEditionV1.Unauthorized.selector);

        vm.prank(attacker);
        edition.setMaxMintable(1);
    }

    function test_setMaxMintableSuccess() external {
        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                MASTER_MAX_MINTABLE
            )
        );

        /**
         * Owner can set max
         */
        uint32 newMax = 69;

        vm.expectEmit(false, false, false, true);

        emit EditionMaxMintableSet(newMax);

        edition.setMaxMintable(newMax);
        assert(edition.editionMaxMintable() == newMax);

        /**
         * Admin can set max
         */

        address admin = address(54321);
        edition.grantRole(edition.ADMIN_ROLE(), admin);

        newMax = 42;

        vm.expectEmit(false, false, false, true);

        emit EditionMaxMintableSet(newMax);

        vm.prank(admin);
        edition.setMaxMintable(newMax);
        assert(edition.editionMaxMintable() == newMax);
    }
}
