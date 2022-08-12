pragma solidity ^0.8.15;

import "../../TestConfig.sol";
import "../../mocks/MockMinter.sol";
import "../../../contracts/SoundEdition/SoundEditionV1.sol";
import "../../../contracts/SoundCreator/SoundCreatorV1.sol";

contract MintControllerBaseTests is TestConfig {
    event MintControllerSet(address indexed edition, uint256 indexed mintId, address indexed controller);

    MockMinter public minter;

    constructor() {
        minter = new MockMinter();
    }

    function _createEdition(uint32 masterMaxMintable) internal returns (SoundEditionV1 edition) {
        edition = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                masterMaxMintable,
                masterMaxMintable,
                RANDOMNESS_LOCKED_TIMESTAMP
            )
        );

        edition.grantRole(edition.MINTER_ROLE(), address(minter));
    }

    function test_createEditionMintControllerEmitsEvent() external {
        address controller = getRandomAccount(0);
        vm.startPrank(controller);

        SoundEditionV1 edition = _createEdition(MASTER_MAX_MINTABLE);

        uint256 mintId = 0;

        vm.expectEmit(false, false, false, true);
        emit MintControllerSet(address(edition), mintId, controller);
        minter.createEditionMintController(address(edition));

        vm.stopPrank();
    }

    function test_createEditionMintControllerRevertsIfCallerNotEditionOwner() external {
        SoundEditionV1 edition = _createEdition(MASTER_MAX_MINTABLE);
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
        SoundEditionV1 edition = _createEdition(MASTER_MAX_MINTABLE);

        uint256 mintId = 0;

        assertEq(minter.editionMintController(address(edition), mintId), address(0));

        minter.createEditionMintController(address(edition));
        assertEq(minter.editionMintController(address(edition), mintId), edition.owner());
    }

    function test_setEditionMintControllerEmitsEvent() external {
        SoundEditionV1 edition = _createEdition(MASTER_MAX_MINTABLE);
        address newController = getRandomAccount(1);

        uint256 mintId = minter.createEditionMintController(address(edition));

        vm.expectEmit(false, false, false, true);
        emit MintControllerSet(address(edition), mintId, newController);
        minter.setEditionMintController(address(edition), mintId, newController);
    }

    function test_setEditionMintControllerChangesController() external {
        SoundEditionV1 edition = _createEdition(MASTER_MAX_MINTABLE);
        address newController = getRandomAccount(1);

        uint256 mintId = minter.createEditionMintController(address(edition));

        minter.setEditionMintController(address(edition), mintId, newController);
        assertEq(minter.editionMintController(address(edition), mintId), newController);
    }

    function test_deleteEditionMintControllerEmitsEvent() external {
        SoundEditionV1 edition = _createEdition(MASTER_MAX_MINTABLE);

        uint256 mintId = minter.createEditionMintController(address(edition));

        vm.expectEmit(false, false, false, true);
        emit MintControllerSet(address(edition), mintId, address(0));

        minter.deleteEditionMintController(address(edition), mintId);
    }

    function test_deleteEditionMintRevertsIfCallerUnauthorized() public {
        SoundEditionV1 edition = _createEdition(MASTER_MAX_MINTABLE);
        address attacker = getRandomAccount(1);

        uint256 mintId = minter.createEditionMintController(address(edition));

        vm.prank(attacker);
        vm.expectRevert(MintControllerBase.MintControllerUnauthorized.selector);
        minter.deleteEditionMintController(address(edition), mintId);
    }

    function test_deleteEditionMintRevertsIfMintEditionDoesNotExist() public {
        SoundEditionV1 edition0 = _createEdition(MASTER_MAX_MINTABLE);
        SoundEditionV1 edition1 = _createEdition(MASTER_MAX_MINTABLE);

        address controller = getRandomAccount(0);

        uint256 mintId = minter.createEditionMintController(address(edition0));

        vm.prank(controller);
        vm.expectRevert(MintControllerBase.MintControllerNotFound.selector);
        minter.deleteEditionMintController(address(edition1), mintId);
    }

    function test_deleteEditionMintControllerChangesControllerToZeroAddress() public {
        SoundEditionV1 edition = _createEdition(MASTER_MAX_MINTABLE);

        uint256 mintId = minter.createEditionMintController(address(edition));
        assertEq(minter.editionMintController(address(edition), mintId), edition.owner());

        minter.deleteEditionMintController(address(edition), mintId);
        assertEq(minter.editionMintController(address(edition), mintId), address(0));
    }

    function test_mintRevertsForWrongEtherValue() public {
        SoundEditionV1 edition = _createEdition(MASTER_MAX_MINTABLE);

        uint256 mintId = minter.createEditionMintController(address(edition));

        uint256 price = 1;
        vm.expectRevert(abi.encodeWithSelector(MintControllerBase.WrongEtherValue.selector, price * 2 - 1, price * 2));
        minter.mint{ value: price * 2 - 1 }(address(edition), mintId, 2, price);

        minter.mint{ value: price * 2 }(address(edition), mintId, 2, price);
    }

    function test_mintRevertsWhenPaused() public {
        SoundEditionV1 edition = _createEdition(MASTER_MAX_MINTABLE);

        uint256 mintId = minter.createEditionMintController(address(edition));

        minter.setEditionMintPaused(address(edition), mintId, true);

        uint256 price = 1;
        vm.expectRevert(MintControllerBase.MintPaused.selector);

        minter.mint{ value: price * 2 }(address(edition), mintId, 2, price);

        minter.setEditionMintPaused(address(edition), mintId, false);

        minter.mint{ value: price * 2 }(address(edition), mintId, 2, price);
    }

    function test_mintRevertsWithZeroQuantity() public {
        SoundEditionV1 edition = _createEdition(MASTER_MAX_MINTABLE);

        uint256 mintId = minter.createEditionMintController(address(edition));

        vm.expectRevert(IERC721AUpgradeable.MintZeroQuantity.selector);

        minter.mint{ value: 0 }(address(edition), mintId, 0, 0);
    }

    function test_createEditionMintControllerMultipleTimes() external {
        SoundEditionV1 edition = _createEdition(MASTER_MAX_MINTABLE);

        for (uint256 i; i < 3; ++i) {
            uint256 mintId = minter.createEditionMintController(address(edition));
            assertEq(mintId, i);
        }
    }

    function test_cantMintPastMasterMaxMintable() external {
        uint32 maxSupply = 5000;

        SoundEditionV1 edition1 = _createEdition(maxSupply);

        uint256 mintId1 = minter.createEditionMintController(address(edition1));

        // Mint the max supply
        minter.mint(address(edition1), mintId1, maxSupply, 0);

        // try minting 1 more
        vm.expectRevert(SoundEditionV1.MasterMaxMintableReached.selector);
        minter.mint(address(edition1), mintId1, 1, 0);
    }
}
