pragma solidity ^0.8.16;

import { MerkleProof } from "openzeppelin/utils/cryptography/MerkleProof.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { Merkle } from "murky/Merkle.sol";

import { SoundEditionV1_2 } from "@core/SoundEditionV1_2.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { MerkleDropMinterV2_1 } from "@modules/MerkleDropMinterV2_1.sol";
import { IMerkleDropMinterV2_1, MintInfo } from "@modules/interfaces/IMerkleDropMinterV2_1.sol";
import { IMinterModuleV2_1 } from "@core/interfaces/IMinterModuleV2_1.sol";
import { Ownable, OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { TestConfig } from "../TestConfig.sol";

contract MerkleDropMinterV2_1Tests is TestConfig {
    uint32 public constant START_TIME = 100;

    uint32 public constant END_TIME = 200;

    uint16 public constant AFFILIATE_FEE_BPS = 0;

    address[] accounts = [getFundedAccount(1), getFundedAccount(2), getFundedAccount(3)];

    bytes32[] leaves;

    bytes32 public root;

    Merkle public m;

    // prettier-ignore
    event PriceSet(
        address indexed edition,
        uint128 mintId,
        uint96 price
    );

    // prettier-ignore
    event MaxMintableSet(
        address indexed edition,
         uint128 mintId, 
         uint32 maxMintable
    );

    // prettier-ignore
    event MaxMintablePerAccountSet(
        address indexed edition,
        uint128 mintId,
        uint32 maxMintablePerAccount
    );

    // prettier-ignore
    event MerkleRootHashSet(
        address indexed edition,
        uint128 mintId,
        bytes32 merkleRootHash
    );

    function setUpMerkleTree() public {
        // Initialize
        m = new Merkle();

        leaves = new bytes32[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            leaves[i] = keccak256(abi.encodePacked(accounts[i]));
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
            SoundEditionV1_2 edition,
            MerkleDropMinterV2_1 minter,
            uint128 mintId
        )
    {
        edition = createGenericEdition();

        setUpMerkleTree();

        minter = new MerkleDropMinterV2_1();
        edition.grantRoles(address(minter), edition.MINTER_ROLE());

        mintId = minter.createEditionMint(
            address(edition),
            root,
            _price,
            START_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS,
            _maxMintable,
            _maxMintablePerAccount
        );
    }

    function test_canMintMultipleTimesLessThanMaxMintablePerAccount() public {
        uint32 maxPerAccount = 2;
        (SoundEditionV1_2 edition, MerkleDropMinterV2_1 minter, uint128 mintId) = _createEditionAndMinter(
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
        (SoundEditionV1_2 edition, MerkleDropMinterV2_1 minter, uint128 mintId) = _createEditionAndMinter(
            0,
            6,
            maxPerAccount
        );
        bytes32[] memory proof = m.getProof(leaves, 0);

        vm.warp(START_TIME);
        vm.prank(accounts[0]);
        vm.expectRevert(IMerkleDropMinterV2_1.ExceedsMaxPerAccount.selector);
        // Max is 1 but buyer is requesting 2
        minter.mint(address(edition), mintId, requestedQuantity, proof, address(0));
    }

    function test_cannotClaimMoreThanMaxMintable() public {
        uint32 maxPerAccount = 3;
        uint32 requestedQuantity = 3;

        (SoundEditionV1_2 edition, MerkleDropMinterV2_1 minter, uint128 mintId) = _createEditionAndMinter(
            0,
            2,
            maxPerAccount
        );
        bytes32[] memory proof = m.getProof(leaves, 2);

        vm.warp(START_TIME);
        vm.prank(accounts[2]);
        vm.expectRevert(abi.encodeWithSelector(IMinterModuleV2_1.ExceedsAvailableSupply.selector, 2));
        minter.mint(address(edition), mintId, requestedQuantity, proof, address(0));
    }

    function test_cannotClaimWithInvalidProof() public {
        (SoundEditionV1_2 edition, MerkleDropMinterV2_1 minter, uint128 mintId) = _createEditionAndMinter(0, 1, 1);
        bytes32[] memory proof = m.getProof(leaves, 1);

        vm.warp(START_TIME);
        vm.prank(accounts[0]);
        uint32 requestedQuantity = 1;
        vm.expectRevert(IMerkleDropMinterV2_1.InvalidMerkleProof.selector);
        minter.mint(address(edition), mintId, requestedQuantity, proof, address(0));
    }

    function test_setPrice(uint96 price) public {
        (SoundEditionV1_2 edition, MerkleDropMinterV2_1 minter, uint128 mintId) = _createEditionAndMinter(0, 0, 1);

        vm.expectEmit(true, true, true, true);
        emit PriceSet(address(edition), mintId, price);
        minter.setPrice(address(edition), mintId, price);

        assertEq(minter.mintInfo(address(edition), mintId).price, price);
    }

    function test_setMaxMintable(uint32 maxMintable) public {
        (SoundEditionV1_2 edition, MerkleDropMinterV2_1 minter, uint128 mintId) = _createEditionAndMinter(0, 0, 1);

        vm.expectEmit(true, true, true, true);
        emit MaxMintableSet(address(edition), mintId, maxMintable);
        minter.setMaxMintable(address(edition), mintId, maxMintable);

        assertEq(minter.mintInfo(address(edition), mintId).maxMintable, maxMintable);
    }

    function test_setMaxMintableRevertsIfCallerNotEditionOwnerOrAdmin(uint32 maxMintable) external {
        (SoundEditionV1_2 edition, MerkleDropMinterV2_1 minter, uint128 mintId) = _createEditionAndMinter(0, 0, 1);
        address attacker = getFundedAccount(1);

        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(attacker);
        minter.setMaxMintable(address(edition), mintId, maxMintable);
    }

    function test_setMaxMintablePerAccount(uint32 maxMintablePerAccount) public {
        vm.assume(maxMintablePerAccount != 0);
        (SoundEditionV1_2 edition, MerkleDropMinterV2_1 minter, uint128 mintId) = _createEditionAndMinter(0, 0, 1);

        vm.expectEmit(true, true, true, true);
        emit MaxMintablePerAccountSet(address(edition), mintId, maxMintablePerAccount);
        minter.setMaxMintablePerAccount(address(edition), mintId, maxMintablePerAccount);

        assertEq(minter.mintInfo(address(edition), mintId).maxMintablePerAccount, maxMintablePerAccount);
    }

    function test_setMaxMintablePerAccountRevertsIfCallerNotEditionOwnerOrAdmin(uint32 maxMintable) external {
        (SoundEditionV1_2 edition, MerkleDropMinterV2_1 minter, uint128 mintId) = _createEditionAndMinter(0, 0, 1);
        address attacker = getFundedAccount(1);

        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(attacker);
        minter.setMaxMintablePerAccount(address(edition), mintId, maxMintable);
    }

    function test_setMaxMintablePerAccountWithZeroReverts() public {
        (SoundEditionV1_2 edition, MerkleDropMinterV2_1 minter, uint128 mintId) = _createEditionAndMinter(0, 0, 1);

        vm.expectRevert(IMerkleDropMinterV2_1.MaxMintablePerAccountIsZero.selector);
        minter.setMaxMintablePerAccount(address(edition), mintId, 0);
    }

    function test_setMerkleRootHash(bytes32 merkleRootHash) public {
        vm.assume(merkleRootHash != bytes32(0));
        (SoundEditionV1_2 edition, MerkleDropMinterV2_1 minter, uint128 mintId) = _createEditionAndMinter(0, 0, 1);

        vm.expectEmit(true, true, true, true);
        emit MerkleRootHashSet(address(edition), mintId, merkleRootHash);
        minter.setMerkleRootHash(address(edition), mintId, merkleRootHash);

        assertEq(minter.mintInfo(address(edition), mintId).merkleRootHash, merkleRootHash);
    }

    function test_setEmptyMerkleRootHashReverts() public {
        (SoundEditionV1_2 edition, MerkleDropMinterV2_1 minter, uint128 mintId) = _createEditionAndMinter(0, 0, 1);

        vm.expectRevert(IMerkleDropMinterV2_1.MerkleRootHashIsEmpty.selector);
        minter.setMerkleRootHash(address(edition), mintId, bytes32(0));
    }

    function test_setCreateWithMerkleRootHashReverts() public {
        (SoundEditionV1_2 edition, MerkleDropMinterV2_1 minter, ) = _createEditionAndMinter(0, 0, 1);

        vm.expectRevert(IMerkleDropMinterV2_1.MerkleRootHashIsEmpty.selector);

        minter.createEditionMint(
            address(edition),
            bytes32(0),
            0,
            START_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS,
            EDITION_MAX_MINTABLE,
            EDITION_MAX_MINTABLE
        );
    }

    function test_supportsInterface() public {
        (, MerkleDropMinterV2_1 minter, ) = _createEditionAndMinter(0, 0, 1);

        bool supportsIMinterModuleV2_1 = minter.supportsInterface(type(IMinterModuleV2_1).interfaceId);
        bool supportsIMerkleDropMint = minter.supportsInterface(type(IMerkleDropMinterV2_1).interfaceId);
        bool supports165 = minter.supportsInterface(type(IERC165).interfaceId);

        assertTrue(supports165);
        assertTrue(supportsIMinterModuleV2_1);
        assertTrue(supportsIMerkleDropMint);
    }

    function test_moduleInterfaceId() public {
        (, MerkleDropMinterV2_1 minter, ) = _createEditionAndMinter(0, 0, 1);

        assertTrue(type(IMerkleDropMinterV2_1).interfaceId == minter.moduleInterfaceId());
    }

    function test_mintInfo() public {
        SoundEditionV1_2 edition = createGenericEdition();

        MerkleDropMinterV2_1 minter = new MerkleDropMinterV2_1();
        setUpMerkleTree();

        edition.grantRoles(address(minter), edition.MINTER_ROLE());

        uint32 expectedStartTime = 123;
        uint32 expectedEndTime = 502370;
        uint32 expectedMaxMintable = 3973030;
        uint32 expectedMaxPerWallet = 397;

        uint128 mintId = minter.createEditionMint(
            address(edition),
            root,
            0,
            expectedStartTime,
            expectedEndTime,
            AFFILIATE_FEE_BPS,
            expectedMaxMintable,
            expectedMaxPerWallet
        );

        MintInfo memory mintData = minter.mintInfo(address(edition), mintId);

        assertEq(expectedStartTime, mintData.startTime);
        assertEq(expectedEndTime, mintData.endTime);
        assertEq(0, mintData.affiliateFeeBPS);
        assertEq(false, mintData.mintPaused);
        assertEq(expectedMaxMintable, mintData.maxMintable);
        assertEq(expectedMaxPerWallet, mintData.maxMintablePerAccount);
        assertEq(0, mintData.totalMinted);
        assertEq(root, mintData.merkleRootHash);
    }
}
