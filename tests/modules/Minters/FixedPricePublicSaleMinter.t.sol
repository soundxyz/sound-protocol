pragma solidity ^0.8.15;

import "../../TestConfig.sol";
import "../../../contracts/SoundEdition/SoundEditionV1.sol";
import "../../../contracts/SoundCreator/SoundCreatorV1.sol";
import "../../../contracts/modules/Minters/FixedPricePublicSaleMinter.sol";

contract FixedPricePublicSaleMinterTests is TestConfig {
    uint256 constant PRICE = 1;

    uint32 constant START_TIME = 100;

    uint32 constant END_TIME = 200;

    uint32 constant MAX_MINTABLE = 5;

    uint32 constant MINT_ID = 0;

    // prettier-ignore
    event FixedPricePublicSaleMintCreated(
        address indexed edition,
        uint256 indexed mintId,
        uint256 price,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMintable,
        uint32 maxAllowedPerWallet
    );

    function _createEditionAndMinter(uint32 _maxAllowedPerWallet)
        internal
        returns (SoundEditionV1 edition, FixedPricePublicSaleMinter minter)
    {
        edition = createGenericEdition();

        minter = new FixedPricePublicSaleMinter();

        edition.grantRole(edition.MINTER_ROLE(), address(minter));

        minter.createEditionMint(address(edition), PRICE, START_TIME, END_TIME, MAX_MINTABLE, _maxAllowedPerWallet);
    }

    function test_createEditionMintEmitsEvent() public {
        SoundEditionV1 edition = createGenericEdition();

        FixedPricePublicSaleMinter minter = new FixedPricePublicSaleMinter();

        vm.expectEmit(false, false, false, true);

        emit FixedPricePublicSaleMintCreated(address(edition), MINT_ID, PRICE, START_TIME, END_TIME, MAX_MINTABLE, 0);

        minter.createEditionMint(address(edition), PRICE, START_TIME, END_TIME, MAX_MINTABLE, 0);
    }

    function test_mintBeforeStartTimeReverts() public {
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEditionAndMinter(0);

        vm.warp(START_TIME - 1);

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(MintControllerBase.MintNotOpen.selector, block.timestamp, START_TIME, END_TIME)
        );
        minter.mint{ value: PRICE }(address(edition), MINT_ID, 1);

        vm.warp(START_TIME);
        vm.prank(caller);
        minter.mint{ value: PRICE }(address(edition), MINT_ID, 1);
    }

    function test_mintAfterEndTimeReverts() public {
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEditionAndMinter(0);

        vm.warp(END_TIME + 1);

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(MintControllerBase.MintNotOpen.selector, block.timestamp, START_TIME, END_TIME)
        );
        minter.mint{ value: PRICE }(address(edition), MINT_ID, 1);

        vm.warp(END_TIME);
        vm.prank(caller);
        minter.mint{ value: PRICE }(address(edition), MINT_ID, 1);
    }

    function test_mintWhenSoldOutReverts() public {
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEditionAndMinter(0);

        vm.warp(START_TIME);

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(MintControllerBase.SoldOut.selector, MAX_MINTABLE));
        minter.mint{ value: PRICE * (MAX_MINTABLE + 1) }(address(edition), MINT_ID, MAX_MINTABLE + 1);

        vm.prank(caller);
        minter.mint{ value: PRICE * MAX_MINTABLE }(address(edition), MINT_ID, MAX_MINTABLE);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(MintControllerBase.SoldOut.selector, MAX_MINTABLE));
        minter.mint{ value: PRICE }(address(edition), MINT_ID, 1);
    }

    function test_mintWithWrongEtherValueReverts() public {
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEditionAndMinter(0);

        vm.warp(START_TIME);

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(MintControllerBase.WrongEtherValue.selector, PRICE * 2, PRICE));
        minter.mint{ value: PRICE * 2 }(address(edition), MINT_ID, 1);
    }

    function test_mintWithUnauthorizedMinterReverts() public {
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEditionAndMinter(0);

        vm.warp(START_TIME);

        address caller = getRandomAccount(1);

        bool status;

        vm.prank(caller);
        (status, ) = address(minter).call{ value: PRICE }(
            abi.encodeWithSelector(FixedPricePublicSaleMinter.mint.selector, address(edition), MINT_ID, 1)
        );
        assertTrue(status);

        vm.prank(edition.owner());
        edition.revokeRole(edition.MINTER_ROLE(), address(minter));

        vm.prank(caller);
        (status, ) = address(minter).call{ value: PRICE }(
            abi.encodeWithSelector(FixedPricePublicSaleMinter.mint.selector, address(edition), MINT_ID, 1)
        );
        assertFalse(status);
    }

    function test_mintUpdatesValuesAndEditionCorrectly() public {
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEditionAndMinter(0);

        vm.warp(START_TIME);

        address caller = getRandomAccount(1);

        uint32 quantity = 2;

        FixedPricePublicSaleMinter.EditionMintData memory data = minter.editionMintData(address(edition), MINT_ID);

        assertEq(data.totalMinted, 0);

        vm.prank(caller);
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity);

        assertEq(edition.balanceOf(caller), uint256(quantity));

        data = minter.editionMintData(address(edition), MINT_ID);

        assertEq(data.totalMinted, quantity);
    }

    function test_mintWhenOverMaxAllowedPerWalletReverts() public {
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEditionAndMinter(1);
        vm.warp(START_TIME);

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert(FixedPricePublicSaleMinter.ExceedsMaxPerWallet.selector);
        minter.mint{ value: PRICE * 2 }(address(edition), MINT_ID, 2);
    }

    function test_mintWhenAllowedPerWalletIsSetAndSatisfied() public {
        // Set max allowed per wallet to 2
        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEditionAndMinter(2);

        // Ensure we can mint the max allowed of 2 tokens
        address caller = getRandomAccount(1);
        vm.warp(START_TIME);
        vm.prank(caller);
        minter.mint{ value: PRICE * 2 }(address(edition), MINT_ID, 2);

        assertEq(edition.balanceOf(caller), 2);

        FixedPricePublicSaleMinter.EditionMintData memory data = minter.editionMintData(address(edition), MINT_ID);
        assertEq(data.totalMinted, 2);
    }
}
