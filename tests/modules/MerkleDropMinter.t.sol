pragma solidity ^0.8.16;

import { MerkleProof } from "openzeppelin/utils/cryptography/MerkleProof.sol";
import { Merkle } from "murky/Merkle.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { MerkleDropMinter } from "@modules/MerkleDropMinter.sol";
import { IMerkleDropMinter, MintInfo } from "@modules/interfaces/IMerkleDropMinter.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { TestConfig } from "../TestConfig.sol";

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
        uint32 _maxMintablePerAccount
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

        minter = new MerkleDropMinter(feeRegistry);
        edition.grantRoles(address(minter), edition.MINTER_ROLE());

        mintId = minter.createEditionMint(
            address(edition),
            root,
            _price,
            START_TIME,
            END_TIME,
            _maxMintable,
            _maxMintablePerAccount
        );
    }

    function test_canMintMultipleTimesLessThanMaxMintablePerAccount() public {
        uint32 maxPerAccount = 2;
        (SoundEditionV1 edition, MerkleDropMinter minter, uint256 mintId) = _createEditionAndMinter(
            0,
            6,
            maxPerAccount
        );
        bytes32[] memory proof = m.getProof(leaves, 1);

        uint256 user1Balance = edition.balanceOf(accounts[1]);
        assertEq(user1Balance, 0);

        vm.warp(START_TIME);

        uint32 requestedQuantity = 1;
        vm.prank(accounts[1]);
        minter.mint(address(edition), mintId, requestedQuantity, proof, address(0));
        user1Balance = edition.balanceOf(accounts[1]);
        assertEq(user1Balance, 1);

        // Claim the second of the 2 max per account
        vm.prank(accounts[1]);
        minter.mint(address(edition), mintId, requestedQuantity, proof, address(0));
        user1Balance = edition.balanceOf(accounts[1]);
        assertEq(user1Balance, 2);
    }

    function test_cannotClaimMoreThanMaxMintablePerAccount() public {
        uint32 maxPerAccount = 1;
        uint32 requestedQuantity = 2;
        (SoundEditionV1 edition, MerkleDropMinter minter, uint256 mintId) = _createEditionAndMinter(
            0,
            6,
            maxPerAccount
        );
        bytes32[] memory proof = m.getProof(leaves, 0);

        vm.warp(START_TIME);
        vm.prank(accounts[0]);
        vm.expectRevert(IMerkleDropMinter.ExceedsMaxPerAccount.selector);
        // Max is 1 but buyer is requesting 2
        minter.mint(address(edition), mintId, requestedQuantity, proof, address(0));
    }

    function test_cannotClaimMoreThanMaxMintable() public {
        uint32 maxPerAccount = 3;
        uint32 requestedQuantity = 3;

        (SoundEditionV1 edition, MerkleDropMinter minter, uint256 mintId) = _createEditionAndMinter(
            0,
            2,
            maxPerAccount
        );
        bytes32[] memory proof = m.getProof(leaves, 2);

        vm.warp(START_TIME);
        vm.prank(accounts[2]);
        vm.expectRevert(abi.encodeWithSelector(IMinterModule.MaxMintableReached.selector, 2));
        minter.mint(address(edition), mintId, requestedQuantity, proof, address(0));
    }

    function test_cannotClaimWithInvalidProof() public {
        (SoundEditionV1 edition, MerkleDropMinter minter, uint256 mintId) = _createEditionAndMinter(0, 1, 1);
        bytes32[] memory proof = m.getProof(leaves, 1);

        vm.warp(START_TIME);
        vm.prank(accounts[0]);
        uint32 requestedQuantity = 1;
        vm.expectRevert(IMerkleDropMinter.InvalidMerkleProof.selector);
        minter.mint(address(edition), mintId, requestedQuantity, proof, address(0));
    }

    function test_canGetClaimedAmountForWallet() public {
        uint32 maxMintablePerAccount = 1;
        (SoundEditionV1 edition, MerkleDropMinter minter, uint256 mintId) = _createEditionAndMinter(
            0,
            6,
            maxMintablePerAccount
        );
        bytes32[] memory proof = m.getProof(leaves, 0);

        vm.warp(START_TIME);
        vm.prank(accounts[0]);

        uint32 requestedQuantity = maxMintablePerAccount;
        minter.mint(address(edition), mintId, requestedQuantity, proof, address(0));

        uint256 claimedAmount = minter.getClaimed(address(edition), mintId, accounts[0]);
        assertEq(claimedAmount, 1);
    }

    function test_supportsInterface() public {
        (, MerkleDropMinter minter, ) = _createEditionAndMinter(0, 0, 0);

        bool supportsIMinterModule = minter.supportsInterface(type(IMinterModule).interfaceId);
        bool supportsIMerkleDropMint = minter.supportsInterface(type(IMerkleDropMinter).interfaceId);

        assertTrue(supportsIMinterModule);
        assertTrue(supportsIMerkleDropMint);
    }

    function test_mintInfo() public {
        SoundEditionV1 edition = createGenericEdition();

        MerkleDropMinter minter = new MerkleDropMinter(feeRegistry);
        setUpMerkleTree(address(edition));

        edition.grantRoles(address(minter), edition.MINTER_ROLE());

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

        MintInfo memory mintData = minter.mintInfo(address(edition), mintId);

        assertEq(expectedStartTime, mintData.startTime);
        assertEq(expectedEndTime, mintData.endTime);
        assertEq(false, mintData.mintPaused);
        assertEq(expectedMaxMintable, mintData.maxMintable);
        assertEq(expectedMaxPerWallet, mintData.maxMintablePerAccount);
        assertEq(0, mintData.totalMinted);
        assertEq(root, mintData.merkleRootHash);
    }
}
