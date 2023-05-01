// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";

/**
 * @title IMinterAdapter
 * @dev Interface for the `MinterAdapter` module.
 * @author Sound.xyz
 */
interface IMinterAdapter is IERC165 {
    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when a mint happens via the minter adapter.
     * @param minter        The address of the EditionMaxMinterV2 or RangeEditionMinterV2.
     * @param edition       The address of the edition.
     * @param fromTokenId   The starting token ID in the batch minted.
     * @param quantity      The number of tokens minted.
     * @param to            The address to mint the tokens to.
     * @param attributionId The attribution ID.
     */
    event AdapterMinted(
        address minter,
        address indexed edition,
        uint256 indexed fromTokenId,
        uint32 quantity,
        address to,
        uint256 indexed attributionId
    );

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Mints tokens for a given edition.
     * @param minter         The address of the EditionMaxMinterV2 or RangeEditionMinterV2.
     * @param edition        Address of the song edition contract we are minting for.
     * @param mintId         The mint ID.
     * @param to             The address to mint to.
     * @param quantity       Token quantity to mint in song `edition`.
     * @param affiliate      The affiliate address.
     * @param attributionId  The attribution ID.
     */
    function mintTo(
        address minter,
        address edition,
        uint128 mintId,
        address to,
        uint32 quantity,
        address affiliate,
        uint256 attributionId
    ) external payable;

    /**
     * @dev Buys tokens from the Sound Automated Market (SAM).
     * @param sam            The address of the SAM contract.
     * @param edition        Address of the song edition contract we are minting for.
     * @param to             The address to mint to.
     * @param quantity       Token quantity to mint in song `edition`.
     * @param affiliate      The affiliate address.
     * @param affiliateProof The Merkle proof for the affiliate.
     * @param attributionId  The attribution ID.
     * @param excessRefundTo The address to refund excess ETH to.
     */
    function samBuy(
        address sam,
        address edition,
        address to,
        uint32 quantity,
        address affiliate,
        bytes32[] calldata affiliateProof,
        uint256 attributionId,
        address excessRefundTo
    ) external payable;

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev The interface ID of the minter.
     * @return The constant value.
     */
    function moduleInterfaceId() external view returns (bytes4);
}
