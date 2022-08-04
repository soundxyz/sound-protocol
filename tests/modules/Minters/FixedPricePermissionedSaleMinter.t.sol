pragma solidity ^0.8.15;

import "../../TestConfig.sol";
import "../../../contracts/SoundEdition/SoundEditionV1.sol";
import "../../../contracts/SoundCreator/SoundCreatorV1.sol";
import "../../../contracts/modules/Minters/FixedPricePermissionedSaleMinter.sol";

contract FixedPricePermissionedSaleMinterTests is TestConfig {
    using ECDSA for bytes32;

    uint256 constant PRICE = 1;

    uint32 constant MAX_MINTABLE = 5;

    uint256 SIGNER_PRIVATE_KEY = 1;

    // prettier-ignore
    event FixedPricePermissionedMintCreated(
        address indexed edition,
        uint256 price,
        address signer,
        uint32 maxMintable
    );

    function _signerAddress() internal returns (address) {
        return vm.addr(SIGNER_PRIVATE_KEY);
    }

    function _getSignature(address caller, address edition) internal returns (bytes memory) {
        bytes32 digest = keccak256(abi.encode(caller, address(edition))).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function _createEditionAndMinter()
        internal
        returns (SoundEditionV1 edition, FixedPricePermissionedSaleMinter minter)
    {
        edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        minter = new FixedPricePermissionedSaleMinter();

        edition.grantRole(edition.MINTER_ROLE(), address(minter));

        minter.createEditionMint(address(edition), PRICE, _signerAddress(), MAX_MINTABLE);
    }

    function test_createEditionMintEmitsEvent() public {
        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        FixedPricePermissionedSaleMinter minter = new FixedPricePermissionedSaleMinter();

        vm.expectEmit(false, false, false, true);

        emit FixedPricePermissionedMintCreated(address(edition), PRICE, _signerAddress(), MAX_MINTABLE);

        minter.createEditionMint(address(edition), PRICE, _signerAddress(), MAX_MINTABLE);
    }

    function test_createEditionMintRevertsIfSignerIsZeroAddress() public {
        SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        FixedPricePermissionedSaleMinter minter = new FixedPricePermissionedSaleMinter();

        vm.expectRevert(FixedPricePermissionedSaleMinter.SignerIsZeroAddress.selector);

        minter.createEditionMint(address(edition), PRICE, address(0), MAX_MINTABLE);
    }

    function test_mintWithoutCorrectSignatureReverts() public {
        (SoundEditionV1 edition, FixedPricePermissionedSaleMinter minter) = _createEditionAndMinter();

        address caller = getRandomAccount(1);
        bytes memory sig = _getSignature(caller, address(edition));

        vm.prank(caller);
        minter.mint{ value: PRICE }(address(edition), 1, sig);

        vm.expectRevert(FixedPricePermissionedSaleMinter.InvalidSignature.selector);
        minter.mint{ value: PRICE }(address(edition), 1, sig);
    }

    function test_mintWithWrongEtherValueReverts() public {
        (SoundEditionV1 edition, FixedPricePermissionedSaleMinter minter) = _createEditionAndMinter();

        address caller = getRandomAccount(1);
        bytes memory sig = _getSignature(caller, address(edition));

        vm.prank(caller);
        vm.expectRevert(FixedPricePermissionedSaleMinter.WrongEtherValue.selector);
        minter.mint{ value: PRICE * 2 }(address(edition), 1, sig);
    }

    function test_mintWhenSoldOutReverts() public {
        (SoundEditionV1 edition, FixedPricePermissionedSaleMinter minter) = _createEditionAndMinter();

        address caller = getRandomAccount(1);
        bytes memory sig = _getSignature(caller, address(edition));

        vm.prank(caller);
        vm.expectRevert(FixedPricePermissionedSaleMinter.SoldOut.selector);
        minter.mint{ value: PRICE * (MAX_MINTABLE + 1) }(address(edition), MAX_MINTABLE + 1, sig);

        vm.prank(caller);
        minter.mint{ value: PRICE * MAX_MINTABLE }(address(edition), MAX_MINTABLE, sig);

        vm.prank(caller);
        vm.expectRevert(FixedPricePermissionedSaleMinter.SoldOut.selector);
        minter.mint{ value: PRICE }(address(edition), 1, sig);
    }

    function test_mintWithUnauthorizedMinterReverts() public {
        (SoundEditionV1 edition, FixedPricePermissionedSaleMinter minter) = _createEditionAndMinter();

        address caller = getRandomAccount(1);
        bytes memory sig = _getSignature(caller, address(edition));

        bool status;

        vm.prank(caller);
        (status, ) = address(minter).call{ value: PRICE }(
            abi.encodeWithSelector(FixedPricePermissionedSaleMinter.mint.selector, address(edition), 1, sig)
        );
        assertTrue(status);

        vm.prank(edition.owner());
        edition.revokeRole(edition.MINTER_ROLE(), address(minter));

        vm.prank(caller);
        (status, ) = address(minter).call{ value: PRICE }(
            abi.encodeWithSelector(FixedPricePermissionedSaleMinter.mint.selector, address(edition), 1, sig)
        );
        assertFalse(status);
    }

    function test_mintUpdatesValuesAndMintsCorrectly() public {
        (SoundEditionV1 edition, FixedPricePermissionedSaleMinter minter) = _createEditionAndMinter();

        address caller = getRandomAccount(1);
        bytes memory sig = _getSignature(caller, address(edition));

        uint32 quantity = 2;

        FixedPricePermissionedSaleMinter.EditionMintData memory data = minter.editionMintData(address(edition));

        assertEq(data.totalMinted, 0);

        vm.prank(caller);
        minter.mint{ value: PRICE * quantity }(address(edition), quantity, sig);

        assertEq(edition.balanceOf(caller), uint256(quantity));

        data = minter.editionMintData(address(edition));

        assertEq(data.totalMinted, quantity);
    }
}
