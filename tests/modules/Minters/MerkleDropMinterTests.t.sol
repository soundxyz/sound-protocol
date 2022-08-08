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
    address[] accounts = [
        getRandomAccount(1),
        getRandomAccount(2),
        getRandomAccount(3)
    ];
    bytes32[] leaves;
    bytes32 public root;
    Merkle public m;

    function setUpMerkleTree() public {
        // Initialize
        m = new Merkle();

        leaves = new bytes32[](accounts.length);
        for (uint256 i = 0; i<accounts.length; ++i) {
            // Set eligibility for account[0] to 1 token, account[1] to 2 tokens and account[2] to 3 tokens
            leaves[i] = keccak256(abi.encodePacked(accounts[i], uint32(i+1)));
        }

        root = m.getRoot(leaves);
    }

    function _createEditionAndMinter(uint32 _price, uint32 _maxMintable, uint32 _maxAllowedPerWallet) internal returns (SoundEditionV1 edition, MerkleDropMinter minter) {
        setUpMerkleTree();
        edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        minter = new MerkleDropMinter();
        edition.grantRole(edition.MINTER_ROLE(), address(minter));
        minter.createEditionMint(address(edition), root, _price, START_TIME, END_TIME, _maxMintable);
    }

    function test_canSuccessfullyMintWhenEligible() public {
      (SoundEditionV1 edition, MerkleDropMinter minter) = _createEditionAndMinter(0, 6, 1);
      bytes32[] memory proof = m.getProof(leaves, 0);

      // Test we can verify proof using OZ MerkleProof lib, used by the minter
      bool verifiedOZ = MerkleProof.verify(proof, root, leaves[0]);
      assertTrue(verifiedOZ);

      // Test we can verify proof using Murky lib, used by the tests
      bool verifiedMurky = m.verifyProof(root, proof, leaves[0]);
      assertTrue(verifiedMurky);

      vm.warp(START_TIME);
      vm.prank(accounts[0]);
      minter.mint(address(edition), 1, proof);
    }
}
