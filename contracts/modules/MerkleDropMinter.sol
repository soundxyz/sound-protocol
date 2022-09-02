// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

import { MerkleProof } from "openzeppelin/utils/cryptography/MerkleProof.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { BaseMinter } from "@modules/BaseMinter.sol";
import { IMerkleDropMinter, EditionMintData, MintInfo } from "./interfaces/IMerkleDropMinter.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

/**
 * @title MerkleDropMinter
 * @dev Module for minting Sound editions using a merkle tree of approved accounts.
 * @author Sound.xyz
 */
contract MerkleDropMinter is IMerkleDropMinter, BaseMinter {
    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev Edition mint data.
     *      Maps `edition` => `mintId` => value.
     */
    mapping(address => mapping(uint128 => EditionMintData)) internal _editionMintData;

    /**
     * @dev Number of tokens minted by each buyer address
     *      Maps: `edition` => `mintId` => `buyer` => value.
     */
    mapping(address => mapping(uint128 => mapping(address => uint256))) public mintedTallies;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor(ISoundFeeRegistry feeRegistry_) BaseMinter(feeRegistry_) {}

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IMerkleDropMinter
     */
    function createEditionMint(
        address edition,
        bytes32 merkleRootHash,
        uint96 price,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS,
        uint32 maxMintable,
        uint32 maxMintablePerAccount
    ) public returns (uint128 mintId) {
        mintId = _createEditionMint(edition, startTime, endTime, affiliateFeeBPS);

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.merkleRootHash = merkleRootHash;
        data.price = price;
        data.maxMintable = maxMintable;
        data.maxMintablePerAccount = maxMintablePerAccount;
        // prettier-ignore
        emit MerkleDropMintCreated(
            edition,
            mintId,
            merkleRootHash,
            price,
            startTime,
            endTime,
            affiliateFeeBPS,
            maxMintable,
            maxMintablePerAccount
        );
    }

    /**
     * @inheritdoc IMerkleDropMinter
     */
    function mint(
        address edition,
        uint128 mintId,
        uint32 requestedQuantity,
        bytes32[] calldata merkleProof,
        address affiliate
    ) public payable {
        EditionMintData storage data = _editionMintData[edition][mintId];

        // Increase `totalMinted` by `requestedQuantity`.
        // Require that the increased value does not exceed `maxMintable`.
        data.totalMinted = _incrementTotalMinted(data.totalMinted, requestedQuantity, data.maxMintable);

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        bool valid = MerkleProof.verify(merkleProof, data.merkleRootHash, leaf);
        if (!valid) revert InvalidMerkleProof();

        unchecked {
            uint256 userMintedBalance = mintedTallies[edition][mintId][msg.sender];
            // Check the additional requestedQuantity does not exceed the set maximum.
            // If `requestedQuantity` is large enough to cause an overflow,
            // `_mint` will give an out of gas error.
            uint256 tally = userMintedBalance + requestedQuantity;
            if (tally > data.maxMintablePerAccount) revert ExceedsMaxPerAccount();
            // Update the minted tally for this account
            mintedTallies[edition][mintId][msg.sender] = tally;
        }

        _mint(edition, mintId, requestedQuantity, affiliate);

        emit DropClaimed(msg.sender, requestedQuantity);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IMinterModule
     */
    function totalPrice(
        address edition,
        uint128 mintId,
        address, /* minter */
        uint32 quantity
    ) public view virtual override(BaseMinter, IMinterModule) returns (uint128) {
        unchecked {
            // Won't overflow, as `price` is 96 bits, and `quantity` is 32 bits.
            return _editionMintData[edition][mintId].price * quantity;
        }
    }

    /**
     * @inheritdoc IMerkleDropMinter
     */
    function mintInfo(address edition, uint128 mintId) public view returns (MintInfo memory) {
        BaseData memory baseData = _baseData[edition][mintId];
        EditionMintData storage mintData = _editionMintData[edition][mintId];

        MintInfo memory combinedMintData = MintInfo(
            baseData.startTime,
            baseData.endTime,
            baseData.affiliateFeeBPS,
            baseData.mintPaused,
            mintData.price,
            mintData.maxMintable,
            mintData.maxMintablePerAccount,
            mintData.totalMinted,
            mintData.merkleRootHash
        );

        return combinedMintData;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, BaseMinter) returns (bool) {
        return BaseMinter.supportsInterface(interfaceId) || interfaceId == type(IMerkleDropMinter).interfaceId;
    }

    /**
     * @inheritdoc IMinterModule
     */
    function moduleInterfaceId() public pure returns (bytes4) {
        return type(IMerkleDropMinter).interfaceId;
    }
}
