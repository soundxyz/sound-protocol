pragma solidity ^0.8.15;

import "../../TestConfig.sol";
import "../../../contracts/SoundEdition/SoundEditionV1.sol";
import "../../../contracts/SoundCreator/SoundCreatorV1.sol";
import "../../../contracts/modules/Minters/MintControllerBase.sol";

contract MintControllerBaseTests is TestConfig, MintControllerBase {
    function _createEdition() internal returns (SoundEditionV1 edition) {
        edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        edition.grantRole(edition.MINTER_ROLE(), address(this));
    }

    function createEditionMintController(address edition) external {
        _createEditionMintController(edition);
    }

    function deleteEditionMintController(address edition) external {
        _deleteEditionMintController(edition);
    }

    function onlyEditionMintControllerAction(address edition) external onlyEditionMintController(edition) {}

    function mint(address edition, uint32 quantity, uint256 price) external payable {
        _requireExactPayment(quantity * price);
        _requireMintNotPaused(edition);
        ISoundEditionV1(edition).mint{ value: msg.value }(msg.sender, quantity);
    }

    function test_createEditionMintControllerEmitsEvent() external {
        address controller = getRandomAccount(0);
        vm.startPrank(controller);

        SoundEditionV1 edition = _createEdition();

        vm.expectEmit(false, false, false, true);
        emit MintControllerSet(address(edition), controller);
        this.createEditionMintController(address(edition));

        vm.stopPrank();
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
        vm.startPrank(controller0);

        SoundEditionV1 edition = _createEdition();
        assertEq(edition.owner(), controller0);

        address controller1 = getRandomAccount(1);

        this.createEditionMintController(address(edition));

        // Try calling with `controller0`, should revert with {MintControllerAlreadyExists},
        // since the controller has already been registered.
        vm.expectRevert(abi.encodeWithSelector(MintControllerBase.MintControllerAlreadyExists.selector, controller0));
        this.createEditionMintController(address(edition));

        vm.stopPrank();

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
        emit MintControllerSet(address(edition), newController);
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
        emit MintControllerSet(address(edition), address(0));

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

    function test_deleteEditionMintControllerChangesControllerToZeroAddress() public {
        SoundEditionV1 edition = _createEdition();

        this.createEditionMintController(address(edition));
        assertEq(this.editionMintController(address(edition)), edition.owner());

        this.deleteEditionMintController(address(edition));
        assertEq(this.editionMintController(address(edition)), address(0));
    }

    function test_revertsForWrongEtherValue() public {
        SoundEditionV1 edition = _createEdition();

        this.createEditionMintController(address(edition));

        uint256 price = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                WrongEtherValue.selector,
                price * 2 - 1,
                price * 2
            )
        );
        this.mint{ value: price * 2 - 1 }(address(edition), 2, price);

        this.mint{ value: price * 2 }(address(edition), 2, price);
    }

    function test_revertsWhenPaused() public {
        SoundEditionV1 edition = _createEdition();

        this.createEditionMintController(address(edition));

        this.setEditionMintPaused(address(edition), true);

        uint256 price = 1;
        vm.expectRevert(MintPaused.selector);

        this.mint{ value: price * 2 }(address(edition), 2, price);

        this.setEditionMintPaused(address(edition), false);

        this.mint{ value: price * 2 }(address(edition), 2, price);
    }

    function test_revertsWhenAccessRenounced() public {
        SoundEditionV1 edition = _createEdition();

        this.createEditionMintController(address(edition));

        this.onlyEditionMintControllerAction(address(edition));

        this.renounceEditionMintControllerAccess(address(edition));

        vm.expectRevert(MintControllerUnauthorized.selector);
        this.onlyEditionMintControllerAction(address(edition));
    }
}
