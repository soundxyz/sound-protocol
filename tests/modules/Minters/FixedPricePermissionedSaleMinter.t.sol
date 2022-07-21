pragma solidity ^0.8.15;

import "../../TestConfig.sol";
import "../../../contracts/SoundEdition/SoundEditionV1.sol";
import "../../../contracts/SoundCreator/SoundCreatorV1.sol";
import "../../../contracts/modules/Minters/FixedPricePermissionedSaleMinter.sol";

contract FixedPricePermissionedSaleMinterTests is TestConfig {
    uint256 constant PRICE = 1;

    uint32 constant MAX_MINTED = 5;

    // prettier-ignore
    event FixedPricePermissionedMintCreated(
        address indexed edition,
        uint256 price,
        address signer,
        uint32 maxMinted
    );

    function _createEditionAndMinter() 
        internal
        returns (SoundEditionV1 edition, FixedPricePermissionedSaleMinter minter)
    {
        edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL)
        );
        
        minter = new FixedPricePermissionedSaleMinter();

        edition.grantRole(edition.MINTER_ROLE(), address(minter));

        minter.createEditionMint(
            address(edition),
            PRICE, 
            edition.owner(),
            MAX_MINTED
        );
    }

    function test_createEditionMintEmitsEvent() public {
        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL)
        );
        
        FixedPricePermissionedSaleMinter minter = new FixedPricePermissionedSaleMinter();

        vm.expectEmit(false, false, false, true);
        
        emit FixedPricePermissionedMintCreated(
            address(edition),
            PRICE,
            edition.owner(),
            MAX_MINTED
        );

        minter.createEditionMint(
            address(edition),
            PRICE, 
            edition.owner(),
            MAX_MINTED
        );
    }

    function test_createEditionMintRevertsIfMintEditionExists() public {
        (SoundEditionV1 edition, FixedPricePermissionedSaleMinter minter) = _createEditionAndMinter();

        vm.expectRevert(EditionMinter.MintAlreadyExists.selector);

        minter.createEditionMint(
            address(edition),
            PRICE, 
            edition.owner(),
            MAX_MINTED
        );
    }

    function test_deleteEditionMintRevertsIfCallerUnauthorized() public {
        (SoundEditionV1 edition, FixedPricePermissionedSaleMinter minter) = _createEditionAndMinter();

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert(EditionMinter.MintControllerUnauthorized.selector);
        minter.deleteEditionMint(address(edition));

        minter.setEditionMintController(address(edition), caller);
        vm.prank(caller);
        minter.deleteEditionMint(address(edition));
    }

    function test_deleteEditionMintRevertsIfMintEditionDoesNotExist() public {
        (SoundEditionV1 edition, FixedPricePermissionedSaleMinter minter) = _createEditionAndMinter();

        minter.deleteEditionMint(address(edition));

        vm.expectRevert(EditionMinter.MintNotFound.selector);

        minter.deleteEditionMint(address(edition));
    }

    // function test_mintBeforeStartTimeReverts() public {
    //     (SoundEditionV1 edition, FixedPricePermissionedSaleMinter minter) = _createEditionAndMinter();

    //     vm.warp(START_TIME - 1);

    //     address caller = getRandomAccount(1);
    //     vm.prank(caller);
    //     vm.expectRevert(FixedPricePermissionedSaleMinter.MintNotStarted.selector);
    //     minter.mint{ value: PRICE }(address(edition), 1);

    //     vm.warp(START_TIME);
    //     vm.prank(caller);
    //     minter.mint{ value: PRICE }(address(edition), 1);
    // }

    // function test_mintAfterStartTimeReverts() public {
    //     (SoundEditionV1 edition, FixedPricePermissionedSaleMinter minter) = _createEditionAndMinter();

    //     vm.warp(END_TIME + 1);

    //     address caller = getRandomAccount(1);
    //     vm.prank(caller);
    //     vm.expectRevert(FixedPricePermissionedSaleMinter.MintHasEnded.selector);
    //     minter.mint{ value: PRICE }(address(edition), 1);

    //     vm.warp(END_TIME);
    //     vm.prank(caller);
    //     minter.mint{ value: PRICE }(address(edition), 1);
    // }

    // function test_mintDuringOutOfStockReverts() public {
    //     (SoundEditionV1 edition, FixedPricePermissionedSaleMinter minter) = _createEditionAndMinter();

    //     vm.warp(START_TIME);

    //     address caller = getRandomAccount(1);
    //     vm.prank(caller);
    //     vm.expectRevert(FixedPricePermissionedSaleMinter.MintOutOfStock.selector);
    //     minter.mint{ value: PRICE * (MAX_MINTED + 1) }(address(edition), MAX_MINTED + 1);

    //     vm.prank(caller);
    //     minter.mint{ value: PRICE * MAX_MINTED }(address(edition), MAX_MINTED);

    //     vm.prank(caller);
    //     vm.expectRevert(FixedPricePermissionedSaleMinter.MintOutOfStock.selector);
    //     minter.mint{ value: PRICE }(address(edition), 1);
    // }

    // function test_mintWithWrongEtherValueReverts() public {
    //     (SoundEditionV1 edition, FixedPricePermissionedSaleMinter minter) = _createEditionAndMinter();

    //     vm.warp(START_TIME);

    //     address caller = getRandomAccount(1);
    //     vm.prank(caller);
    //     vm.expectRevert(FixedPricePermissionedSaleMinter.MintWithWrongEtherValue.selector);
    //     minter.mint{ value: PRICE * 2 }(address(edition), 1);
    // }

    // function test_mintWithUnauthorizedMinterReverts() public {
    //     (SoundEditionV1 edition, FixedPricePermissionedSaleMinter minter) = _createEditionAndMinter();
        
    //     vm.warp(START_TIME);
        
    //     address caller = getRandomAccount(1);

    //     bool status;

    //     vm.prank(caller);
    //     (status, ) = address(minter).call{ value: PRICE }(
    //         abi.encodeWithSelector(
    //             FixedPricePermissionedSaleMinter.mint.selector,
    //             address(edition), 
    //             1
    //         )
    //     );
    //     assertTrue(status);

    //     vm.prank(edition.owner());
    //     edition.revokeRole(edition.MINTER_ROLE(), address(minter));

    //     vm.prank(caller);
    //     (status, ) = address(minter).call{ value: PRICE }(
    //         abi.encodeWithSelector(
    //             FixedPricePermissionedSaleMinter.mint.selector,
    //             address(edition), 
    //             1
    //         )
    //     );
    //     assertFalse(status);
    // }
}
