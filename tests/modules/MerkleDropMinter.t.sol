pragma solidity ^0.8.16;

import { MerkleProof } from "openzeppelin/utils/cryptography/MerkleProof.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
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

    uint16 public constant AFFILIATE_FEE_BPS = 0;

    address[] accounts = [getFundedAccount(1), getFundedAccount(2), getFundedAccount(3)];

    bytes32[] leaves;

    bytes32 public root;

    Merkle public m;

    // prettier-ignore
    event PriceSet(
        address indexed edition,
        uint128 indexed mintId,
        uint96 price
    );

    // prettier-ignore
    event MaxMintableSet(
        address indexed edition,
         uint128 indexed mintId, 
         uint32 maxMintable
    );

    // prettier-ignore
    event MaxMintablePerAccountSet(
        address indexed edition,
        uint128 indexed mintId,
        uint32 maxMintablePerAccount
    );

    // prettier-ignore
    event MerkleRootHashSet(
        address indexed edition,
        uint128 indexed mintId,
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
            SoundEditionV1 edition,
            MerkleDropMinter minter,
            uint128 mintId
        )
    {
        edition = createGenericEdition();

        setUpMerkleTree();

        minter = new MerkleDropMinter(feeRegistry);
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

    function test_mintToDifferentAddress() external {
        (SoundEditionV1 edition, MerkleDropMinter minter, uint128 mintId) = _createEditionAndMinter(
            0,
            EDITION_MAX_MINTABLE,
            EDITION_MAX_MINTABLE
        );

        vm.warp(START_TIME);
        unchecked {
            uint256 seed = uint256(keccak256(bytes("test_mintToDifferentAddress()")));
            for (uint256 i; i < accounts.length; ++i) {
                address to = accounts[i];
                bytes32[] memory proof = m.getProof(leaves, i);
                uint256 quantity;
                for (uint256 j = 1e9; quantity == 0; ++j) {
                    quantity = uint256(keccak256(abi.encode(j + i + seed))) % 10;
                }
                assertEq(edition.balanceOf(to), 0);
                assertEq(minter.mintCount(address(edition), mintId, to), 0);
                minter.mint(address(edition), mintId, to, uint32(quantity), proof, address(0));
                assertEq(edition.balanceOf(to), quantity);
                assertEq(minter.mintCount(address(edition), mintId, to), quantity);
            }
        }
    }

    function test_canMintMultipleTimesLessThanMaxMintablePerAccount() public {
        uint32 maxPerAccount = 2;
        (SoundEditionV1 edition, MerkleDropMinter minter, uint128 mintId) = _createEditionAndMinter(
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
        minter.mint(address(edition), mintId, accounts[1], requestedQuantity, proof, address(0));
        user1Balance = edition.balanceOf(accounts[1]);
        assertEq(user1Balance, 1);

        // Claim the second of the 2 max per account
        vm.prank(accounts[1]);
        minter.mint(address(edition), mintId, accounts[1], requestedQuantity, proof, address(0));
        user1Balance = edition.balanceOf(accounts[1]);
        assertEq(user1Balance, 2);
    }

    function test_cannotClaimMoreThanMaxMintablePerAccount() public {
        uint32 maxPerAccount = 1;
        uint32 requestedQuantity = 2;
        (SoundEditionV1 edition, MerkleDropMinter minter, uint128 mintId) = _createEditionAndMinter(
            0,
            6,
            maxPerAccount
        );
        bytes32[] memory proof = m.getProof(leaves, 0);

        vm.warp(START_TIME);
        vm.prank(accounts[0]);
        vm.expectRevert(IMerkleDropMinter.ExceedsMaxPerAccount.selector);
        // Max is 1 but buyer is requesting 2
        minter.mint(address(edition), mintId, accounts[0], requestedQuantity, proof, address(0));
    }

    function test_cannotClaimMoreThanMaxMintable() public {
        uint32 maxPerAccount = 3;
        uint32 requestedQuantity = 3;

        (SoundEditionV1 edition, MerkleDropMinter minter, uint128 mintId) = _createEditionAndMinter(
            0,
            2,
            maxPerAccount
        );
        bytes32[] memory proof = m.getProof(leaves, 2);

        vm.warp(START_TIME);
        vm.prank(accounts[2]);
        vm.expectRevert(abi.encodeWithSelector(IMinterModule.ExceedsAvailableSupply.selector, 2));
        minter.mint(address(edition), mintId, address(this), requestedQuantity, proof, address(0));
    }

    function test_cannotClaimWithInvalidProof() public {
        (SoundEditionV1 edition, MerkleDropMinter minter, uint128 mintId) = _createEditionAndMinter(0, 1, 1);
        bytes32[] memory proof = m.getProof(leaves, 1);

        vm.warp(START_TIME);
        vm.prank(accounts[0]);
        uint32 requestedQuantity = 1;
        vm.expectRevert(IMerkleDropMinter.InvalidMerkleProof.selector);
        minter.mint(address(edition), mintId, address(this), requestedQuantity, proof, address(0));
    }

    function test_setPrice(uint96 price) public {
        (SoundEditionV1 edition, MerkleDropMinter minter, uint128 mintId) = _createEditionAndMinter(0, 0, 1);

        vm.expectEmit(true, true, true, true);
        emit PriceSet(address(edition), mintId, price);
        minter.setPrice(address(edition), mintId, price);

        assertEq(minter.mintInfo(address(edition), mintId).price, price);
    }

    function test_setMaxMintable(uint32 maxMintable) public {
        (SoundEditionV1 edition, MerkleDropMinter minter, uint128 mintId) = _createEditionAndMinter(0, 0, 1);

        vm.expectEmit(true, true, true, true);
        emit MaxMintableSet(address(edition), mintId, maxMintable);
        minter.setMaxMintable(address(edition), mintId, maxMintable);

        assertEq(minter.mintInfo(address(edition), mintId).maxMintable, maxMintable);
    }

    function test_setMaxMintableRevertsIfCallerNotEditionOwnerOrAdmin(uint32 maxMintable) external {
        (SoundEditionV1 edition, MerkleDropMinter minter, uint128 mintId) = _createEditionAndMinter(0, 0, 1);
        address attacker = getFundedAccount(1);

        vm.expectRevert(IMinterModule.Unauthorized.selector);
        vm.prank(attacker);
        minter.setMaxMintable(address(edition), mintId, maxMintable);
    }

    function test_setMaxMintablePerAccount(uint32 maxMintablePerAccount) public {
        vm.assume(maxMintablePerAccount != 0);
        (SoundEditionV1 edition, MerkleDropMinter minter, uint128 mintId) = _createEditionAndMinter(0, 0, 1);

        vm.expectEmit(true, true, true, true);
        emit MaxMintablePerAccountSet(address(edition), mintId, maxMintablePerAccount);
        minter.setMaxMintablePerAccount(address(edition), mintId, maxMintablePerAccount);

        assertEq(minter.mintInfo(address(edition), mintId).maxMintablePerAccount, maxMintablePerAccount);
    }

    function test_setMaxMintablePerAccountRevertsIfCallerNotEditionOwnerOrAdmin(uint32 maxMintable) external {
        (SoundEditionV1 edition, MerkleDropMinter minter, uint128 mintId) = _createEditionAndMinter(0, 0, 1);
        address attacker = getFundedAccount(1);

        vm.expectRevert(IMinterModule.Unauthorized.selector);
        vm.prank(attacker);
        minter.setMaxMintablePerAccount(address(edition), mintId, maxMintable);
    }

    function test_setMaxMintablePerAccountWithZeroReverts() public {
        (SoundEditionV1 edition, MerkleDropMinter minter, uint128 mintId) = _createEditionAndMinter(0, 0, 1);

        vm.expectRevert(IMerkleDropMinter.MaxMintablePerAccountIsZero.selector);
        minter.setMaxMintablePerAccount(address(edition), mintId, 0);
    }

    function test_setMerkleRootHash(bytes32 merkleRootHash) public {
        vm.assume(merkleRootHash != bytes32(0));
        (SoundEditionV1 edition, MerkleDropMinter minter, uint128 mintId) = _createEditionAndMinter(0, 0, 1);

        vm.expectEmit(true, true, true, true);
        emit MerkleRootHashSet(address(edition), mintId, merkleRootHash);
        minter.setMerkleRootHash(address(edition), mintId, merkleRootHash);

        assertEq(minter.mintInfo(address(edition), mintId).merkleRootHash, merkleRootHash);
    }

    function test_setEmptyMerkleRootHashReverts() public {
        (SoundEditionV1 edition, MerkleDropMinter minter, uint128 mintId) = _createEditionAndMinter(0, 0, 1);

        vm.expectRevert(IMerkleDropMinter.MerkleRootHashIsEmpty.selector);
        minter.setMerkleRootHash(address(edition), mintId, bytes32(0));
    }

    function test_setCreateWithMerkleRootHashReverts() public {
        (SoundEditionV1 edition, MerkleDropMinter minter, ) = _createEditionAndMinter(0, 0, 1);

        vm.expectRevert(IMerkleDropMinter.MerkleRootHashIsEmpty.selector);

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
        (, MerkleDropMinter minter, ) = _createEditionAndMinter(0, 0, 1);

        bool supportsIMinterModule = minter.supportsInterface(type(IMinterModule).interfaceId);
        bool supportsIMerkleDropMint = minter.supportsInterface(type(IMerkleDropMinter).interfaceId);
        bool supports165 = minter.supportsInterface(type(IERC165).interfaceId);

        assertTrue(supports165);
        assertTrue(supportsIMinterModule);
        assertTrue(supportsIMerkleDropMint);
    }

    function test_moduleInterfaceId() public {
        (, MerkleDropMinter minter, ) = _createEditionAndMinter(0, 0, 1);

        assertTrue(type(IMerkleDropMinter).interfaceId == minter.moduleInterfaceId());
    }

    function test_mintInfo() public {
        SoundEditionV1 edition = createGenericEdition();

        MerkleDropMinter minter = new MerkleDropMinter(feeRegistry);
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
