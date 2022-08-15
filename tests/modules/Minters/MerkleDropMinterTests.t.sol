pragma solidity ^0.8.15;

import "../../TestConfig.sol";
import "../../../contracts/SoundEdition/SoundEditionV1.sol";
import "../../../contracts/SoundCreator/SoundCreatorV1.sol";
import "../../../contracts/modules/Minters/MerkleDropMinter.sol";
import "openzeppelin/utils/cryptography/MerkleProof.sol";
import "murky/Merkle.sol";
import "forge-std/console2.sol";

contract MerkleDropMinterTests is TestConfig {
    uint32 public constant START_TIME = 100;
    uint32 public constant END_TIME = 200;

    address[] accounts = [getRandomAccount(1), getRandomAccount(2), getRandomAccount(3)];
    bytes32[] leaves;
    bytes32 public root;
    Merkle public m;

    function setUpMerkleTree(address edition) public {
        // Initialize
        m = new Merkle();

        leaves = new bytes32[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            // Set eligibility for account[0] to 1 token, account[1] to 2 tokens and account[2] to 3 tokens
            leaves[i] = keccak256(abi.encodePacked(edition, accounts[i], uint32(i + 1)));
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

    function test_canSuccessfullyMintWhenEligible() public {
        (SoundEditionV1 edition, MerkleDropMinter minter, uint256 mintId) = _createEditionAndMinter(0, 6, 0);
        bytes32[] memory proof = m.getProof(leaves, 0);

        // Test we can verify proof using OZ MerkleProof lib, used by the minter
        bool verifiedOZ = MerkleProof.verify(proof, root, leaves[0]);
        assertTrue(verifiedOZ);

        // Test we can verify proof using Murky lib, used by the tests
        bool verifiedMurky = m.verifyProof(root, proof, leaves[0]);
        assertTrue(verifiedMurky);

        vm.warp(START_TIME);
        vm.prank(accounts[0]);
        uint32 eligibleQuantity = 1;
        uint32 requestedQuantity = 1;
        minter.mint(address(edition), mintId, eligibleQuantity, requestedQuantity, proof);
    }

    function test_canMintMultipleTimesLessThanEligibleAmount() public {
        (SoundEditionV1 edition, MerkleDropMinter minter, uint256 mintId) = _createEditionAndMinter(0, 6, 0);
        bytes32[] memory proof = m.getProof(leaves, 1);

        uint256 user1Balance = edition.balanceOf(accounts[1]);
        assertEq(user1Balance, 0);

        vm.warp(START_TIME);

        // Claim 1 of 2 eligible tokens
        uint32 eligibleQuantity = 2;
        uint32 requestedQuantity = 1;
        vm.prank(accounts[1]);
        minter.mint(address(edition), mintId, eligibleQuantity, requestedQuantity, proof);
        user1Balance = edition.balanceOf(accounts[1]);
        assertEq(user1Balance, 1);

        // Claim the second of the 2 eligible tokens
        vm.prank(accounts[1]);
        minter.mint(address(edition), mintId, eligibleQuantity, requestedQuantity, proof);
        user1Balance = edition.balanceOf(accounts[1]);
        assertEq(user1Balance, 2);
    }

    function test_cannotClaimMoreThanEligible() public {
        (SoundEditionV1 edition, MerkleDropMinter minter, uint256 mintId) = _createEditionAndMinter(0, 6, 0);
        bytes32[] memory proof = m.getProof(leaves, 0);

        vm.warp(START_TIME);
        vm.prank(accounts[0]);
        uint32 eligibleQuantity = 1;
        uint32 requestedQuantity = 2;
        vm.expectRevert(MerkleDropMinter.ExceedsEligibleQuantity.selector);
        // User is eligible for 1 but is requesting 2
        minter.mint(address(edition), mintId, eligibleQuantity, requestedQuantity, proof);
    }

    function test_cannotClaimMoreThanMaxMintable() public {
        (SoundEditionV1 edition, MerkleDropMinter minter, uint256 mintId) = _createEditionAndMinter(0, 2, 0);
        bytes32[] memory proof = m.getProof(leaves, 2);

        vm.warp(START_TIME);
        vm.prank(accounts[2]);
        uint32 eligibleQuantity = 3;
        uint32 requestedQuantity = 3;
        vm.expectRevert(abi.encodeWithSelector(MintControllerBase.MaxMintableReached.selector, 2));
        minter.mint(address(edition), mintId, eligibleQuantity, requestedQuantity, proof);
    }

    function test_cannotClaimWithInvalidProof() public {
        (SoundEditionV1 edition, MerkleDropMinter minter, uint256 mintId) = _createEditionAndMinter(0, 6, 0);
        bytes32[] memory proof = m.getProof(leaves, 1);

        vm.warp(START_TIME);
        vm.prank(accounts[0]);
        uint32 eligibleQuantity = 1;
        uint32 requestedQuantity = 1;
        vm.expectRevert(MerkleDropMinter.InvalidMerkleProof.selector);
        minter.mint(address(edition), mintId, eligibleQuantity, requestedQuantity, proof);
    }

    function test_canGetClaimedAmountForWallet() public {
        (SoundEditionV1 edition, MerkleDropMinter minter, uint256 mintId) = _createEditionAndMinter(0, 6, 0);
        bytes32[] memory proof = m.getProof(leaves, 0);

        vm.warp(START_TIME);
        vm.prank(accounts[0]);
        uint32 eligibleQuantity = 1;
        uint32 requestedQuantity = 1;
        minter.mint(address(edition), mintId, eligibleQuantity, requestedQuantity, proof);

        uint256 claimedAmount = minter.getClaimed(address(edition), mintId, accounts[0]);
        assertEq(claimedAmount, 1);
    }

    function test_cannotMintWhenOverMaxAllowedPerWallet() public {
        // Create a minter with overall maximum limit of 6 tokens and per wallet limit of 1
        (SoundEditionV1 edition, MerkleDropMinter minter, uint256 mintId) = _createEditionAndMinter(0, 6, 1);
        bytes32[] memory proof = m.getProof(leaves, 1);

        vm.warp(START_TIME);

        // Try to claim 2 of the 2 eligible tokens. This is more than the allowed 1 and test it reverts.
        uint32 eligibleQuantity = 2;
        uint32 requestedQuantity = 2;
        vm.prank(accounts[1]);
        vm.expectRevert(MerkleDropMinter.ExceedsMaxPerWallet.selector);
        minter.mint(address(edition), mintId, eligibleQuantity, requestedQuantity, proof);
    }

    function test_canMintUpToMinterMaximumWhenNoPerWalletMaximumIsSet() public {
        // Create a minter with overall maximum limit of 2 tokens and per wallet limit not set (i.e. set to 0)
        (SoundEditionV1 edition, MerkleDropMinter minter, uint256 mintId) = _createEditionAndMinter(0, 2, 0);
        bytes32[] memory proof = m.getProof(leaves, 1);

        vm.warp(START_TIME);

        uint256 user1Balance = edition.balanceOf(accounts[1]);
        assertEq(user1Balance, 0);
        // Try to claim 2 of the 2 eligible tokens. This is more than the allowed 1 and test it reverts.
        uint32 eligibleQuantity = 2;
        uint32 requestedQuantity = 2;
        vm.prank(accounts[1]);
        minter.mint(address(edition), mintId, eligibleQuantity, requestedQuantity, proof);

        user1Balance = edition.balanceOf(accounts[1]);
        assertEq(user1Balance, 2);
    }
}
