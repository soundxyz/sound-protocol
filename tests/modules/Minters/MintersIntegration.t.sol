pragma solidity ^0.8.15;

import "../../TestConfig.sol";
import "../../../contracts/SoundEdition/SoundEditionV1.sol";
import "../../../contracts/SoundCreator/SoundCreatorV1.sol";
import "../../../contracts/modules/Minters/MerkleDropMinter.sol";
import "../../../contracts/modules/Minters/FixedPricePublicSaleMinter.sol";
import "openzeppelin/utils/cryptography/MerkleProof.sol";
import "murky/Merkle.sol";
import "forge-std/console2.sol";

contract MintersIntegration is TestConfig {
    uint32 public constant START_TIME_FREE_DROP = 100;
    uint32 public constant START_TIME_PRESALE = START_TIME_FREE_DROP + 1 days;
    uint32 public constant START_TIME_PUBLIC_SALE = START_TIME_PRESALE + 1 days;
    uint32 public constant END_TIME_PUBLIC_SALE = START_TIME_PUBLIC_SALE + 1 days;

    address[] public userAccounts = [
      getRandomAccount(1), // User 1 - participate in free drop
      getRandomAccount(2), // User 2 - participate in free drop
      getRandomAccount(3), // User 3 - participate in presale
      getRandomAccount(4), // User 4 - participate in presale
      getRandomAccount(5), // User 5 - participate in public sale
      getRandomAccount(6)  // User 6 - participate in public sale
    ];

    SoundEditionV1 public edition;

    // Helper function to setup a MerkleTree construct
    function setUpMerkleTree(address editionAddress, address[] memory accounts, uint32[] memory eligibleQuantities) public returns(Merkle, bytes32[] memory) {
        Merkle m = new Merkle();

        bytes32[] memory leaves = new bytes32[](accounts.length);
        for (uint256 i = 0; i<accounts.length; ++i) {
            leaves[i] = keccak256(abi.encodePacked(editionAddress, accounts[i], eligibleQuantities[i]));
        }

        return (m, leaves);
    }

    /* Glasshouse integration test https://danielallan.xyz/glasshouse
      - Supply - 1000 Editions
      - Free Drop - 0.00 ETH
      - Presale - 0.05 ETH
      - Public Sale - 0.1 ETH
      - Restrictions per wallet - 25 mint max during presale, 50 mint max during public sale.

      Executed as sequential sales
      - Free mint: executed as 1 day long free drop
      - Pre-sale: executed as 1 day long paid drop
      - Public Sale: executed as 1 day long public sale
    */
    function test_Glasshouse() public {
      run_FreeAirdrop();
      run_Presale();
      run_PublicSale();
    }

    function run_FreeAirdrop() public {
      uint32 MASTER_MAX_MINTABLE = 1000;

      // Setup Glass house sound edition
      edition = SoundEditionV1(
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

        // START THE FREE DROP
        vm.warp(START_TIME_FREE_DROP);

        // Setup the free mint for 2 accounts able to claim 100 tokens in total.
        address[] memory accountsFreeMerkleDrop = new address[](2);
        accountsFreeMerkleDrop[0] = userAccounts[0];
        accountsFreeMerkleDrop[1] = userAccounts[1];

        // Account 1 is eligible for 30 tokens, and account 2 for 70.
        uint32[] memory eligibleAmountsFreeMerkleDrop = new uint32[](2);
        eligibleAmountsFreeMerkleDrop[0] = uint32(30);
        eligibleAmountsFreeMerkleDrop[1] = uint32(70);

        // Setup the Merkle tree
        (Merkle m, bytes32[] memory leavesFreeMerkleDrop) = setUpMerkleTree(address(edition), accountsFreeMerkleDrop, eligibleAmountsFreeMerkleDrop);

        MerkleDropMinter freeMerkleDropMinter = new MerkleDropMinter();
        edition.grantRole(edition.MINTER_ROLE(), address(freeMerkleDropMinter));

        uint256 PRICE_FREE_DROP = 0;
        uint32 MINTER_MAX_MINTABLE_FREE_DROP = 100;
        bytes32 root = m.getRoot(leavesFreeMerkleDrop);
        uint256 mintId = freeMerkleDropMinter.createEditionMint(
          address(edition),
          root,
          PRICE_FREE_DROP,
          START_TIME_FREE_DROP,
          START_TIME_PRESALE,
          MINTER_MAX_MINTABLE_FREE_DROP
        );

        // Check user has no tokens
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

        // END FREE DROP, START PRESALE
        vm.warp(START_TIME_PRESALE);
    }

    function run_Presale() public {
        // Setup the presale for 2 accounts able to claim 200 tokens in total.
        address[] memory accountsPresale = new address[](2);
        accountsPresale[0] = userAccounts[2];
        accountsPresale[1] = userAccounts[3];

        // User 2 is eligible for 50 tokens, and User 3 for 150.
        uint32[] memory eligibleAmountsPresale = new uint32[](2);
        eligibleAmountsPresale[0] = uint32(50);
        eligibleAmountsPresale[1] = uint32(150);

        // Setup the Merkle tree
        (Merkle mPresale, bytes32[] memory leavesPresale) =
        setUpMerkleTree(
          address(edition),
          accountsPresale,
          eligibleAmountsPresale
        );

        // todo update to work with the same merkle drop minter instance
        MerkleDropMinter presaleMerkleDropMinter = new MerkleDropMinter();
        edition.grantRole(edition.MINTER_ROLE(), address(presaleMerkleDropMinter));

        uint256 PRICE_PRESALE = 50000000000000000; // Price is 0.05 ETH
        uint32 MINTER_MAX_MINTABLE_PRESALE = 200;
        bytes32 root = mPresale.getRoot(leavesPresale);
        uint256 mintId = presaleMerkleDropMinter.createEditionMint(
          address(edition),
          root,
          PRICE_PRESALE,
          START_TIME_PRESALE,
          START_TIME_PUBLIC_SALE,
          MINTER_MAX_MINTABLE_PRESALE
        );

        // Check user 0 has no tokens
        uint256 user0Balance = edition.balanceOf(accountsPresale[0]);
        assertEq(user0Balance, 0);
        // Claim all 50 eligible tokens
        bytes32[] memory proof0 = mPresale.getProof(leavesPresale, 0);
        vm.prank(accountsPresale[0]);
        presaleMerkleDropMinter.mint{ value: 50 * PRICE_PRESALE }(address(edition), mintId, 50, 50, proof0);
        user0Balance = edition.balanceOf(accountsPresale[0]);
        assertEq(user0Balance, 50);

        // Check user 1 has no tokens
        bytes32[] memory proof1 = mPresale.getProof(leavesPresale, 1);
        uint256 user1Balance = edition.balanceOf(accountsPresale[1]);
        assertEq(user1Balance, 0);
        // Claim all 70 eligible tokens
        vm.prank(accountsPresale[1]);
        presaleMerkleDropMinter.mint{ value: 150 * PRICE_PRESALE }(address(edition), mintId, 150, 150, proof1);
        user1Balance = edition.balanceOf(accountsPresale[1]);
        assertEq(user1Balance, 150);

        // END PRESALE START AND START PUBLIC SALE
        vm.warp(START_TIME_PUBLIC_SALE);
    }

    function run_PublicSale() public {
        uint256 PRICE_PUBLIC_SALE = 100000000000000000; // Price is 0.1 ETH
        uint32 MINTER_MAX_MINTABLE_PUBLIC_SALE = 700;
        uint32 MAX_ALLOWED_PER_WALLET_PUBLIC_SALE = 50;

        FixedPricePublicSaleMinter minter = new FixedPricePublicSaleMinter();
        edition.grantRole(edition.MINTER_ROLE(), address(minter));
        uint256 mintId = minter.createEditionMint(
          address(edition),
          PRICE_PUBLIC_SALE,
          START_TIME_PUBLIC_SALE,
          END_TIME_PUBLIC_SALE,
          MINTER_MAX_MINTABLE_PUBLIC_SALE,
          MAX_ALLOWED_PER_WALLET_PUBLIC_SALE
        );

        // Check user 5 has no tokens
        uint256 user5Balance = edition.balanceOf(userAccounts[4]);
        assertEq(user5Balance, 0);
        // Mint 5 tokens
        vm.prank(userAccounts[4]);
        minter.mint{ value: 5 * PRICE_PUBLIC_SALE }(address(edition), mintId, 5);
        user5Balance = edition.balanceOf(userAccounts[4]);
        assertEq(user5Balance, 5);

        // Check user 6 has no tokens
        uint256 user6Balance = edition.balanceOf(userAccounts[5]);
        assertEq(user6Balance, 0);
        // Claim maximum allowed tokens
        vm.prank(userAccounts[5]);
        minter.mint{ value: MAX_ALLOWED_PER_WALLET_PUBLIC_SALE * PRICE_PUBLIC_SALE }(address(edition), mintId, MAX_ALLOWED_PER_WALLET_PUBLIC_SALE);
        user6Balance = edition.balanceOf(userAccounts[5]);
        assertEq(user6Balance, MAX_ALLOWED_PER_WALLET_PUBLIC_SALE);

        // END PUBLIC SALE
        vm.warp(END_TIME_PUBLIC_SALE);
    }
}
