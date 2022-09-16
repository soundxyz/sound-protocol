pragma solidity ^0.8.16;

import { ECDSA } from "solady/utils/ECDSA.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";

import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { FixedPriceSignatureMinter } from "@modules/FixedPriceSignatureMinter.sol";
import { IFixedPriceSignatureMinter, MintInfo } from "@modules/interfaces/IFixedPriceSignatureMinter.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { TestConfig } from "../TestConfig.sol";

import "forge-std/console.sol";

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

    // prettier-ignore
    event PriceSet(
        address indexed edition,
        uint128 indexed mintId,
        uint96 price
    );

    // prettier-ignore
    event SignerSet(
        address indexed edition,
        uint128 indexed mintId,
        address signer
    );

    // prettier-ignore
    event MaxMintableSet(
        address indexed edition,
         uint128 indexed mintId, 
         uint32 maxMintable
    );

    function _signerAddress() internal returns (address) {
        return vm.addr(SIGNER_PRIVATE_KEY);
    }

    function _getSignature(
        address buyer,
        address minter,
        uint128 mintId,
        uint32 claimTicket,
        uint32 signedQuantity,
        address affiliate
    ) internal returns (bytes memory) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                IFixedPriceSignatureMinter(minter).DOMAIN_SEPARATOR(),
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
        bytes memory sig1 = _getSignature(buyer, address(minter), MINT_ID, claimTicket, signedQuantity, NULL_AFFILIATE);

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
        bytes memory sig2 = _getSignature(buyer, address(minter), MINT_ID, claimTicket++, MAX_MINTABLE, NULL_AFFILIATE);

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
        bytes memory sig3 = _getSignature(buyer, address(minter), MINT_ID, claimTicket++, MAX_MINTABLE, NULL_AFFILIATE);

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

    function test_mintForNonExistentMintIdReverts() public {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        uint32 quantity = 2;
        uint32 signedQuantity = quantity;
        address buyer = getFundedAccount(1);

        bytes memory sig = _getSignature(
            buyer,
            address(minter),
            MINT_ID,
            CLAIM_TICKET_0,
            signedQuantity,
            NULL_AFFILIATE
        );

        MintInfo memory data = minter.mintInfo(address(edition), MINT_ID);

        assertEq(data.totalMinted, 0);

        uint128 nonExistentMintId = MINT_ID + 1;

        vm.prank(buyer);
        vm.expectRevert(IFixedPriceSignatureMinter.SignerIsZeroAddress.selector);
        minter.mint{ value: PRICE * quantity }(
            address(edition),
            nonExistentMintId,
            quantity,
            signedQuantity,
            NULL_AFFILIATE,
            sig,
            CLAIM_TICKET_0
        );
    }

    function test_mintUpdatesValuesAndMintsCorrectly() public {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        uint32 quantity = 2;
        uint32 signedQuantity = quantity;
        address buyer = getFundedAccount(1);

        bytes memory sig = _getSignature(
            buyer,
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

    function test_multipleMintsFromSameBuyer() public {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        uint32 quantity = 1;
        uint32 signedQuantity = 2;
        uint32 claimTicket1 = 0;
        uint32 claimTicket2 = 1;
        address buyer = getFundedAccount(1);

        bytes memory sig1 = _getSignature(
            buyer,
            address(minter),
            MINT_ID,
            claimTicket1,
            signedQuantity,
            NULL_AFFILIATE
        );

        vm.prank(buyer);
        minter.mint{ value: PRICE * quantity }(
            address(edition),
            MINT_ID,
            quantity,
            signedQuantity,
            NULL_AFFILIATE,
            sig1,
            claimTicket1
        );

        assertEq(edition.balanceOf(buyer), uint256(quantity));

        bytes memory sig2 = _getSignature(
            buyer,
            address(minter),
            MINT_ID,
            claimTicket2,
            signedQuantity,
            NULL_AFFILIATE
        );

        vm.prank(buyer);
        minter.mint{ value: PRICE * quantity }(
            address(edition),
            MINT_ID,
            quantity,
            signedQuantity,
            NULL_AFFILIATE,
            sig2,
            claimTicket2
        );

        assertEq(edition.balanceOf(buyer), uint256(quantity * 2));
    }

    function test_signatureCannotBeReusedOnDifferentEditions() public {
        SoundEditionV1 edition1 = createGenericEdition();
        SoundEditionV1 edition2 = createGenericEdition();

        // Use the same minter for both editions
        FixedPriceSignatureMinter minter = new FixedPriceSignatureMinter(feeRegistry);

        edition1.grantRoles(address(minter), edition1.MINTER_ROLE());
        edition2.grantRoles(address(minter), edition2.MINTER_ROLE());

        uint128 mintId1 = minter.createEditionMint(
            address(edition1),
            PRICE,
            _signerAddress(),
            MAX_MINTABLE,
            START_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS
        );

        uint128 mintId2 = minter.createEditionMint(
            address(edition2),
            PRICE,
            _signerAddress(),
            MAX_MINTABLE,
            START_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS
        );

        address buyer = getFundedAccount(1);

        // Create signature to mint from edition 1

        bytes memory sig = _getSignature(
            buyer,
            address(minter),
            mintId1,
            CLAIM_TICKET_0,
            SIGNED_QUANTITY_1,
            NULL_AFFILIATE
        );

        // Mint on edition 1 succeeds

        vm.prank(buyer);
        minter.mint{ value: PRICE }(
            address(edition1),
            mintId1,
            QUANTITY_1,
            SIGNED_QUANTITY_1,
            NULL_AFFILIATE,
            sig,
            CLAIM_TICKET_0
        );

        // Mint with same signature on edition 2 fails - signature invalid

        vm.prank(buyer);
        vm.expectRevert(IFixedPriceSignatureMinter.InvalidSignature.selector);
        minter.mint{ value: PRICE }(
            address(edition2),
            mintId2,
            QUANTITY_1,
            SIGNED_QUANTITY_1,
            NULL_AFFILIATE,
            sig,
            CLAIM_TICKET_0
        );
    }

    function test_signatureCannotBeReusedOnDifferentMintInstances() external {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        address buyer = getFundedAccount(1);

        uint128 mintId1 = minter.createEditionMint(
            address(edition),
            PRICE,
            _signerAddress(),
            MAX_MINTABLE,
            START_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS
        );

        uint128 mintId2 = minter.createEditionMint(
            address(edition),
            PRICE,
            _signerAddress(),
            MAX_MINTABLE,
            START_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS
        );

        // Create signature to mint from first mint instance

        bytes memory sig = _getSignature(
            buyer,
            address(minter),
            mintId1,
            CLAIM_TICKET_0,
            SIGNED_QUANTITY_1,
            NULL_AFFILIATE
        );

        // Mint on edition 1 succeeds

        vm.prank(buyer);
        minter.mint{ value: PRICE }(
            address(edition),
            mintId1,
            QUANTITY_1,
            SIGNED_QUANTITY_1,
            NULL_AFFILIATE,
            sig,
            CLAIM_TICKET_0
        );

        // Mint with same signature on mint instance 2 - signature invalid

        vm.prank(buyer);
        vm.expectRevert(IFixedPriceSignatureMinter.InvalidSignature.selector);
        minter.mint{ value: PRICE }(
            address(edition),
            mintId2,
            QUANTITY_1,
            SIGNED_QUANTITY_1,
            NULL_AFFILIATE,
            sig,
            CLAIM_TICKET_0
        );
    }

    function test_checkClaimTickets() public {
        uint32[] memory tokensPerBuyer = new uint32[](1);
        tokensPerBuyer[0] = 1;

        uint32 numOfTokensToBuy = 10;

        uint32[] memory claimTickets = new uint32[](numOfTokensToBuy * 2);

        bool[] memory expectedClaimedAndUnclaimed = new bool[](numOfTokensToBuy * 2);

        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        uint128 mintId = minter.createEditionMint(
            address(edition),
            PRICE,
            _signerAddress(),
            type(uint32).max, // max mintable
            START_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS
        );

        // For each ticket number, mint a token, store the claim ticket as claimed (true),
        // then add an unclaimed ticket number so we can test the response from checkClaimTickets alternates as true and false
        for (uint32 claimTicket = 0; claimTicket < numOfTokensToBuy; claimTicket++) {
            address buyer = getFundedAccount(claimTicket + 1);

            bytes memory sig = _getSignature(
                buyer,
                address(minter),
                mintId,
                claimTicket,
                SIGNED_QUANTITY_1,
                NULL_AFFILIATE
            );

            // Buy token
            vm.prank(buyer);
            minter.mint{ value: PRICE }(
                address(edition),
                mintId,
                QUANTITY_1,
                SIGNED_QUANTITY_1,
                NULL_AFFILIATE,
                sig,
                claimTicket
            );

            // Store ticket number as claimed
            claimTickets[claimTicket * 2] = claimTicket;
            expectedClaimedAndUnclaimed[claimTicket * 2] = true;

            // Add an unclaimed ticket number
            claimTickets[claimTicket * 2 + 1] = claimTicket + 100000;
            expectedClaimedAndUnclaimed[claimTicket * 2 + 1] = false;
        }

        bool[] memory results = minter.checkClaimTickets(address(edition), mintId, claimTickets);

        assertEq(abi.encode(results), abi.encode(expectedClaimedAndUnclaimed));
    }

    function test_setMaxMintable(uint32 maxMintable) public {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        vm.expectEmit(true, true, true, true);
        emit MaxMintableSet(address(edition), MINT_ID, maxMintable);
        minter.setMaxMintable(address(edition), MINT_ID, maxMintable);

        assertEq(minter.mintInfo(address(edition), MINT_ID).maxMintable, maxMintable);
    }

    function test_setMaxMintableRevertsIfCallerNotEditionOwnerOrAdmin(uint32 maxMintable) external {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();
        address attacker = getFundedAccount(1);

        vm.expectRevert(IMinterModule.Unauthorized.selector);
        vm.prank(attacker);
        minter.setMaxMintable(address(edition), MINT_ID, maxMintable);
    }

    function test_setPrice(uint96 price) public {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        vm.expectEmit(true, true, true, true);
        emit PriceSet(address(edition), MINT_ID, price);
        minter.setPrice(address(edition), MINT_ID, price);

        assertEq(minter.mintInfo(address(edition), MINT_ID).price, price);
    }

    function test_setSigner(address signer) public {
        vm.assume(signer != address(0));

        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        vm.expectEmit(true, true, true, true);
        emit SignerSet(address(edition), MINT_ID, signer);
        minter.setSigner(address(edition), MINT_ID, signer);

        assertEq(minter.mintInfo(address(edition), MINT_ID).signer, signer);
    }

    function test_setZeroSignerReverts() public {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        vm.expectRevert(IFixedPriceSignatureMinter.SignerIsZeroAddress.selector);
        minter.setSigner(address(edition), MINT_ID, address(0));
    }

    function test_supportsInterface() public {
        (, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        bool supportsIMinterModule = minter.supportsInterface(type(IMinterModule).interfaceId);
        bool supportsIFixedPriceSignatureMinter = minter.supportsInterface(
            type(IFixedPriceSignatureMinter).interfaceId
        );
        bool supports165 = minter.supportsInterface(type(IERC165).interfaceId);

        assertTrue(supports165);
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
        uint96 expectedPrice = 1234071;

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

    function test_mintWithDifferentChainIdReverts() public {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        uint32 claimTicket = 0;
        address buyer = getFundedAccount(1);

        vm.chainId(1);
        bytes memory sig1 = _getSignature(
            buyer,
            address(minter),
            MINT_ID,
            claimTicket,
            SIGNED_QUANTITY_1,
            NULL_AFFILIATE
        );

        // This mint fails because the chain id is different.
        vm.prank(buyer);
        vm.expectRevert(IFixedPriceSignatureMinter.InvalidSignature.selector);
        vm.chainId(11111);
        minter.mint{ value: PRICE }(
            address(edition),
            MINT_ID,
            QUANTITY_1,
            SIGNED_QUANTITY_1,
            NULL_AFFILIATE,
            sig1,
            claimTicket
        );

        // This mint succeeds.
        vm.chainId(1);
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
    }

    function test_mintWithMoreThanSignedQuantityReverts() public {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        uint32 quantity = 2;
        uint32 signedQuantity = 2;

        address buyer = getFundedAccount(1);
        bytes memory sig = _getSignature(
            buyer,
            address(minter),
            MINT_ID,
            CLAIM_TICKET_0,
            signedQuantity,
            NULL_AFFILIATE
        );

        quantity = signedQuantity + 1;

        // This mint fails because we have exceeded the signed quantity.
        vm.prank(buyer);
        vm.expectRevert(IFixedPriceSignatureMinter.ExceedsSignedQuantity.selector);
        minter.mint{ value: PRICE * quantity }(
            address(edition),
            MINT_ID,
            quantity,
            signedQuantity,
            NULL_AFFILIATE,
            sig,
            CLAIM_TICKET_0
        );

        quantity = signedQuantity - 1;

        // This mint succeeds.
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
    }

    function test_mintWithInvalidAffiliateReverts() public {
        (SoundEditionV1 edition, FixedPriceSignatureMinter minter) = _createEditionAndMinter();

        address buyer = getFundedAccount(1);
        address affiliate = getFundedAccount(2);
        address wrongAffiliate = getFundedAccount(3);
        bytes memory sig = _getSignature(buyer, address(minter), MINT_ID, CLAIM_TICKET_0, SIGNED_QUANTITY_1, affiliate);

        // This mint fails because we are not minting with the correct affiliate.
        vm.prank(buyer);
        vm.expectRevert(IFixedPriceSignatureMinter.InvalidSignature.selector);
        minter.mint{ value: PRICE * QUANTITY_1 }(
            address(edition),
            MINT_ID,
            QUANTITY_1,
            SIGNED_QUANTITY_1,
            wrongAffiliate,
            sig,
            CLAIM_TICKET_0
        );

        // This mint fails because we are not minting with the correct affiliate.
        vm.prank(buyer);
        vm.expectRevert(IFixedPriceSignatureMinter.InvalidSignature.selector);
        minter.mint{ value: PRICE * QUANTITY_1 }(
            address(edition),
            MINT_ID,
            QUANTITY_1,
            SIGNED_QUANTITY_1,
            NULL_AFFILIATE,
            sig,
            CLAIM_TICKET_0
        );

        // This mint succeeds.
        vm.prank(buyer);
        minter.mint{ value: PRICE * QUANTITY_1 }(
            address(edition),
            MINT_ID,
            QUANTITY_1,
            SIGNED_QUANTITY_1,
            affiliate,
            sig,
            CLAIM_TICKET_0
        );
    }
}
