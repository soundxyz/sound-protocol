pragma solidity ^0.8.15;

import "../../TestConfig.sol";
import "../../../contracts/SoundEdition/SoundEditionV1.sol";
import "../../../contracts/SoundCreator/SoundCreatorV1.sol";
import "../../../contracts/modules/Minters/FixedPricePublicSaleMinter.sol";

contract FixedPricePublicSaleMinterTests is TestConfig {
    uint256 constant PRICE = 1;

    uint32 constant START_TIME = 100;

    uint32 constant END_TIME = 200;

    uint32 constant MAX_MINTED = 5;

    // prettier-ignore
    event FixedPricePublicSaleMintCreated(
        address indexed edition,
        uint256 price,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMinted
    );

    function _createEditionAndMinter() internal returns (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) {
        edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        minter = new FixedPricePublicSaleMinter();

        edition.grantRole(edition.MINTER_ROLE(), address(minter));

        minter.createEditionMint(address(edition), PRICE, START_TIME, END_TIME, MAX_MINTED);
    }

    function test_createEditionMintEmitsEvent() public {
        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        FixedPricePublicSaleMinter minter = new FixedPricePublicSaleMinter();

        vm.expectEmit(false, false, false, true);

        emit FixedPricePublicSaleMintCreated(address(edition), PRICE, START_TIME, END_TIME, MAX_MINTED);

        minter.createEditionMint(address(edition), PRICE, START_TIME, END_TIME, MAX_MINTED);
    }

    function test_mintBeforeStartTimeReverts() public {
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEditionAndMinter();

        vm.warp(START_TIME - 1);

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert(FixedPricePublicSaleMinter.MintNotStarted.selector);
        minter.mint{ value: PRICE }(address(edition), 1);

        vm.warp(START_TIME);
        vm.prank(caller);
        minter.mint{ value: PRICE }(address(edition), 1);
    }

    function test_mintAfterEndTimeReverts() public {
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEditionAndMinter();

        vm.warp(END_TIME + 1);

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert(FixedPricePublicSaleMinter.MintHasEnded.selector);
        minter.mint{ value: PRICE }(address(edition), 1);

        vm.warp(END_TIME);
        vm.prank(caller);
        minter.mint{ value: PRICE }(address(edition), 1);
    }

    function test_mintWhenSoldOutReverts() public {
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEditionAndMinter();

        vm.warp(START_TIME);

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert(FixedPricePublicSaleMinter.SoldOut.selector);
        minter.mint{ value: PRICE * (MAX_MINTED + 1) }(address(edition), MAX_MINTED + 1);

        vm.prank(caller);
        minter.mint{ value: PRICE * MAX_MINTED }(address(edition), MAX_MINTED);

        vm.prank(caller);
        vm.expectRevert(FixedPricePublicSaleMinter.SoldOut.selector);
        minter.mint{ value: PRICE }(address(edition), 1);
    }

    function test_mintWithWrongEtherValueReverts() public {
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEditionAndMinter();

        vm.warp(START_TIME);

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                MintControllerBase.WrongEtherValue.selector,
                PRICE * 2,
                PRICE
            )
        );
        minter.mint{ value: PRICE * 2 }(address(edition), 1);
    }

    function test_mintWithUnauthorizedMinterReverts() public {
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEditionAndMinter();

        vm.warp(START_TIME);

        address caller = getRandomAccount(1);

        bool status;

        vm.prank(caller);
        (status, ) = address(minter).call{ value: PRICE }(
            abi.encodeWithSelector(FixedPricePublicSaleMinter.mint.selector, address(edition), 1)
        );
        assertTrue(status);

        vm.prank(edition.owner());
        edition.revokeRole(edition.MINTER_ROLE(), address(minter));

        vm.prank(caller);
        (status, ) = address(minter).call{ value: PRICE }(
            abi.encodeWithSelector(FixedPricePublicSaleMinter.mint.selector, address(edition), 1)
        );
        assertFalse(status);
    }
}
