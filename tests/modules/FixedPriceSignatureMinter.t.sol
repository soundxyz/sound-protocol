pragma solidity ^0.8.16;

import { ECDSA } from "solady/utils/ECDSA.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { FixedPriceSignatureMinter } from "@modules/FixedPriceSignatureMinter.sol";
import { IFixedPriceSignatureMinter } from "@modules/interfaces/IFixedPriceSignatureMinter.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { StandardMintData } from "@core/interfaces/IMinterModule.sol";
import { TestConfig } from "../TestConfig.sol";

contract FixedPriceSignatureMinterTests is TestConfig {
    using ECDSA for bytes32;

    uint256 constant PRICE = 1;
    uint32 constant MAX_MINTABLE = 5;
    uint256 constant SIGNER_PRIVATE_KEY = 1;
    uint256 constant MINT_ID = 0;
    uint32 constant START_TIME = 0;
    uint32 constant END_TIME = type(uint32).max;

    // prettier-ignore
    event FixedPriceSignatureMintCreated(
        address indexed edition,
        uint256 indexed mintId,
        uint256 price,
        address signer,
        uint32 maxMintable
    );

    function _signerAddress() internal returns (address) {
        return vm.addr(SIGNER_PRIVATE_KEY);
    }

    function _getSignature(address caller, address edition) internal returns (bytes memory) {
        bytes32 digest = keccak256(abi.encode(caller, address(edition), MINT_ID)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function _createEditionAndMinter() internal returns (SoundEditionV1 edition, FixedPriceSignatureMinter minter) {
        edition = createGenericEdition();

        minter = new FixedPriceSignatureMinter();

        edition.grantRole(edition.MINTER_ROLE(), address(minter));

        minter.createEditionMint(address(edition), PRICE, _signerAddress(), MAX_MINTABLE, START_TIME, END_TIME);
    }

    function test_createEditionMintEmitsEvent() public {
        SoundEditionV1 edition = createGenericEdition();

        FixedPriceSignatureMinter minter = new FixedPriceSignatureMinter();

        vm.expectEmit(false, false, false, true);

        emit FixedPriceSignatureMintCreated(address(edition), MINT_ID, PRICE, _signerAddress(), MAX_MINTABLE);

        minter.createEditionMint(address(edition), PRICE, _signerAddress(), MAX_MINTABLE, START_TIME, END_TIME);
    }

    function test_createEditionMintRevertsIfSignerIsZeroAddress() public {
        SoundEditionV1 edition = createGenericEdition();

        FixedPriceSignatureMinter minter = new FixedPriceSignatureMinter();

        vm.expectRevert(IFixedPriceSignatureMinter.SignerIsZeroAddress.selector);

        minter.createEditionMint(address(edition), PRICE, address(0), MAX_MINTABLE, START_TIME, END_TIME);
    }

    function test_mintWithoutCorrectSignatureReverts() public {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        address caller = getFundedAccount(1);
        bytes memory sig = _getSignature(caller, address(edition));

        vm.prank(caller);
        minter.mint{ value: PRICE }(address(edition), MINT_ID, 1, sig);

        vm.expectRevert(IFixedPriceSignatureMinter.InvalidSignature.selector);
        minter.mint{ value: PRICE }(address(edition), MINT_ID, 1, sig);
    }

    function test_mintWithWrongEtherValueReverts() public {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        address caller = getFundedAccount(1);
        bytes memory sig = _getSignature(caller, address(edition));

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(IMinterModule.WrongEtherValue.selector, PRICE * 2, PRICE));
        minter.mint{ value: PRICE * 2 }(address(edition), MINT_ID, 1, sig);
    }

    function test_mintWhenSoldOutReverts() public {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        address caller = getFundedAccount(1);
        bytes memory sig = _getSignature(caller, address(edition));

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(IMinterModule.MaxMintableReached.selector, MAX_MINTABLE));
        minter.mint{ value: PRICE * (MAX_MINTABLE + 1) }(address(edition), MINT_ID, MAX_MINTABLE + 1, sig);

        vm.prank(caller);
        minter.mint{ value: PRICE * MAX_MINTABLE }(address(edition), MINT_ID, MAX_MINTABLE, sig);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(IMinterModule.MaxMintableReached.selector, MAX_MINTABLE));
        minter.mint{ value: PRICE }(address(edition), MINT_ID, 1, sig);
    }

    function test_mintWithUnauthorizedMinterReverts() public {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        address caller = getFundedAccount(1);
        bytes memory sig = _getSignature(caller, address(edition));

        bool status;

        vm.prank(caller);
        (status, ) = address(minter).call{ value: PRICE }(
            abi.encodeWithSelector(FixedPriceSignatureMinter.mint.selector, address(edition), MINT_ID, 1, sig)
        );
        assertTrue(status);

        vm.prank(edition.owner());
        edition.revokeRole(edition.MINTER_ROLE(), address(minter));

        vm.prank(caller);
        (status, ) = address(minter).call{ value: PRICE }(
            abi.encodeWithSelector(FixedPriceSignatureMinter.mint.selector, address(edition), MINT_ID, 1, sig)
        );
        assertFalse(status);
    }

    function test_mintUpdatesValuesAndMintsCorrectly() public {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        address caller = getFundedAccount(1);
        bytes memory sig = _getSignature(caller, address(edition));

        uint32 quantity = 2;

        FixedPriceSignatureMinter.EditionMintData memory data = minter.editionMintData(address(edition), MINT_ID);

        assertEq(data.totalMinted, 0);

        vm.prank(caller);
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, sig);

        assertEq(edition.balanceOf(caller), uint256(quantity));

        data = minter.editionMintData(address(edition), MINT_ID);

        assertEq(data.totalMinted, quantity);
    }

    function test_supportsInterface() public {
        (, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        bool supportsIMinterModule = minter.supportsInterface(type(IMinterModule).interfaceId);
        bool supportsIFixedPriceSignatureMinter = minter.supportsInterface(
            type(IFixedPriceSignatureMinter).interfaceId
        );

        assertTrue(supportsIMinterModule);
        assertTrue(supportsIFixedPriceSignatureMinter);
    }

    function test_standardMintData() public {
        SoundEditionV1 edition = createGenericEdition();

        FixedPriceSignatureMinter minter = new FixedPriceSignatureMinter();

        edition.grantRole(edition.MINTER_ROLE(), address(minter));

        uint32 expectedStartTime = 123;
        uint32 expectedEndTime = 502370;
        uint32 expectedPrice = 1234071;

        minter.createEditionMint(
            address(edition),
            expectedPrice,
            _signerAddress(),
            MAX_MINTABLE,
            expectedStartTime,
            expectedEndTime
        );

        StandardMintData memory mintData = minter.standardMintData(address(edition), MINT_ID);

        assertEq(expectedStartTime, mintData.startTime);
        assertEq(expectedEndTime, mintData.endTime);
        assertEq(false, mintData.mintPaused);
        assertEq(expectedPrice, mintData.price);
        assertEq(type(uint32).max, mintData.maxMintablePerAccount);
        assertEq(MAX_MINTABLE, mintData.maxMintable);
        assertEq(0, mintData.totalMinted);
    }
}
