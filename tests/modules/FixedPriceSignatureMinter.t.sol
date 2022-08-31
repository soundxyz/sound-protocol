pragma solidity ^0.8.16;

import { ECDSA } from "solady/utils/ECDSA.sol";

import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { FixedPriceSignatureMinter } from "@modules/FixedPriceSignatureMinter.sol";
import { IFixedPriceSignatureMinter, MintInfo } from "@modules/interfaces/IFixedPriceSignatureMinter.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { TestConfig } from "../TestConfig.sol";

// TODO: test buyer can mint multiple times with new signatures / claim tickets
// TODO: test signature created on one edition can't be to mint from another edition
// TODO: test a valid signature can't be used on the wrong network
// TODO: test buyer can't mint more than the signed quantity
// TODO: test buyer can't mint with invalid affiliate address

contract FixedPriceSignatureMinterTests is TestConfig {
    using ECDSA for bytes32;

    uint96 constant PRICE = 1;
    uint32 constant MAX_MINTABLE = 5;
    uint256 constant SIGNER_PRIVATE_KEY = 1;
    uint128 constant MINT_ID = 0;
    uint32 constant START_TIME = 0;
    uint32 constant END_TIME = type(uint32).max;
    uint16 constant AFFILIATE_FEE_BPS = 0;
    address constant NULL_AFFILIATE = address(0);
    uint32 constant CLAIM_TICKET_0 = 0;
    uint32 constant QUANTITY_1 = 1;
    uint32 constant SIGNED_QUANTITY_1 = 1;

    // prettier-ignore
    event FixedPriceSignatureMintCreated(
        address indexed edition,
        uint128 indexed mintId,
        uint96 price,
        address signer,
        uint32 maxMintable,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBps
    );

    function _signerAddress() internal returns (address) {
        return vm.addr(SIGNER_PRIVATE_KEY);
    }

    // function _getSignature(address buyer, address edition) internal returns (bytes memory) {
    //     bytes32 digest = keccak256(abi.encode(buyer, address(edition), MINT_ID)).toEthSignedMessageHash();
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
    //     return abi.encodePacked(r, s, v);
    // }

    function _getSignature(
        address buyer,
        address edition,
        address minter,
        uint128 mintId,
        uint32 claimTicket,
        uint32 signedQuantity,
        address affiliate
    ) internal returns (bytes memory) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                ISoundEditionV1(edition).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        IFixedPriceSignatureMinter(minter).MINT_TYPEHASH(),
                        buyer,
                        mintId,
                        claimTicket,
                        signedQuantity,
                        affiliate
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function _createEditionAndMinter() internal returns (SoundEditionV1 edition, FixedPriceSignatureMinter minter) {
        edition = createGenericEdition();

        minter = new FixedPriceSignatureMinter(feeRegistry);

        edition.grantRoles(address(minter), edition.MINTER_ROLE());

        minter.createEditionMint(
            address(edition),
            PRICE,
            _signerAddress(),
            MAX_MINTABLE,
            START_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS
        );
    }

    function test_createEditionMintEmitsEvent() public {
        SoundEditionV1 edition = createGenericEdition();

        FixedPriceSignatureMinter minter = new FixedPriceSignatureMinter(feeRegistry);

        vm.expectEmit(false, false, false, true);

        emit FixedPriceSignatureMintCreated(
            address(edition),
            MINT_ID,
            PRICE,
            _signerAddress(),
            MAX_MINTABLE,
            START_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS
        );

        minter.createEditionMint(
            address(edition),
            PRICE,
            _signerAddress(),
            MAX_MINTABLE,
            START_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS
        );
    }

    function test_createEditionMintRevertsIfSignerIsZeroAddress() public {
        SoundEditionV1 edition = createGenericEdition();

        FixedPriceSignatureMinter minter = new FixedPriceSignatureMinter(feeRegistry);

        vm.expectRevert(IFixedPriceSignatureMinter.SignerIsZeroAddress.selector);

        minter.createEditionMint(
            address(edition),
            PRICE,
            address(0),
            MAX_MINTABLE,
            START_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS
        );
    }

    function test_mintRevertsIfBuyerNotAuthorized() public {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        uint32 claimTicket = 0;
        address buyer = getFundedAccount(1);

        bytes memory sig1 = _getSignature(
            buyer,
            address(edition),
            address(minter),
            MINT_ID,
            claimTicket,
            SIGNED_QUANTITY_1,
            NULL_AFFILIATE
        );

        // This mint succeeds because the signature is valid and contains the buyer address
        vm.prank(buyer);
        minter.mint{ value: PRICE }(
            address(edition),
            MINT_ID,
            QUANTITY_1,
            SIGNED_QUANTITY_1,
            NULL_AFFILIATE,
            sig1,
            claimTicket
        );

        address invalidBuyer = address(666);

        bytes memory sig2 = _getSignature(
            invalidBuyer,
            address(edition),
            address(minter),
            MINT_ID,
            claimTicket++,
            SIGNED_QUANTITY_1,
            NULL_AFFILIATE
        );

        // This mint fails because invalidBuyer isn't in the signed message
        vm.prank(buyer);
        vm.expectRevert(IFixedPriceSignatureMinter.InvalidSignature.selector);
        minter.mint{ value: PRICE }(
            address(edition),
            MINT_ID,
            QUANTITY_1,
            SIGNED_QUANTITY_1,
            NULL_AFFILIATE,
            sig2,
            claimTicket++
        );
    }

    function test_mintWithUnderpaidReverts() public {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        uint32 quantity = 2;
        uint32 signedQuantity = quantity;

        address buyer = getFundedAccount(1);
        bytes memory sig = _getSignature(
            buyer,
            address(edition),
            address(minter),
            MINT_ID,
            CLAIM_TICKET_0,
            signedQuantity,
            NULL_AFFILIATE
        );

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IMinterModule.Underpaid.selector, PRICE * quantity - 1, PRICE * 2));
        minter.mint{ value: PRICE * quantity - 1 }(
            address(edition),
            MINT_ID,
            quantity,
            signedQuantity,
            NULL_AFFILIATE,
            sig,
            CLAIM_TICKET_0
        );
    }

    function test_mintWhenSoldOutReverts() public {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        uint32 claimTicket = 0;
        uint32 quantity = MAX_MINTABLE + 1;
        uint32 signedQuantity = quantity;

        address buyer = getFundedAccount(1);
        bytes memory sig1 = _getSignature(
            buyer,
            address(edition),
            address(minter),
            MINT_ID,
            claimTicket,
            signedQuantity,
            NULL_AFFILIATE
        );

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IMinterModule.ExceedsAvailableSupply.selector, MAX_MINTABLE));
        minter.mint{ value: PRICE * (MAX_MINTABLE + 1) }(
            address(edition),
            MINT_ID,
            quantity,
            signedQuantity,
            NULL_AFFILIATE,
            sig1,
            CLAIM_TICKET_0
        );

        // Second buy is authorized to mint the max mintable quantity
        bytes memory sig2 = _getSignature(
            buyer,
            address(edition),
            address(minter),
            MINT_ID,
            claimTicket++,
            MAX_MINTABLE,
            NULL_AFFILIATE
        );

        // Mint should succeed
        vm.prank(buyer);
        minter.mint{ value: PRICE * MAX_MINTABLE }(
            address(edition),
            MINT_ID,
            MAX_MINTABLE,
            MAX_MINTABLE,
            NULL_AFFILIATE,
            sig2,
            CLAIM_TICKET_0
        );

        // Last signature authorizes max mintable quantity, but the mint is now sold out.
        bytes memory sig3 = _getSignature(
            buyer,
            address(edition),
            address(minter),
            MINT_ID,
            claimTicket++,
            MAX_MINTABLE,
            NULL_AFFILIATE
        );

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IMinterModule.ExceedsAvailableSupply.selector, 0));
        minter.mint{ value: PRICE }(
            address(edition),
            MINT_ID,
            QUANTITY_1,
            SIGNED_QUANTITY_1,
            NULL_AFFILIATE,
            sig3,
            CLAIM_TICKET_0
        );
    }

    function test_mintWithUnauthorizedMinterReverts() public {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        address buyer = getFundedAccount(1);
        uint32 claimTicket = 0;

        bytes memory sig = _getSignature(
            buyer,
            address(edition),
            address(minter),
            MINT_ID,
            claimTicket,
            SIGNED_QUANTITY_1,
            NULL_AFFILIATE
        );

        vm.prank(buyer);
        minter.mint{ value: PRICE }(
            address(edition),
            MINT_ID,
            QUANTITY_1,
            SIGNED_QUANTITY_1,
            NULL_AFFILIATE,
            sig,
            claimTicket
        );

        vm.prank(edition.owner());
        edition.revokeRoles(address(minter), edition.MINTER_ROLE());

        vm.prank(buyer);
        vm.expectRevert(IFixedPriceSignatureMinter.SignatureAlreadyUsed.selector);
        minter.mint{ value: PRICE }(
            address(edition),
            MINT_ID,
            QUANTITY_1,
            SIGNED_QUANTITY_1,
            NULL_AFFILIATE,
            sig,
            claimTicket++
        );
    }

    function test_mintUpdatesValuesAndMintsCorrectly() public {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        uint32 quantity = 2;
        uint32 signedQuantity = quantity;
        address buyer = getFundedAccount(1);

        bytes memory sig = _getSignature(
            buyer,
            address(edition),
            address(minter),
            MINT_ID,
            CLAIM_TICKET_0,
            signedQuantity,
            NULL_AFFILIATE
        );

        MintInfo memory data = minter.mintInfo(address(edition), MINT_ID);

        assertEq(data.totalMinted, 0);

        vm.prank(buyer);
        minter.mint{ value: PRICE * quantity }(
            address(edition),
            MINT_ID,
            quantity,
            signedQuantity,
            NULL_AFFILIATE,
            sig,
            CLAIM_TICKET_0
        );

        assertEq(edition.balanceOf(buyer), uint256(quantity));

        data = minter.mintInfo(address(edition), MINT_ID);

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

    function test_moduleInterfaceId() public {
        (, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        assertTrue(type(IFixedPriceSignatureMinter).interfaceId == minter.moduleInterfaceId());
    }

    function test_mintInfo() public {
        SoundEditionV1 edition = createGenericEdition();

        FixedPriceSignatureMinter minter = new FixedPriceSignatureMinter(feeRegistry);

        edition.grantRoles(address(minter), edition.MINTER_ROLE());

        uint32 expectedStartTime = 123;
        uint32 expectedEndTime = 502370;
        uint32 expectedPrice = 1234071;

        minter.createEditionMint(
            address(edition),
            expectedPrice,
            _signerAddress(),
            MAX_MINTABLE,
            expectedStartTime,
            expectedEndTime,
            AFFILIATE_FEE_BPS
        );

        MintInfo memory mintData = minter.mintInfo(address(edition), MINT_ID);

        assertEq(expectedStartTime, mintData.startTime);
        assertEq(expectedEndTime, mintData.endTime);
        assertEq(0, mintData.affiliateFeeBPS);
        assertEq(false, mintData.mintPaused);
        assertEq(expectedPrice, mintData.price);
        assertEq(_signerAddress(), mintData.signer);
        assertEq(type(uint32).max, mintData.maxMintablePerAccount);
        assertEq(MAX_MINTABLE, mintData.maxMintable);
        assertEq(0, mintData.totalMinted);
    }
}
