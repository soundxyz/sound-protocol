pragma solidity ^0.8.15;

import "../../TestConfig.sol";
import "../../../contracts/SoundEdition/SoundEditionV1.sol";
import "../../../contracts/SoundCreator/SoundCreatorV1.sol";
import "../../../contracts/modules/Minters/MerkleDropMinter.sol";
import "openzeppelin/utils/cryptography/MerkleProof.sol";
import "murky/Merkle.sol";
import "forge-std/console2.sol";

contract MintersIntegration is TestConfig {
    uint32 public constant START_TIME = 100;

    // Helper function to setup a MerkleTree construct
    function setUpMerkleTree(address edition, address[] memory accounts, uint32[] memory eligibleQuantities) public returns(Merkle, bytes32[] memory) {
        Merkle m = new Merkle();

        bytes32[] memory leaves = new bytes32[](accounts.length);
        for (uint256 i = 0; i<accounts.length; ++i) {
            leaves[i] = keccak256(abi.encodePacked(edition, accounts[i], eligibleQuantities[i]));
        }

        return (m, leaves);
    }

    /* Glasshouse integration test https://danielallan.xyz/glasshouse
      - Supply - 1000 Editions
      - Free Mint - 0.00 ETH
      - Presale - 0.05 ETH
      - Public Sale - 0.1 ETH
      - Restrictions per wallet - 25 mint max during presale, 50 mint max during public sale.

      Executed as sequential sales
      - Free mint: executed as 1 day long free drop
      - Pre-sale: executed as 1 day long paid drop
      - Public Sale: executed as 1 day long public sale
    */
    function test_FreeAirdrop_PaidAirdrop_PublicSale() public {
      uint32 MASTER_MAX_MINTABLE = 1000;

      // Setup Glass house sound edition
      SoundEditionV1 edition = SoundEditionV1(
            soundCreator.createSound(
                "Glass House",
                "GLASS",
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                MASTER_MAX_MINTABLE,
                MASTER_MAX_MINTABLE,
                RANDOMNESS_LOCKED_TIMESTAMP)
        );

        // Setup the free mint for 2 accounts able to claim 100 tokens in total.
        address[] memory accountsFreeMerkleDrop = new address[](2);
        accountsFreeMerkleDrop[0] = getRandomAccount(1);
        accountsFreeMerkleDrop[1] = getRandomAccount(2);

        // Account 1 is eligible for 30 tokens, and account 2 for 70.
        uint32[] memory eligibleAmountsFreeMerkleDrop = new uint32[](2);
        eligibleAmountsFreeMerkleDrop[0] = uint32(30);
        eligibleAmountsFreeMerkleDrop[1] = uint32(70);

        // Setup the Merkle tree
        (Merkle m, bytes32[] memory leavesFreeMerkleDrop) = setUpMerkleTree(address(edition), accountsFreeMerkleDrop, eligibleAmountsFreeMerkleDrop);

        MerkleDropMinter freeMerkleDropMinter = new MerkleDropMinter();
        edition.grantRole(edition.MINTER_ROLE(), address(freeMerkleDropMinter));

        uint32 PRICE = 0;
        uint32 MINTER_MAX_MINTABLE = 100;
        bytes32 root = m.getRoot(leavesFreeMerkleDrop);
        uint256 mintId = freeMerkleDropMinter.createEditionMint(address(edition), root, PRICE, START_TIME, START_TIME + 1 days, MINTER_MAX_MINTABLE);

        // Start the free drop
        vm.warp(START_TIME);
        // Check user 0 has no tokens
        uint256 user0Balance = edition.balanceOf(accountsFreeMerkleDrop[0]);
        assertEq(user0Balance, 0);
        // Claim 20 of 30 eligible tokens
        bytes32[] memory proof0 = m.getProof(leavesFreeMerkleDrop, 0);
        vm.prank(accountsFreeMerkleDrop[0]);
        freeMerkleDropMinter.mint(address(edition), mintId, 30, 20, proof0);
        user0Balance = edition.balanceOf(accountsFreeMerkleDrop[0]);
        assertEq(user0Balance, 20);

        // Check user 1 has no tokens
        bytes32[] memory proof1 = m.getProof(leavesFreeMerkleDrop, 1);
        uint256 user1Balance = edition.balanceOf(accountsFreeMerkleDrop[1]);
        assertEq(user1Balance, 0);
        // Claim all 70 eligible tokens
        vm.prank(accountsFreeMerkleDrop[1]);
        freeMerkleDropMinter.mint(address(edition), mintId, 70, 70, proof1);
        user1Balance = edition.balanceOf(accountsFreeMerkleDrop[1]);
        assertEq(user1Balance, 70);

        // User 0 comes back to claim 5 more tokens of the 10 remaining eligible quantity
        vm.prank(accountsFreeMerkleDrop[0]);
        freeMerkleDropMinter.mint(address(edition), mintId, 30, 5, proof0);
        user0Balance = edition.balanceOf(accountsFreeMerkleDrop[0]);
        assertEq(user0Balance, 25);

        // Fast forward a day to end the free drop
        vm.warp(START_TIME + 1 days);
    }
}
