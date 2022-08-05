pragma solidity ^0.8.15;

import "../../TestConfig.sol";
import "../../../contracts/modules/Minters/MintControllerBase.sol";
import "../../../contracts/SoundEdition/SoundEditionV1.sol";
import "../../../contracts/SoundCreator/SoundCreatorV1.sol";

contract MintControllerBaseTests is TestConfig, MintControllerBase {
    function _createEdition() internal returns (SoundEditionV1 edition) {
        edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI, GUARDIAN)
        );
    }

    function createEditionMintController(address edition) external {
        _createEditionMintController(edition);
    }

    function deleteEditionMintController(address edition) external {
        _deleteEditionMintController(edition);
    }

    function test_createEditionMintControllerEmitsEvent() external {
        SoundEditionV1 edition = _createEdition();

        vm.expectEmit(false, false, false, true);
        emit MintControllerUpdated(address(edition), edition.owner());
        this.createEditionMintController(address(edition));
    }

    function test_createEditionMintControllerRevertsIfCallerNotEditionOwner() external {
        SoundEditionV1 edition = _createEdition();
        address attacker = getRandomAccount(1);

        vm.expectRevert(MintControllerBase.CallerNotEditionOwner.selector);
        vm.prank(attacker);
        this.createEditionMintController(address(edition));
    }

    function test_createEditionMintControllerRevertsIfEditionDoesNotImplementOwner() external {
        vm.expectRevert(MintControllerBase.CallerNotEditionOwner.selector);
        this.createEditionMintController(address(0));
    }

    function test_createEditionMintControllerChangesController() external {
        SoundEditionV1 edition = _createEdition();

        assertEq(this.editionMintController(address(edition)), address(0));

        this.createEditionMintController(address(edition));
        assertEq(this.editionMintController(address(edition)), edition.owner());
    }

    function test_createEditionMintControllerRevertsWhenAlreadyExists() external {
        address controller0 = getRandomAccount(0);
        vm.prank(controller0);
        SoundEditionV1 edition = _createEdition();
        assertEq(edition.owner(), controller0);

        address controller1 = getRandomAccount(1);

        vm.prank(controller0);
        this.createEditionMintController(address(edition));

        // Try calling with `controller0`, should revert with {MintControllerAlreadyExists},
        // since the controller has already been registered.
        vm.expectRevert(abi.encodeWithSelector(MintControllerBase.MintControllerAlreadyExists.selector, controller0));
        vm.prank(controller0);
        this.createEditionMintController(address(edition));

        // Try calling with `controller1`, should revert with {CallerNotEditionOwner}.
        vm.prank(controller1);
        vm.expectRevert(MintControllerBase.CallerNotEditionOwner.selector);
        this.createEditionMintController(address(edition));

        // Transfer ownership of the `edition` to `controller1`.
        vm.prank(controller0);
        edition.transferOwnership(controller1);

        // Try calling with `controller1`, should revert with {MintControllerAlreadyExists}.
        vm.prank(controller1);
        vm.expectRevert(abi.encodeWithSelector(MintControllerBase.MintControllerAlreadyExists.selector, controller0));
        this.createEditionMintController(address(edition));
    }

    function test_setEditionMintControllerEmitsEvent() external {
        SoundEditionV1 edition = _createEdition();
        address newController = getRandomAccount(1);

        this.createEditionMintController(address(edition));

        vm.expectEmit(false, false, false, true);
        emit MintControllerUpdated(address(edition), newController);
        this.setEditionMintController(address(edition), newController);
    }

    function test_setEditionMintControllerChangesController() external {
        SoundEditionV1 edition = _createEdition();
        address newController = getRandomAccount(1);

        this.createEditionMintController(address(edition));

        this.setEditionMintController(address(edition), newController);
        assertEq(this.editionMintController(address(edition)), newController);
    }

    function test_deleteEditionMintControllerEmitsEvent() external {
        SoundEditionV1 edition = _createEdition();

        this.createEditionMintController(address(edition));

        vm.expectEmit(false, false, false, true);
        emit MintControllerUpdated(address(edition), address(0));
        this.deleteEditionMintController(address(edition));
    }

    function test_deleteEditionMintRevertsIfCallerUnauthorized() public {
        SoundEditionV1 edition = _createEdition();
        address attacker = getRandomAccount(1);

        this.createEditionMintController(address(edition));

        vm.prank(attacker);
        vm.expectRevert(MintControllerBase.MintControllerUnauthorized.selector);
        this.deleteEditionMintController(address(edition));
    }

    function test_deleteEditionMintRevertsIfMintEditionDoesNotExist() public {
        SoundEditionV1 edition0 = _createEdition();
        SoundEditionV1 edition1 = _createEdition();

        address controller = getRandomAccount(0);

        this.createEditionMintController(address(edition0));

        vm.prank(controller);
        vm.expectRevert(MintControllerBase.MintControllerNotFound.selector);
        this.deleteEditionMintController(address(edition1));
    }

    function test_deleteEditionMintControllerChangesControllerToZeroAddress() external {
        SoundEditionV1 edition = _createEdition();

        this.createEditionMintController(address(edition));
        assertEq(this.editionMintController(address(edition)), edition.owner());

        this.deleteEditionMintController(address(edition));
        assertEq(this.editionMintController(address(edition)), address(0));
    }

    function test_adminMintRevertsIfNotAuthorized(address nonAdminOrOwner) public {
        vm.assume(nonAdminOrOwner != address(this));
        vm.assume(nonAdminOrOwner != address(0));

        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI, GUARDIAN)
        );

        this.createEditionMintController(address(edition));

        edition.grantRole(edition.MINTER_ROLE(), address(this));

        vm.expectRevert(SoundEditionV1.Unauthorized.selector);

        vm.prank(nonAdminOrOwner);
        this.adminMint(edition, nonAdminOrOwner, 1);
    }

    function test_adminMintSuccess() public {
        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI, GUARDIAN)
        );

        // Register the edition
        this.createEditionMintController(address(edition));

        // Test owner can mint to own address
        address owner = address(12345);
        edition.transferOwnership(owner);

        // Give this minter the minter role
        edition.grantRole(edition.MINTER_ROLE(), address(this));

        // Since we're testing the MintControllerBase, we're not setting a max quantity, so this number can be anything up to uint32.max;
        uint32 quantity = 307023923;

        vm.prank(owner);
        this.adminMint(edition, owner, quantity);

        assert(edition.balanceOf(owner) == quantity);

        // Test owner can mint to a recipient address
        address recipient1 = address(39730);
        edition.transferOwnership(owner);

        vm.prank(owner);
        this.adminMint(edition, recipient1, quantity);

        assert(edition.balanceOf(recipient1) == quantity);

        // Test an admin can mint to own address
        address admin = address(54321);

        edition.grantRole(edition.MINTER_ROLE(), address(this));
        edition.grantRole(edition.ADMIN_ROLE(), admin);

        vm.prank(admin);
        this.adminMint(edition, admin, 420);

        assert(edition.balanceOf(admin) == 420);

        // Test an admin can mint to a recipient address
        address recipient2 = address(837802);
        vm.prank(admin);
        this.adminMint(edition, recipient2, quantity);

        assert(edition.balanceOf(recipient2) == quantity);
    }
}
