pragma solidity ^0.8.16;

import { MerkleProof } from "openzeppelin/utils/cryptography/MerkleProof.sol";
import { Merkle } from "murky/Merkle.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { MerkleDropMinter } from "@modules/minter/MerkleDropMinter.sol";
import { IMerkleDropMint } from "@modules/interfaces/IMerkleDropMint.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { IMinterModuleEventsAndErrors } from "@core/interfaces/minter/IMinterModuleEventsAndErrors.sol";
import { TestConfig } from "../TestConfig.sol";
import { StandardMintData } from "@core/interfaces/minter/minterStructs.sol";

contract MerkleDropMinterTests is TestConfig {
    uint32 public constant START_TIME = 100;
    uint32 public constant END_TIME = 200;

    address[] accounts = [getFundedAccount(1), getFundedAccount(2), getFundedAccount(3)];
    bytes32[] leaves;
    bytes32 public root;
    Merkle public m;

    function setUpMerkleTree(address edition) public {
        // Initialize
        m = new Merkle();

        leaves = new bytes32[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            leaves[i] = keccak256(abi.encodePacked(edition, accounts[i]));
        }

        root = m.getRoot(leaves);
    }

    function _createEditionAndMinter(
        uint32 _price,
        uint32 _maxMintable,
        uint32 _maxAllowedPerWallet
    )
        internal
        returns (
            SoundEditionV1 edition,
            MerkleDropMinter minter,
            uint256 mintId
        )
    {
        edition = createGenericEdition();

        setUpMerkleTree(address(edition));

        minter = new MerkleDropMinter();
        edition.grantRole(edition.MINTER_ROLE(), address(minter));
        mintId = minter.createEditionMint(
            address(edition),
            root,
            _price,
            START_TIME,
            END_TIME,
            _maxMintable,
            _maxAllowedPerWallet
        );
    }

    function test_canMintMultipleTimesLessThanMaxAllowedPerWallet() public {
        uint32 maxPerWallet = 2;
        (SoundEditionV1 edition, MerkleDropMinter minter, uint256 mintId) = _createEditionAndMinter(0, 6, maxPerWallet);
        bytes32[] memory proof = m.getProof(leaves, 1);

        uint256 user1Balance = edition.balanceOf(accounts[1]);
        assertEq(user1Balance, 0);

        vm.warp(START_TIME);

        uint32 requestedQuantity = 1;
        vm.prank(accounts[1]);
        minter.mint(address(edition), mintId, requestedQuantity, proof);
        user1Balance = edition.balanceOf(accounts[1]);
        assertEq(user1Balance, 1);

        // Claim the second of the 2 max per wallet
        vm.prank(accounts[1]);
        minter.mint(address(edition), mintId, requestedQuantity, proof);
        user1Balance = edition.balanceOf(accounts[1]);
        assertEq(user1Balance, 2);
    }

    function test_cannotClaimMoreThanMaxAllowedPerWallet() public {
        uint32 maxPerWallet = 1;
        uint32 requestedQuantity = 2;
        (SoundEditionV1 edition, MerkleDropMinter minter, uint256 mintId) = _createEditionAndMinter(0, 6, maxPerWallet);
        bytes32[] memory proof = m.getProof(leaves, 0);

        vm.warp(START_TIME);
        vm.prank(accounts[0]);
        vm.expectRevert(MerkleDropMinter.ExceedsMaxPerWallet.selector);
        // Max is 1 but buyer is requesting 2
        minter.mint(address(edition), mintId, requestedQuantity, proof);
    }

    function test_cannotClaimMoreThanMaxMintable() public {
        uint32 maxPerWallet = 3;
        uint32 requestedQuantity = 3;

        (SoundEditionV1 edition, MerkleDropMinter minter, uint256 mintId) = _createEditionAndMinter(0, 2, maxPerWallet);
        bytes32[] memory proof = m.getProof(leaves, 2);

        vm.warp(START_TIME);
        vm.prank(accounts[2]);
        vm.expectRevert(abi.encodeWithSelector(IMinterModuleEventsAndErrors.MaxMintableReached.selector, 2));
        minter.mint(address(edition), mintId, requestedQuantity, proof);
    }

    function test_cannotClaimWithInvalidProof() public {
        (SoundEditionV1 edition, MerkleDropMinter minter, uint256 mintId) = _createEditionAndMinter(0, 1, 1);
        bytes32[] memory proof = m.getProof(leaves, 1);

        vm.warp(START_TIME);
        vm.prank(accounts[0]);
        uint32 requestedQuantity = 1;
        vm.expectRevert(MerkleDropMinter.InvalidMerkleProof.selector);
        minter.mint(address(edition), mintId, requestedQuantity, proof);
    }

    function test_canGetClaimedAmountForWallet() public {
        uint32 maxAllowedPerWwallet = 1;
        (SoundEditionV1 edition, MerkleDropMinter minter, uint256 mintId) = _createEditionAndMinter(
            0,
            6,
            maxAllowedPerWwallet
        );
        bytes32[] memory proof = m.getProof(leaves, 0);

        vm.warp(START_TIME);
        vm.prank(accounts[0]);
        uint32 requestedQuantity = maxAllowedPerWwallet;
        minter.mint(address(edition), mintId, requestedQuantity, proof);

        uint256 claimedAmount = minter.getClaimed(address(edition), mintId, accounts[0]);
        assertEq(claimedAmount, 1);
    }

    function test_supportsInterface() public {
        (, MerkleDropMinter minter, ) = _createEditionAndMinter(0, 0, 0);

        bool supportsIMinterModule = minter.supportsInterface(type(IMinterModule).interfaceId);
        bool supportsIMerkleDropMint = minter.supportsInterface(type(IMerkleDropMint).interfaceId);

        assertTrue(supportsIMinterModule);
        assertTrue(supportsIMerkleDropMint);
    }

    function test_standardMintData() public {
        SoundEditionV1 edition = createGenericEdition();

        MerkleDropMinter minter = new MerkleDropMinter();
        setUpMerkleTree(address(edition));

        edition.grantRole(edition.MINTER_ROLE(), address(minter));

        uint32 expectedStartTime = 123;
        uint32 expectedEndTime = 502370;
        uint32 expectedMaxMintable = 39730302;
        uint32 expectedMaxPerWallet = 397;

        uint256 mintId = minter.createEditionMint(
            address(edition),
            root,
            0,
            expectedStartTime,
            expectedEndTime,
            expectedMaxMintable,
            expectedMaxPerWallet
        );

        StandardMintData memory mintData = minter.standardMintData(address(edition), mintId);

        assertEq(mintData.startTime, expectedStartTime);
        assertEq(mintData.endTime, expectedEndTime);
        assertEq(mintData.mintPaused, false);
        assertEq(mintData.maxMintable, expectedMaxMintable);
        assertEq(mintData.maxAllowedPerWallet, expectedMaxPerWallet);
        assertEq(mintData.totalMinted, 0);
    }
}
