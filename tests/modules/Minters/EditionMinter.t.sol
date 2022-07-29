pragma solidity ^0.8.15;

import "../../TestConfig.sol";
import "../../../contracts/SoundEdition/SoundEditionV1.sol";
import "../../../contracts/SoundCreator/SoundCreatorV1.sol";
import "../../../contracts/modules/Minters/FixedPricePublicSaleMinter.sol";

contract EditionMinterTests is TestConfig, EditionMinter {
    function createEditionMintController(address edition) external {
        _createEditionMintController(edition);
    }

    function deleteEditionMintController(address edition) external {
        _deleteEditionMintController(edition);
    }

    function test_createEditionMintControllerEmitsEvent(address edition) external {
        address controller = getRandomAccount(1);
        vm.expectEmit(false, false, false, true);
        emit MintControllerUpdated(address(edition), controller);
        vm.prank(controller);
        this.createEditionMintController(address(edition));
    }

    function test_createEditionMintControllerChangesController(address edition) external {
        address controller = getRandomAccount(1);
        assertEq(this.editionMintController(edition), address(0));
        vm.prank(controller);
        this.createEditionMintController(address(edition));
        assertEq(this.editionMintController(edition), controller);
    }

    function test_createEditionMintControllerRevertsWhenAlreadyExists(address edition) external {
        address controller0 = getRandomAccount(0);
        address controller1 = getRandomAccount(1);
        vm.prank(controller0);
        this.createEditionMintController(address(edition));
        vm.expectRevert(abi.encodeWithSelector(EditionMinter.MintControllerAlreadyExists.selector, controller0));
        vm.prank(controller0);
        this.createEditionMintController(address(edition));
        vm.prank(controller1);
        vm.expectRevert(abi.encodeWithSelector(EditionMinter.MintControllerAlreadyExists.selector, controller0));
        this.createEditionMintController(address(edition));
    }

    function test_setEditionMintControllerEmitsEvent(address edition) external {
        address controller0 = getRandomAccount(0);
        address controller1 = getRandomAccount(1);
        vm.prank(controller0);
        this.createEditionMintController(address(edition));
        vm.expectEmit(false, false, false, true);
        emit MintControllerUpdated(address(edition), controller1);
        vm.prank(controller0);
        this.setEditionMintController(address(edition), controller1);
    }

    function test_setEditionMintControllerChangesController(address edition) external {
        address controller0 = getRandomAccount(0);
        address controller1 = getRandomAccount(1);
        vm.prank(controller0);
        this.createEditionMintController(address(edition));
        vm.prank(controller0);
        this.setEditionMintController(address(edition), controller1);
        assertEq(this.editionMintController(edition), controller1);
    }

    function test_deleteEditionMintControllerEmitsEvent(address edition) external {
        address controller = getRandomAccount(0);
        vm.prank(controller);
        this.createEditionMintController(address(edition));
        vm.expectEmit(false, false, false, true);
        emit MintControllerUpdated(address(edition), address(0));
        vm.prank(controller);
        this.deleteEditionMintController(address(edition));
    }

    function test_deleteEditionMintRevertsIfCallerUnauthorized(address edition) public {
        address controller0 = getRandomAccount(0);
        address controller1 = getRandomAccount(1);
        vm.prank(controller0);
        this.createEditionMintController(address(edition));

        vm.prank(controller1);
        vm.expectRevert(EditionMinter.MintControllerUnauthorized.selector);
        this.deleteEditionMintController(address(edition));
    }

    function test_deleteEditionMintRevertsIfMintEditionDoesNotExist(address edition0, address edition1) public {
        vm.assume(edition0 != edition1);

        address controller = getRandomAccount(0);
        vm.prank(controller);
        this.createEditionMintController(address(edition0));

        vm.prank(controller);
        vm.expectRevert(EditionMinter.MintControllerNotFound.selector);
        this.deleteEditionMintController(address(edition1));
    }
}
