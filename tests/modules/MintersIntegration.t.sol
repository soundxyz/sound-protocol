pragma solidity ^0.8.16;

import { Merkle } from "murky/Merkle.sol";
import { MerkleProof } from "openzeppelin/utils/cryptography/MerkleProof.sol";

import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { MerkleDropMinter } from "@modules/MerkleDropMinter.sol";
import { RangeEditionMinter } from "@modules/RangeEditionMinter.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { TestConfig } from "../TestConfig.sol";

contract MintersIntegration is TestConfig {
    uint32 public constant START_TIME_FREE_DROP = 100;
    uint32 public constant START_TIME_PRESALE = START_TIME_FREE_DROP + 1 days;
    uint32 public constant START_TIME_PUBLIC_SALE = START_TIME_PRESALE + 1 days;
    uint32 public constant END_TIME_PUBLIC_SALE = START_TIME_PUBLIC_SALE + 1 days;
    uint16 public constant AFFILIATE_FEE_BPS = 0;

    // Free drop constant properties
    uint96 PRICE_FREE_DROP = 0;
    uint32 MINTER_MAX_MINTABLE_FREE_DROP = 100;
    uint32 MAX_MINTABLE_PER_ACCOUNT = 3;

    // Presale constant properties
    uint96 PRICE_PRESALE = 50000000 gwei; // Price is 0.05 ETH
    uint32 MINTER_MAX_MINTABLE_PRESALE = 45;
    uint32 MAX_MINTABLE_PER_ACCOUNT_PRESALE = 25; // There is a 25 tokens per account limit set on the presale.

    // Public sale constant properties
    uint96 PRICE_PUBLIC_SALE = 100000000000000000; // Price is 0.1 ETH
    uint32 MINTER_MAX_MINTABLE_PUBLIC_SALE = 700;
    uint32 MAX_MINTABLE_PER_ACCOUNT_PUBLIC_SALE = 50;

    address[] public userAccounts = [
        getFundedAccount(1), // User 1 - participate in free drop
        getFundedAccount(2), // User 2 - participate in free drop
        getFundedAccount(3), // User 3 - participate in presale
        getFundedAccount(4), // User 4 - participate in presale
        getFundedAccount(5), // User 5 - participate in public sale
        getFundedAccount(6) // User 6 - participate in public sale
    ];

    SoundEditionV1 public edition;

    // Helper function to setup a MerkleTree construct
    function setUpMerkleTree(address[] memory accounts) public returns (Merkle, bytes32[] memory) {
        Merkle m = new Merkle();

        bytes32[] memory leaves = new bytes32[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            leaves[i] = keccak256(abi.encodePacked(accounts[i]));
        }

        return (m, leaves);
    }

    /* Glasshouse integration test https://danielallan.xyz/glasshouse
      - Supply - 1000 Editions
      - Free Drop - 0.00 ETH
      - Presale - 0.05 ETH
      - Public Sale - 0.1 ETH
      - Restrictions per account - 25 mint max during presale, 50 mint max during public sale.

      Executed as sequential sales
      - Free mint: executed as 1 day long free drop
      - Pre-sale: executed as 1 day long paid drop
      - Public Sale: executed as 1 day long public sale
    */
    function test_Glasshouse() public {
        uint32 EDITION_MAX_MINTABLE = 1000;
        // Setup Glass house sound edition
        edition = SoundEditionV1(
            createSound(
                "Glass House",
                "GLASS",
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                EDITION_MAX_MINTABLE,
                EDITION_MAX_MINTABLE,
                EDITION_CUTOFF_TIME,
                FLAGS
            )
        );
        feeRegistry.setPlatformFeeBPS(0);

        // Setup the FREE MINT
        // Setup the free mint for 2 accounts able to claim 100 tokens in total.
        address[] memory accountsFreeMerkleDrop = new address[](2);
        accountsFreeMerkleDrop[0] = userAccounts[0];
        accountsFreeMerkleDrop[1] = userAccounts[1];

        // Setup the Merkle tree
        (Merkle merkleFreeDrop, bytes32[] memory leavesFreeMerkleDrop) = setUpMerkleTree(accountsFreeMerkleDrop);

        MerkleDropMinter merkleDropMinter = new MerkleDropMinter(feeRegistry);
        edition.grantRoles(address(merkleDropMinter), edition.MINTER_ROLE());

        bytes32 root = merkleFreeDrop.getRoot(leavesFreeMerkleDrop);
        uint128 mintIdFreeMint = merkleDropMinter.createEditionMint(
            address(edition),
            root,
            PRICE_FREE_DROP,
            START_TIME_FREE_DROP,
            START_TIME_PRESALE,
            AFFILIATE_FEE_BPS,
            MINTER_MAX_MINTABLE_FREE_DROP,
            MAX_MINTABLE_PER_ACCOUNT
        );

        // SETUP THE PRESALE
        // Setup the presale for 2 accounts able to claim 45 tokens in total.
        address[] memory accountsPresale = new address[](2);
        accountsPresale[0] = userAccounts[2];
        accountsPresale[1] = userAccounts[3];

        // Setup the Merkle tree
        (Merkle mPresale, bytes32[] memory leavesPresale) = setUpMerkleTree(accountsPresale);

        root = mPresale.getRoot(leavesPresale);
        uint128 mintIdPresale = merkleDropMinter.createEditionMint(
            address(edition),
            root,
            PRICE_PRESALE,
            START_TIME_PRESALE,
            START_TIME_PUBLIC_SALE,
            AFFILIATE_FEE_BPS,
            MINTER_MAX_MINTABLE_PRESALE,
            MAX_MINTABLE_PER_ACCOUNT_PRESALE
        );

        // SETUP PUBLIC SALE
        RangeEditionMinter publicSaleMinter = new RangeEditionMinter(feeRegistry);
        edition.grantRoles(address(publicSaleMinter), edition.MINTER_ROLE());

        uint128 mintIdPublicSale = publicSaleMinter.createEditionMint(
            address(edition),
            PRICE_PUBLIC_SALE,
            START_TIME_PUBLIC_SALE,
            END_TIME_PUBLIC_SALE - 1,
            END_TIME_PUBLIC_SALE,
            AFFILIATE_FEE_BPS,
            0,
            MINTER_MAX_MINTABLE_PUBLIC_SALE,
            MAX_MINTABLE_PER_ACCOUNT_PUBLIC_SALE
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
        uint128 mintId
    ) public {
        // START THE FREE DROP
        vm.warp(START_TIME_FREE_DROP);
        // Check user has no tokens
        uint256 user0Balance = edition.balanceOf(accountsFreeMerkleDrop[0]);
        assertEq(user0Balance, 0);
        // Claim 1 token
        bytes32[] memory proof0 = merkleFreeDrop.getProof(leavesFreeMerkleDrop, 0);
        vm.prank(accountsFreeMerkleDrop[0]);
        merkleDropMinter.mint(address(edition), mintId, 1, proof0, address(0));
        user0Balance = edition.balanceOf(accountsFreeMerkleDrop[0]);
        assertEq(user0Balance, 1);

        // Next user has no tokens
        bytes32[] memory proof1 = merkleFreeDrop.getProof(leavesFreeMerkleDrop, 1);
        uint256 user1Balance = edition.balanceOf(accountsFreeMerkleDrop[1]);
        assertEq(user1Balance, 0);
        // Claim 3 tokens (max per account)
        vm.prank(accountsFreeMerkleDrop[1]);
        merkleDropMinter.mint(address(edition), mintId, 3, proof1, address(0));
        user1Balance = edition.balanceOf(accountsFreeMerkleDrop[1]);
        assertEq(user1Balance, 3);

        // First user comes back to claim 2 more tokens, bringing balance to 3 (max per account)
        vm.prank(accountsFreeMerkleDrop[0]);
        merkleDropMinter.mint(address(edition), mintId, 2, proof0, address(0));
        user0Balance = edition.balanceOf(accountsFreeMerkleDrop[0]);
        assertEq(user0Balance, 3);

        // END FREE DROP, START PRESALE
        vm.warp(START_TIME_PRESALE);
    }

    function run_Presale(
        address[] memory accountsPresale,
        bytes32[] memory leavesPresale,
        MerkleDropMinter merkleDropMinter,
        Merkle mPresale,
        uint128 mintId
    ) public {
        // Check user 0 has no tokens
        uint256 user0Balance = edition.balanceOf(accountsPresale[0]);
        assertEq(user0Balance, 0);
        // Claim 20 tokens
        bytes32[] memory proof0 = mPresale.getProof(leavesPresale, 0);
        vm.prank(accountsPresale[0]);
        merkleDropMinter.mint{ value: 20 * PRICE_PRESALE }(address(edition), mintId, 20, proof0, address(0));
        user0Balance = edition.balanceOf(accountsPresale[0]);
        assertEq(user0Balance, 20);

        // Check user 1 has no tokens
        bytes32[] memory proof1 = mPresale.getProof(leavesPresale, 1);
        uint256 user1Balance = edition.balanceOf(accountsPresale[1]);
        assertEq(user1Balance, 0);
        // Claim 25 tokens
        vm.prank(accountsPresale[1]);
        merkleDropMinter.mint{ value: 25 * PRICE_PRESALE }(address(edition), mintId, 25, proof1, address(0));
        user1Balance = edition.balanceOf(accountsPresale[1]);
        assertEq(user1Balance, 25);

        // END PRESALE START AND START PUBLIC SALE
        vm.warp(START_TIME_PUBLIC_SALE);
    }

    function run_PublicSale(RangeEditionMinter publicSaleMinter, uint128 mintId) public {
        // Check user 5 has no tokens
        uint256 user5Balance = edition.balanceOf(userAccounts[4]);
        assertEq(user5Balance, 0);
        // Mint 5 tokens
        vm.prank(userAccounts[4]);
        publicSaleMinter.mint{ value: 5 * PRICE_PUBLIC_SALE }(address(edition), mintId, 5, address(0));
        user5Balance = edition.balanceOf(userAccounts[4]);
        assertEq(user5Balance, 5);

        // Check user 6 has no tokens
        uint256 user6Balance = edition.balanceOf(userAccounts[5]);
        assertEq(user6Balance, 0);
        // Claim maximum allowed tokens
        vm.prank(userAccounts[5]);
        publicSaleMinter.mint{ value: MAX_MINTABLE_PER_ACCOUNT_PUBLIC_SALE * PRICE_PUBLIC_SALE }(
            address(edition),
            mintId,
            MAX_MINTABLE_PER_ACCOUNT_PUBLIC_SALE,
            address(0)
        );
        user6Balance = edition.balanceOf(userAccounts[5]);
        assertEq(user6Balance, MAX_MINTABLE_PER_ACCOUNT_PUBLIC_SALE);

        // END PUBLIC SALE
        vm.warp(END_TIME_PUBLIC_SALE);
    }
}
