pragma solidity ^0.8.16;

import "../../TestConfig.sol";
import "../../../contracts/SoundEdition/SoundEditionV1.sol";
import "../../../contracts/SoundCreator/SoundCreatorV1.sol";
import "../../../contracts/modules/Minters/MerkleDropMinter.sol";
import "../../../contracts/interfaces/IMerkleDropMint.sol";
import "openzeppelin/utils/cryptography/MerkleProof.sol";
import "murky/Merkle.sol";

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
        vm.expectRevert(abi.encodeWithSelector(MinterBase.MaxMintableReached.selector, 2));
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

        bool supportsIBaseMinter = minter.supportsInterface(type(IBaseMinter).interfaceId);
        bool supportsIMerkleDropMint = minter.supportsInterface(type(IMerkleDropMint).interfaceId);

        assertTrue(supportsIBaseMinter);
        assertTrue(supportsIMerkleDropMint);
    }
}
