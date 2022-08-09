pragma solidity ^0.8.15;

import "../../TestConfig.sol";
import "../../mocks/MockMinter.sol";
import "../../../contracts/SoundEdition/SoundEditionV1.sol";
import "../../../contracts/SoundCreator/SoundCreatorV1.sol";

contract MintControllerBaseTests is TestConfig {
    event MintControllerUpdated(address indexed edition, address indexed controller);

    MockMinter minter;

    constructor() {
        minter = new MockMinter();
    }

    function _createEdition() internal returns (SoundEditionV1 edition) {
        edition = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                MASTER_MAX_MINTABLE
            )
        );
    }

    function test_createEditionMintControllerEmitsEvent() external {
        SoundEditionV1 edition = _createEdition();

        vm.expectEmit(false, false, false, true);
        emit MintControllerUpdated(address(edition), edition.owner());
        minter.createEditionMintController(address(edition));
    }

    function test_createEditionMintControllerRevertsIfCallerNotEditionOwner() external {
        SoundEditionV1 edition = _createEdition();
        address attacker = getRandomAccount(1);

        vm.expectRevert(MintControllerBase.CallerNotEditionOwner.selector);
        vm.prank(attacker);
        minter.createEditionMintController(address(edition));
    }

    function test_createEditionMintControllerRevertsIfEditionDoesNotImplementOwner() external {
        vm.expectRevert(MintControllerBase.CallerNotEditionOwner.selector);
        minter.createEditionMintController(address(0));
    }

    function test_createEditionMintControllerChangesController() external {
        SoundEditionV1 edition = _createEdition();

        assertEq(minter.editionMintController(address(edition)), address(0));

        minter.createEditionMintController(address(edition));
        assertEq(minter.editionMintController(address(edition)), edition.owner());
    }

    function test_createEditionMintControllerRevertsWhenAlreadyExists() external {
        address controller0 = getRandomAccount(0);
        vm.prank(controller0);
        SoundEditionV1 edition = _createEdition();
        assertEq(edition.owner(), controller0);

        address controller1 = getRandomAccount(1);

        vm.prank(controller0);
        minter.createEditionMintController(address(edition));

        // Try calling with `controller0`, should revert with {MintControllerAlreadyExists},
        // since the controller has already been registered.
        vm.expectRevert(abi.encodeWithSelector(MintControllerBase.MintControllerAlreadyExists.selector, controller0));
        vm.prank(controller0);
        minter.createEditionMintController(address(edition));

        // Try calling with `controller1`, should revert with {CallerNotEditionOwner}.
        vm.prank(controller1);
        vm.expectRevert(MintControllerBase.CallerNotEditionOwner.selector);
        minter.createEditionMintController(address(edition));

        // Transfer ownership of the `edition` to `controller1`.
        vm.prank(controller0);
        edition.transferOwnership(controller1);

        // Try calling with `controller1`, should revert with {MintControllerAlreadyExists}.
        vm.prank(controller1);
        vm.expectRevert(abi.encodeWithSelector(MintControllerBase.MintControllerAlreadyExists.selector, controller0));
        minter.createEditionMintController(address(edition));
    }

    function test_setEditionMintControllerEmitsEvent() external {
        SoundEditionV1 edition = _createEdition();
        address newController = getRandomAccount(1);

        minter.createEditionMintController(address(edition));

        vm.expectEmit(false, false, false, true);
        emit MintControllerUpdated(address(edition), newController);
        minter.setEditionMintController(address(edition), newController);
    }

    function test_setEditionMintControllerChangesController() external {
        SoundEditionV1 edition = _createEdition();
        address newController = getRandomAccount(1);

        minter.createEditionMintController(address(edition));

        minter.setEditionMintController(address(edition), newController);
        assertEq(minter.editionMintController(address(edition)), newController);
    }

    function test_deleteEditionMintControllerEmitsEvent() external {
        SoundEditionV1 edition = _createEdition();

        minter.createEditionMintController(address(edition));

        vm.expectEmit(false, false, false, true);
        emit MintControllerUpdated(address(edition), address(0));
        minter.deleteEditionMintController(address(edition));
    }

    function test_deleteEditionMintRevertsIfCallerUnauthorized() public {
        SoundEditionV1 edition = _createEdition();
        address attacker = getRandomAccount(1);

        minter.createEditionMintController(address(edition));

        vm.prank(attacker);
        vm.expectRevert(MintControllerBase.MintControllerUnauthorized.selector);
        minter.deleteEditionMintController(address(edition));
    }

    function test_deleteEditionMintRevertsIfMintEditionDoesNotExist() public {
        SoundEditionV1 edition0 = _createEdition();
        SoundEditionV1 edition1 = _createEdition();

        address controller = getRandomAccount(0);

        minter.createEditionMintController(address(edition0));

        vm.prank(controller);
        vm.expectRevert(MintControllerBase.MintControllerNotFound.selector);
        minter.deleteEditionMintController(address(edition1));
    }

    function test_deleteEditionMintControllerChangesControllerToZeroAddress() external {
        SoundEditionV1 edition = _createEdition();

        minter.createEditionMintController(address(edition));
        assertEq(minter.editionMintController(address(edition)), edition.owner());

        minter.deleteEditionMintController(address(edition));
        assertEq(minter.editionMintController(address(edition)), address(0));
    }

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

        minter.createEditionMintController(address(edition));

        vm.expectRevert(SoundEditionV1.Unauthorized.selector);

        vm.prank(nonAdminOrOwner);
        minter.adminMint(edition, nonAdminOrOwner, 1);
    }

    function test_adminMintCantMintPastMax() public {
        uint32 maxQuantity = 2;

        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI, maxQuantity)
        );

        minter.createEditionMintController(address(edition));

        edition.grantRole(edition.MINTER_ROLE(), address(minter));

        minter.adminMint(edition, address(this), maxQuantity);

        vm.expectRevert(SoundEditionV1.MaxSupplyReached.selector);

        minter.adminMint(edition, address(this), 1);
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

        // Register the edition
        minter.createEditionMintController(address(edition));

        // Test owner can mint to own address
        address owner = address(12345);
        edition.transferOwnership(owner);

        edition.grantRole(edition.MINTER_ROLE(), address(minter));

        uint32 quantity = 307023;

        vm.prank(owner);
        minter.adminMint(edition, owner, quantity);

        assert(edition.balanceOf(owner) == quantity);

        // Test owner can mint to a recipient address
        address recipient1 = address(39730);

        vm.prank(owner);
        minter.adminMint(edition, recipient1, quantity);

        assert(edition.balanceOf(recipient1) == quantity);

        // Test an admin can mint to own address
        address admin = address(54321);

        edition.grantRole(edition.ADMIN_ROLE(), admin);

        vm.prank(admin);
        minter.adminMint(edition, admin, 420);

        assert(edition.balanceOf(admin) == 420);

        // Test an admin can mint to a recipient address
        address recipient2 = address(837802);
        vm.prank(admin);
        minter.adminMint(edition, recipient2, quantity);

        assert(edition.balanceOf(recipient2) == quantity);
    }
}
