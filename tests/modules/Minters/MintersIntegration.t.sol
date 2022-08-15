pragma solidity ^0.8.16;

import "../../TestConfig.sol";
import "../../../contracts/SoundEdition/SoundEditionV1.sol";
import "../../../contracts/SoundCreator/SoundCreatorV1.sol";
import "../../../contracts/modules/Minters/MerkleDropMinter.sol";
import "../../../contracts/modules/Minters/RangeEditionMinter.sol";
import "openzeppelin/utils/cryptography/MerkleProof.sol";
import "murky/Merkle.sol";
import "forge-std/console2.sol";

contract MintersIntegration is TestConfig {
    uint32 public constant START_TIME_FREE_DROP = 100;
    uint32 public constant START_TIME_PRESALE = START_TIME_FREE_DROP + 1 days;
    uint32 public constant START_TIME_PUBLIC_SALE = START_TIME_PRESALE + 1 days;
    uint32 public constant END_TIME_PUBLIC_SALE = START_TIME_PUBLIC_SALE + 1 days;

    // Free drop constant properties
    uint256 PRICE_FREE_DROP = 0;
    uint32 MINTER_MAX_MINTABLE_FREE_DROP = 100;
    uint32 MAX_ALLOWED_PER_WALLET = 0; // There is no per wallet limit set on the free sale.

    // Presale constant properties
    uint256 PRICE_PRESALE = 50000000 gwei; // Price is 0.05 ETH
    uint32 MINTER_MAX_MINTABLE_PRESALE = 45;
    uint32 MAX_ALLOWED_PER_WALLET_PRESALE = 25; // There is a 25 tokens per wallet limit set on the presale.

    // Public sale constant properties
    uint256 PRICE_PUBLIC_SALE = 100000000000000000; // Price is 0.1 ETH
    uint32 MINTER_MAX_MINTABLE_PUBLIC_SALE = 700;
    uint32 MAX_ALLOWED_PER_WALLET_PUBLIC_SALE = 50;

    address[] public userAccounts = [
        getRandomAccount(1), // User 1 - participate in free drop
        getRandomAccount(2), // User 2 - participate in free drop
        getRandomAccount(3), // User 3 - participate in presale
        getRandomAccount(4), // User 4 - participate in presale
        getRandomAccount(5), // User 5 - participate in public sale
        getRandomAccount(6) // User 6 - participate in public sale
    ];

    SoundEditionV1 public edition;

    // Helper function to setup a MerkleTree construct
    function setUpMerkleTree(
        address editionAddress,
        address[] memory accounts,
        uint32[] memory eligibleQuantities
    ) public returns (Merkle, bytes32[] memory) {
        Merkle m = new Merkle();

        bytes32[] memory leaves = new bytes32[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
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
        uint32 EDITION_MAX_MINTABLE = 1000;
        // Setup Glass house sound edition
        edition = SoundEditionV1(
            soundCreator.createSound(
                "Glass House",
                "GLASS",
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                EDITION_MAX_MINTABLE,
                EDITION_MAX_MINTABLE,
                RANDOMNESS_LOCKED_TIMESTAMP
            )
        );

        // Setup the FREE MINT
        // Setup the free mint for 2 accounts able to claim 100 tokens in total.
        address[] memory accountsFreeMerkleDrop = new address[](2);
        accountsFreeMerkleDrop[0] = userAccounts[0];
        accountsFreeMerkleDrop[1] = userAccounts[1];

        // Account 1 is eligible for 30 tokens, and account 2 for 70.
        uint32[] memory eligibleAmountsFreeMerkleDrop = new uint32[](2);
        eligibleAmountsFreeMerkleDrop[0] = uint32(30);
        eligibleAmountsFreeMerkleDrop[1] = uint32(70);

        // Setup the Merkle tree
        (Merkle merkleFreeDrop, bytes32[] memory leavesFreeMerkleDrop) = setUpMerkleTree(
            address(edition),
            accountsFreeMerkleDrop,
            eligibleAmountsFreeMerkleDrop
        );

        MerkleDropMinter merkleDropMinter = new MerkleDropMinter();
        edition.grantRole(edition.MINTER_ROLE(), address(merkleDropMinter));

        bytes32 root = merkleFreeDrop.getRoot(leavesFreeMerkleDrop);
        uint256 mintIdFreeMint = merkleDropMinter.createEditionMint(
            address(edition),
            root,
            PRICE_FREE_DROP,
            START_TIME_FREE_DROP,
            START_TIME_PRESALE,
            MINTER_MAX_MINTABLE_FREE_DROP,
            MAX_ALLOWED_PER_WALLET
        );

        // SETUP THE PRESALE
        // Setup the presale for 2 accounts able to claim 45 tokens in total.
        address[] memory accountsPresale = new address[](2);
        accountsPresale[0] = userAccounts[2];
        accountsPresale[1] = userAccounts[3];

        // User 2 is eligible for 20 tokens, and User 3 for 25.
        uint32[] memory eligibleAmountsPresale = new uint32[](2);
        eligibleAmountsPresale[0] = uint32(20);
        eligibleAmountsPresale[1] = uint32(25);

        // Setup the Merkle tree
        (Merkle mPresale, bytes32[] memory leavesPresale) = setUpMerkleTree(
            address(edition),
            accountsPresale,
            eligibleAmountsPresale
        );

        root = mPresale.getRoot(leavesPresale);
        uint256 mintIdPresale = merkleDropMinter.createEditionMint(
            address(edition),
            root,
            PRICE_PRESALE,
            START_TIME_PRESALE,
            START_TIME_PUBLIC_SALE,
            MINTER_MAX_MINTABLE_PRESALE,
            MAX_ALLOWED_PER_WALLET_PRESALE
        );

        // SETUP PUBLIC SALE
        RangeEditionMinter publicSaleMinter = new RangeEditionMinter();
        edition.grantRole(edition.MINTER_ROLE(), address(publicSaleMinter));
        uint256 mintIdPublicSale = publicSaleMinter.createEditionMint(
            address(edition),
            PRICE_PUBLIC_SALE,
            START_TIME_PUBLIC_SALE,
            END_TIME_PUBLIC_SALE - 1,
            END_TIME_PUBLIC_SALE,
            0,
            MINTER_MAX_MINTABLE_PUBLIC_SALE,
            MAX_ALLOWED_PER_WALLET_PUBLIC_SALE
        );

        run_FreeAirdrop(accountsFreeMerkleDrop, leavesFreeMerkleDrop, merkleDropMinter, merkleFreeDrop, mintIdFreeMint);
        run_Presale(accountsPresale, leavesPresale, merkleDropMinter, mPresale, mintIdPresale);
        run_PublicSale(publicSaleMinter, mintIdPublicSale);
    }

    function run_FreeAirdrop(
        address[] memory accountsFreeMerkleDrop,
        bytes32[] memory leavesFreeMerkleDrop,
        MerkleDropMinter merkleDropMinter,
        Merkle merkleFreeDrop,
        uint256 mintId
    ) public {
        // START THE FREE DROP
        vm.warp(START_TIME_FREE_DROP);
        // Check user has no tokens
        uint256 user0Balance = edition.balanceOf(accountsFreeMerkleDrop[0]);
        assertEq(user0Balance, 0);
        // Claim 20 of 30 eligible tokens
        bytes32[] memory proof0 = merkleFreeDrop.getProof(leavesFreeMerkleDrop, 0);
        vm.prank(accountsFreeMerkleDrop[0]);
        merkleDropMinter.mint(address(edition), mintId, 30, 20, proof0);
        user0Balance = edition.balanceOf(accountsFreeMerkleDrop[0]);
        assertEq(user0Balance, 20);

        // Check user 1 has no tokens
        bytes32[] memory proof1 = merkleFreeDrop.getProof(leavesFreeMerkleDrop, 1);
        uint256 user1Balance = edition.balanceOf(accountsFreeMerkleDrop[1]);
        assertEq(user1Balance, 0);
        // Claim all 70 eligible tokens
        vm.prank(accountsFreeMerkleDrop[1]);
        merkleDropMinter.mint(address(edition), mintId, 70, 70, proof1);
        user1Balance = edition.balanceOf(accountsFreeMerkleDrop[1]);
        assertEq(user1Balance, 70);

        // User 0 comes back to claim 5 more tokens of the 10 remaining eligible quantity
        vm.prank(accountsFreeMerkleDrop[0]);
        merkleDropMinter.mint(address(edition), mintId, 30, 5, proof0);
        user0Balance = edition.balanceOf(accountsFreeMerkleDrop[0]);
        assertEq(user0Balance, 25);

        // END FREE DROP, START PRESALE
        vm.warp(START_TIME_PRESALE);
    }

    function run_Presale(
        address[] memory accountsPresale,
        bytes32[] memory leavesPresale,
        MerkleDropMinter merkleDropMinter,
        Merkle mPresale,
        uint256 mintId
    ) public {
        // Check user 0 has no tokens
        uint256 user0Balance = edition.balanceOf(accountsPresale[0]);
        assertEq(user0Balance, 0);
        // Claim all 20 eligible tokens
        bytes32[] memory proof0 = mPresale.getProof(leavesPresale, 0);
        vm.prank(accountsPresale[0]);
        merkleDropMinter.mint{ value: 20 * PRICE_PRESALE }(address(edition), mintId, 20, 20, proof0);
        user0Balance = edition.balanceOf(accountsPresale[0]);
        assertEq(user0Balance, 20);

        // Check user 1 has no tokens
        bytes32[] memory proof1 = mPresale.getProof(leavesPresale, 1);
        uint256 user1Balance = edition.balanceOf(accountsPresale[1]);
        assertEq(user1Balance, 0);
        // Claim all 25 eligible tokens
        vm.prank(accountsPresale[1]);
        merkleDropMinter.mint{ value: 25 * PRICE_PRESALE }(address(edition), mintId, 25, 25, proof1);
        user1Balance = edition.balanceOf(accountsPresale[1]);
        assertEq(user1Balance, 25);

        // END PRESALE START AND START PUBLIC SALE
        vm.warp(START_TIME_PUBLIC_SALE);
    }

    function run_PublicSale(RangeEditionMinter publicSaleMinter, uint256 mintId) public {
        // Check user 5 has no tokens
        uint256 user5Balance = edition.balanceOf(userAccounts[4]);
        assertEq(user5Balance, 0);
        // Mint 5 tokens
        vm.prank(userAccounts[4]);
        publicSaleMinter.mint{ value: 5 * PRICE_PUBLIC_SALE }(address(edition), mintId, 5);
        user5Balance = edition.balanceOf(userAccounts[4]);
        assertEq(user5Balance, 5);

        // Check user 6 has no tokens
        uint256 user6Balance = edition.balanceOf(userAccounts[5]);
        assertEq(user6Balance, 0);
        // Claim maximum allowed tokens
        vm.prank(userAccounts[5]);
        publicSaleMinter.mint{ value: MAX_ALLOWED_PER_WALLET_PUBLIC_SALE * PRICE_PUBLIC_SALE }(
            address(edition),
            mintId,
            MAX_ALLOWED_PER_WALLET_PUBLIC_SALE
        );
        user6Balance = edition.balanceOf(userAccounts[5]);
        assertEq(user6Balance, MAX_ALLOWED_PER_WALLET_PUBLIC_SALE);

        // END PUBLIC SALE
        vm.warp(END_TIME_PUBLIC_SALE);
    }
}
