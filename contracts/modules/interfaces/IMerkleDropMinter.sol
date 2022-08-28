// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

/**
 * @dev Data unique to a merkle drop mint.
 */
struct EditionMintData {
    // Hash of the root node for the merkle tree drop
    bytes32 merkleRootHash;
    // The price at which each token will be sold, in ETH.
    uint96 price;
    // The maximum number of tokens that can can be minted for this sale.
    uint32 maxMintable;
    // The maximum number of tokens that a wallet can mint.
    uint32 maxMintablePerAccount;
    // The total number of tokens minted so far for this sale.
    uint32 totalMinted;
}

/**
 * @dev All the information about a merkle drop mint (combines EditionMintData with BaseData).
 */
struct MintInfo {
    uint32 startTime;
    uint32 endTime;
    uint16 affiliateFeeBPS;
    bool mintPaused;
    uint96 price;
    uint32 maxMintable;
    uint32 maxMintablePerAccount;
    uint32 totalMinted;
    bytes32 merkleRootHash;
}

/**
 * @title IMerkleDropMinter
 * @dev Interface for the `MerkleDropMinter` module.
 * @author Sound.xyz
 */
interface IMerkleDropMinter is IMinterModule {
    /**
     * @dev Emitted when a new merkle drop mint is created.
     * @param edition The edition address.
     * @param mintId The mint ID.
     * @param merkleRootHash The merkle root hash of the merkle tree containing the approved addresses.
     * @param price The price at which each token will be sold, in ETH.
     * @param startTime The time minting can begin.
     * @param endTime The time minting will end.
     * @param affiliateFeeBPS The affiliate fee in basis points.
     * @param maxMintable The maximum number of tokens that can be minted.
     * @param maxMintablePerAccount The maximum number of tokens that an account can mint.
     */
    event MerkleDropMintCreated(
        address indexed edition,
        uint256 indexed mintId,
        bytes32 merkleRootHash,
        uint96 price,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS,
        uint32 maxMintable,
        uint32 maxMintablePerAccount
    );

    /**
     * @dev Emitted when tokens are claimed by an account.
     * @param recipient The address of the account that claimed the tokens.
     * @param quantity The quantity of tokens claimed.
     */
    event DropClaimed(address recipient, uint32 quantity);

    /**
     * @dev The merkle proof is invalid.
     */
    error InvalidMerkleProof();

    /**
     * @dev The number of tokens minted has exceeded the number allowed for each account.
     */
    error ExceedsMaxPerAccount();

    /**
     * @dev Initializes merkle drop mint instance.
     * @param edition Address of the song edition contract we are minting for.
     * @param merkleRootHash bytes32 hash of the Merkle tree representing eligible mints.
     * @param price Sale price in ETH for minting a single token in `edition`.
     * @param startTime Start timestamp of sale (in seconds since unix epoch).
     * @param endTime End timestamp of sale (in seconds since unix epoch).
     * @param affiliateFeeBPS The affiliate fee in basis points.
     * @param maxMintable_ The maximum number of tokens that can can be minted for this sale.
     * @param maxMintablePerAccount_ The maximum number of tokens that a single account can mint.
     * @return mintId The ID of the new mint instance.
     */
    function createEditionMint(
        address edition,
        bytes32 merkleRootHash,
        uint96 price,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS,
        uint32 maxMintable_,
        uint32 maxMintablePerAccount_
    ) external returns (uint256 mintId);

    /**
     * @dev Mints a token for a particular mint instance.
     * @param mintId The ID of the mint instance.
     * @param requestedQuantity The quantity of tokens to mint.
     */
    function mint(
        address edition,
        uint256 mintId,
        uint32 requestedQuantity,
        bytes32[] calldata merkleProof,
        address affiliate
    ) external payable;

    /**
     * @dev Returns the amount of minted tokens for `account` in `mintData`.
     * @param edition Address of the edition.
     * @param mintId Mint identifier.
     * @param account Address of the account.
     * @return tally The number of minted tokens for the account.
     */
    function mintedTallies(
        address edition,
        uint256 mintId,
        address account
    ) external view returns (uint256);

    /**
     * @dev Returns IMerkleDropMinter.MintInfo instance containing the full minter parameter set.
     * @param edition The edition to get the mint instance for.
     * @param mintId The ID of the mint instance.
     */
    function mintInfo(address edition, uint256 mintId) external view returns (MintInfo memory);
}
