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

    function createEditionMintController(address edition) external returns (uint256 mintId) {
        mintId = _createEditionMintController(edition);
    }

    function deleteEditionMintController(address edition, uint256 mintId) external {
        _deleteEditionMintController(edition, mintId);
    }

    function onlyEditionMintControllerAction(address edition, uint256 mintId)
        external
        onlyEditionMintController(edition, mintId)
    {}

    function mint(
        address edition,
        uint256 mintId,
        uint32 quantity,
        uint256 price
    ) external payable {
        _mint(edition, mintId, msg.sender, quantity, quantity * price);
    }

    function test_createEditionMintControllerEmitsEvent() external {
        address controller = getRandomAccount(0);
        vm.startPrank(controller);

        SoundEditionV1 edition = _createEdition();

        uint256 mintId = 0;

        vm.expectEmit(false, false, false, true);
        emit MintControllerSet(address(edition), mintId, controller);
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

        uint256 mintId = 0;

        assertEq(this.editionMintController(address(edition), mintId), address(0));

        this.createEditionMintController(address(edition));
        assertEq(this.editionMintController(address(edition), mintId), edition.owner());
    }

    function test_setEditionMintControllerEmitsEvent() external {
        SoundEditionV1 edition = _createEdition();
        address newController = getRandomAccount(1);

        uint256 mintId = this.createEditionMintController(address(edition));

        vm.expectEmit(false, false, false, true);
        emit MintControllerSet(address(edition), mintId, newController);
        this.setEditionMintController(address(edition), mintId, newController);
    }

    function test_setEditionMintControllerChangesController() external {
        SoundEditionV1 edition = _createEdition();
        address newController = getRandomAccount(1);

        uint256 mintId = this.createEditionMintController(address(edition));

        this.setEditionMintController(address(edition), mintId, newController);
        assertEq(this.editionMintController(address(edition), mintId), newController);
    }

    function test_deleteEditionMintControllerEmitsEvent() external {
        SoundEditionV1 edition = _createEdition();

        uint256 mintId = this.createEditionMintController(address(edition));

        vm.expectEmit(false, false, false, true);
        emit MintControllerSet(address(edition), mintId, address(0));

        this.deleteEditionMintController(address(edition), mintId);
    }

    function test_deleteEditionMintRevertsIfCallerUnauthorized() public {
        SoundEditionV1 edition = _createEdition();
        address attacker = getRandomAccount(1);

        uint256 mintId = this.createEditionMintController(address(edition));

        vm.prank(attacker);
        vm.expectRevert(MintControllerBase.MintControllerUnauthorized.selector);
        this.deleteEditionMintController(address(edition), mintId);
    }

    function test_deleteEditionMintRevertsIfMintEditionDoesNotExist() public {
        SoundEditionV1 edition0 = _createEdition();
        SoundEditionV1 edition1 = _createEdition();

        address controller = getRandomAccount(0);

        uint256 mintId = this.createEditionMintController(address(edition0));

        vm.prank(controller);
        vm.expectRevert(MintControllerBase.MintControllerNotFound.selector);
        this.deleteEditionMintController(address(edition1), mintId);
    }

    function test_deleteEditionMintControllerChangesControllerToZeroAddress() public {
        SoundEditionV1 edition = _createEdition();

        uint256 mintId = this.createEditionMintController(address(edition));
        assertEq(this.editionMintController(address(edition), mintId), edition.owner());

        this.deleteEditionMintController(address(edition), mintId);
        assertEq(this.editionMintController(address(edition), mintId), address(0));
    }

    function test_mintRevertsForWrongEtherValue() public {
        SoundEditionV1 edition = _createEdition();

        uint256 mintId = this.createEditionMintController(address(edition));

        uint256 price = 1;
        vm.expectRevert(abi.encodeWithSelector(WrongEtherValue.selector, price * 2 - 1, price * 2));
        this.mint{ value: price * 2 - 1 }(address(edition), mintId, 2, price);

        this.mint{ value: price * 2 }(address(edition), mintId, 2, price);
    }

    function test_mintRevertsWhenPaused() public {
        SoundEditionV1 edition = _createEdition();

        uint256 mintId = this.createEditionMintController(address(edition));

        this.setEditionMintPaused(address(edition), mintId, true);

        uint256 price = 1;
        vm.expectRevert(MintPaused.selector);

        this.mint{ value: price * 2 }(address(edition), mintId, 2, price);

        this.setEditionMintPaused(address(edition), mintId, false);

        this.mint{ value: price * 2 }(address(edition), mintId, 2, price);
    }

    function test_mintRevertsWithZeroQuantity() public {
        SoundEditionV1 edition = _createEdition();

        uint256 mintId = this.createEditionMintController(address(edition));

        vm.expectRevert(IERC721AUpgradeable.MintZeroQuantity.selector);

        this.mint{ value: 0 }(address(edition), mintId, 0, 0);
    }

    function test_createEditionMintControllerMultipleTimes() external {
        SoundEditionV1 edition = _createEdition();

        for (uint256 i; i < 3; ++i) {
            uint256 mintId = this.createEditionMintController(address(edition));
            assertEq(mintId, i);
        }
    }
}
