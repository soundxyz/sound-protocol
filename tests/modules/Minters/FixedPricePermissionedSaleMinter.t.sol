pragma solidity ^0.8.16;

import "../../TestConfig.sol";
import "../../../contracts/SoundEdition/SoundEditionV1.sol";
import "../../../contracts/SoundCreator/SoundCreatorV1.sol";
import "../../../contracts/modules/Minters/FixedPricePermissionedMinter.sol";
import "../../../contracts/interfaces/IFixedPricePermissionedMinter.sol";

contract FixedPricePermissionedSaleMinterTests is TestConfig {
    using ECDSA for bytes32;

    uint256 constant PRICE = 1;
    uint32 constant MAX_MINTABLE = 5;
    uint256 constant SIGNER_PRIVATE_KEY = 1;
    uint256 constant MINT_ID = 0;
    uint32 constant START_TIME = 0;
    uint32 constant END_TIME = type(uint32).max;

    // prettier-ignore
    event FixedPricePermissionedMintCreated(
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

    function _createEditionAndMinter() internal returns (SoundEditionV1 edition, FixedPricePermissionedMinter minter) {
        edition = createGenericEdition();

        minter = new FixedPricePermissionedMinter();

        edition.grantRole(edition.MINTER_ROLE(), address(minter));

        minter.createEditionMint(address(edition), PRICE, _signerAddress(), MAX_MINTABLE, START_TIME, END_TIME);
    }

    function test_createEditionMintEmitsEvent() public {
        SoundEditionV1 edition = createGenericEdition();

        FixedPricePermissionedMinter minter = new FixedPricePermissionedMinter();

        vm.expectEmit(false, false, false, true);

        emit FixedPricePermissionedMintCreated(address(edition), MINT_ID, PRICE, _signerAddress(), MAX_MINTABLE);

        minter.createEditionMint(address(edition), PRICE, _signerAddress(), MAX_MINTABLE, START_TIME, END_TIME);
    }

    function test_createEditionMintRevertsIfSignerIsZeroAddress() public {
        SoundEditionV1 edition = createGenericEdition();

        FixedPricePermissionedMinter minter = new FixedPricePermissionedMinter();

        vm.expectRevert(FixedPricePermissionedMinter.SignerIsZeroAddress.selector);

        minter.createEditionMint(address(edition), PRICE, address(0), MAX_MINTABLE, START_TIME, END_TIME);
    }

    function test_mintWithoutCorrectSignatureReverts() public {
        (SoundEditionV1 edition, FixedPricePermissionedMinter minter) = _createEditionAndMinter();

        address caller = getFundedAccount(1);
        bytes memory sig = _getSignature(caller, address(edition));

        vm.prank(caller);
        minter.mint{ value: PRICE }(address(edition), MINT_ID, 1, sig);

        vm.expectRevert(FixedPricePermissionedMinter.InvalidSignature.selector);
        minter.mint{ value: PRICE }(address(edition), MINT_ID, 1, sig);
    }

    function test_mintWithWrongEtherValueReverts() public {
        (SoundEditionV1 edition, FixedPricePermissionedMinter minter) = _createEditionAndMinter();

        address caller = getFundedAccount(1);
        bytes memory sig = _getSignature(caller, address(edition));

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(BaseMinter.WrongEtherValue.selector, PRICE * 2, PRICE));
        minter.mint{ value: PRICE * 2 }(address(edition), MINT_ID, 1, sig);
    }

    function test_mintWhenSoldOutReverts() public {
        (SoundEditionV1 edition, FixedPricePermissionedMinter minter) = _createEditionAndMinter();

        address caller = getFundedAccount(1);
        bytes memory sig = _getSignature(caller, address(edition));

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(BaseMinter.MaxMintableReached.selector, MAX_MINTABLE));
        minter.mint{ value: PRICE * (MAX_MINTABLE + 1) }(address(edition), MINT_ID, MAX_MINTABLE + 1, sig);

        vm.prank(caller);
        minter.mint{ value: PRICE * MAX_MINTABLE }(address(edition), MINT_ID, MAX_MINTABLE, sig);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(BaseMinter.MaxMintableReached.selector, MAX_MINTABLE));
        minter.mint{ value: PRICE }(address(edition), MINT_ID, 1, sig);
    }

    function test_mintWithUnauthorizedMinterReverts() public {
        (SoundEditionV1 edition, FixedPricePermissionedMinter minter) = _createEditionAndMinter();

        address caller = getFundedAccount(1);
        bytes memory sig = _getSignature(caller, address(edition));

        bool status;

        vm.prank(caller);
        (status, ) = address(minter).call{ value: PRICE }(
            abi.encodeWithSelector(FixedPricePermissionedMinter.mint.selector, address(edition), MINT_ID, 1, sig)
        );
        assertTrue(status);

        vm.prank(edition.owner());
        edition.revokeRole(edition.MINTER_ROLE(), address(minter));

        vm.prank(caller);
        (status, ) = address(minter).call{ value: PRICE }(
            abi.encodeWithSelector(FixedPricePermissionedMinter.mint.selector, address(edition), MINT_ID, 1, sig)
        );
        assertFalse(status);
    }

    function test_mintUpdatesValuesAndMintsCorrectly() public {
        (SoundEditionV1 edition, FixedPricePermissionedMinter minter) = _createEditionAndMinter();

        address caller = getFundedAccount(1);
        bytes memory sig = _getSignature(caller, address(edition));

        uint32 quantity = 2;

        FixedPricePermissionedMinter.EditionMintData memory data = minter.editionMintData(address(edition), MINT_ID);

        assertEq(data.totalMinted, 0);

        vm.prank(caller);
        minter.mint{ value: PRICE * quantity }(address(edition), MINT_ID, quantity, sig);

        assertEq(edition.balanceOf(caller), uint256(quantity));

        data = minter.editionMintData(address(edition), MINT_ID);

        assertEq(data.totalMinted, quantity);
    }

    function test_supportsInterface() public {
        (, FixedPricePermissionedMinter minter) = _createEditionAndMinter();

        bool supportsIBaseMinter = minter.supportsInterface(type(IBaseMinter).interfaceId);
        bool supportsIFixedPricePermissionedMinter = minter.supportsInterface(
            type(IFixedPricePermissionedMinter).interfaceId
        );

        assertTrue(supportsIBaseMinter);
        assertTrue(supportsIFixedPricePermissionedMinter);
    }
}
