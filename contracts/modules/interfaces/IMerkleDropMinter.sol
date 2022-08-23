// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

/**
 * @title IMerkleDropMinter
 * @dev Interface for the `MerkleDropMinter` module.
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
     * @param maxMintable The maximum number of tokens that can be minted.
     * @param maxMintablePerAccount The maximum number of tokens that a wallet can mint.
     */
    event MerkleDropMintCreated(
        address indexed edition,
        uint256 indexed mintId,
        bytes32 merkleRootHash,
        uint256 price,
        uint32 startTime,
        uint32 endTime,
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
     * @param price_ Sale price in ETH for minting a single token in `edition`.
     * @param startTime Start timestamp of sale (in seconds since unix epoch).
     * @param endTime End timestamp of sale (in seconds since unix epoch).
     * @param maxMintable_ The maximum number of tokens that can can be minted for this sale.
     * @param maxMintablePerAccount_ The maximum number of tokens that a single wallet can mint.
     * @return mintId The ID of the new mint instance.
     */
    function createEditionMint(
        address edition,
        bytes32 merkleRootHash,
        uint256 price_,
        uint32 startTime,
        uint32 endTime,
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
     * @dev Returns the amount of claimed tokens for `wallet` in `mintData`.
     * @param edition Address of the edition.
     * @param mintId Mint identifier.
     * @param wallet Address of the wallet.
     * @return claimedQuantity is defaulted to 0 when the wallet address key is not found
     * in the `claimed` map.
     */
    function getClaimed(
        address edition,
        uint256 mintId,
        address wallet
    ) external view returns (uint256);
}
