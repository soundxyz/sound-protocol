pragma solidity ^0.8.16;

import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { SoundEditionV1_2 } from "@core/SoundEditionV1_2.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { EditionMaxMinter } from "@modules/EditionMaxMinter.sol";
import { RangeEditionMinter } from "@modules/RangeEditionMinter.sol";
import { IMinterAdapter, MinterAdapter } from "@modules/MinterAdapter.sol";

import { ISAM, SAM } from "@modules/SAM.sol";
import { Merkle } from "murky/Merkle.sol";
import { TestConfig } from "../TestConfig.sol";

contract MinterAdapterTests is TestConfig {
    uint96 public constant PRICE = 1 ether;

    event AdapterMinted(
        address minter,
        address indexed edition,
        uint256 indexed fromTokenId,
        uint32 quantity,
        address to,
        uint256 indexed attributionId
    );

    SoundEditionV1_2 edition;

    MinterAdapter minterAdapter;

    EditionMaxMinter editionMaxMinter;

    RangeEditionMinter rangeEditionMinter;

    SAM sam;

    function setUp() public override {
        super.setUp();

        edition = createGenericEdition();

        edition.setEditionMaxMintableRange(
            type(uint32).max, // Max mintable lower.
            type(uint32).max // Max mintable upper.
        );
        edition.setEditionCutoffTime(
            type(uint32).max // Max cutoff time.
        );

        // Create and connect the edition max minter.

        editionMaxMinter = new EditionMaxMinter(feeRegistry);

        editionMaxMinter.createEditionMint(
            address(edition),
            PRICE,
            0, // Start time.
            type(uint32).max, // End time.
            0, // Affiliate fee bps.
            type(uint32).max // Max mintable per account.
        );

        edition.grantRoles(address(editionMaxMinter), edition.MINTER_ROLE());

        // Create and connect the range edition minter.

        rangeEditionMinter = new RangeEditionMinter(feeRegistry);

        rangeEditionMinter.createEditionMint(
            address(edition),
            PRICE,
            0, // Start time.
            type(uint32).max - 1, // Cutoff time.
            type(uint32).max, // End time.
            0, // Affiliate fee bps.
            type(uint32).max, // Max mintable lower.
            type(uint32).max, // Max mintable upper.
            type(uint32).max // Max mintable per account.
        );

        edition.grantRoles(address(rangeEditionMinter), edition.MINTER_ROLE());

        // Create and connect the SAM.

        sam = new SAM();

        {
            address[] memory approvedFactories = new address[](1);
            approvedFactories[0] = address(soundCreator);
            sam.setApprovedEditionFactories(approvedFactories);
        }

        sam.create(
            address(edition),
            PRICE, // Base price.
            0, // Linear price slope.
            0, // Inflection price.
            0, // Inflection point.
            type(uint32).max, // Max supply.
            type(uint32).max, // Buy freeze time.
            0, // Artist fee BPS.
            0, // Golden egg fee BPS.
            0, // Affiliate fee BPS.
            address(this), // The address which created the edition via the factory.
            bytes32(_salt) // The salt used to create the edition via the factory.
        );

        edition.setSAM(address(sam));

        // Create the minter adapter with the minters.

        minterAdapter = new MinterAdapter();
    }

    function test_minterAdapterForSAM() public {
        (address payer, ) = _randomSigner();
        uint256 payerInitialBalance = type(uint192).max;
        vm.deal(payer, payerInitialBalance);
        (address collector, ) = _randomSigner();
        assertEq(collector.balance, 0);

        uint32 quantity = 16;
        uint256 attributionId = _random();

        // Mint out the edition to start the SAM.
        edition.setEditionCutoffTime(1);
        edition.setEditionMaxMintableRange(0, 0);

        uint256 paymentExcess = _random() % (1 << 32);
        vm.expectEmit(true, true, true, true);
        emit AdapterMinted(address(sam), address(edition), edition.nextTokenId(), quantity, collector, attributionId);
        vm.prank(payer);
        minterAdapter.samBuy{ value: quantity * PRICE + paymentExcess }(
            address(sam),
            address(edition),
            collector,
            quantity,
            address(0), // Affiliate.
            new bytes32[](0), // Affiliate proof.
            attributionId, // Attribution ID.
            collector
        );
        assertEq(collector.balance, paymentExcess);
        assertEq(edition.balanceOf(collector), quantity);
    }

    function test_minterAdapter() public {
        (address payer, ) = _randomSigner();
        uint256 payerInitialBalance = type(uint192).max;
        vm.deal(payer, payerInitialBalance);
        (address collector, ) = _randomSigner();

        uint32 quantity = 16;
        uint256 attributionId = _random();

        // Test the edition max minter.

        vm.expectEmit(true, true, true, true);
        emit AdapterMinted(
            address(editionMaxMinter),
            address(edition),
            edition.nextTokenId(),
            quantity,
            collector,
            attributionId
        );
        vm.prank(payer);
        minterAdapter.mintTo{ value: address(payer).balance }(
            address(editionMaxMinter),
            address(edition),
            0, // Mint ID
            collector,
            quantity,
            address(0), // Affiliate.
            attributionId
        );

        // Check that any excess payment is refunded.
        assertEq(address(payer).balance, payerInitialBalance - uint256(quantity) * uint256(PRICE));
        // Check that the NFTs are transferred to the collector.
        assertEq(edition.balanceOf(collector), quantity);

        // Test the range edition minter.

        vm.expectEmit(true, true, true, true);
        emit AdapterMinted(
            address(rangeEditionMinter),
            address(edition),
            edition.nextTokenId(),
            quantity,
            collector,
            attributionId
        );
        vm.prank(payer);
        minterAdapter.mintTo{ value: address(payer).balance }(
            address(rangeEditionMinter),
            address(edition),
            0, // Mint ID
            collector,
            quantity,
            address(0), // Affiliate.
            attributionId
        );

        // Check that any excess payment is refunded.
        assertEq(address(payer).balance, payerInitialBalance - 2 * uint256(quantity) * uint256(PRICE));
        // Check that the NFTs are transferred to the collector.
        assertEq(edition.balanceOf(collector), 2 * quantity);
    }

    function test_supportsInterface() public {
        bool supportsIMinterAdapter = minterAdapter.supportsInterface(type(IMinterAdapter).interfaceId);
        bool supports165 = minterAdapter.supportsInterface(type(IERC165).interfaceId);

        assertTrue(supports165);
        assertTrue(supportsIMinterAdapter);
    }

    function test_moduleInterfaceId() public {
        assertTrue(type(IMinterAdapter).interfaceId == minterAdapter.moduleInterfaceId());
    }
}
