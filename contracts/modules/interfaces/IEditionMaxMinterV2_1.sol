// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IMinterModuleV2_1 } from "@core/interfaces/IMinterModuleV2_1.sol";

/**
 * @dev All the information about a edition max mint.
 */
struct MintInfo {
    uint32 startTime;
    uint32 endTime;
    uint16 affiliateFeeBPS;
    bool mintPaused;
    uint96 price;
    uint32 maxMintableLower;
    uint32 maxMintableUpper;
    uint32 maxMintablePerAccount;
    uint32 totalMinted;
    uint32 cutoffTime;
    bytes32 affiliateMerkleRoot;
    uint16 platformFeeBPS;
    uint96 platformFlatFee;
    uint96 platformPerTxFlatFee;
}

/**
 * @title IEditionMaxMinterV2_1
 * @dev Interface for the `EditionMaxMinterV2_1` module.
 * @author Sound.xyz
 */
interface IEditionMaxMinterV2_1 is IMinterModuleV2_1 {
    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when a edition max is created.
     * @param edition               Address of the song edition contract we are minting for.
     * @param mintId                The mint ID.
     * @param price                 Sale price in ETH for minting a single token in `edition`.
     * @param startTime             Start timestamp of sale (in seconds since unix epoch).
     * @param endTime               End timestamp of sale (in seconds since unix epoch).
     * @param affiliateFeeBPS       The affiliate fee in basis points.
     * @param maxMintablePerAccount The maximum number of tokens that can be minted per account.
     */
    event EditionMaxMintCreated(
        address indexed edition,
        uint128 mintId,
        uint96 price,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS,
        uint32 maxMintablePerAccount
    );

    /**
     * @dev Emitted when the `price` is changed for (`edition`, `mintId`).
     * @param edition Address of the song edition contract we are minting for.
     * @param mintId  The mint ID.
     * @param price   Sale price in ETH for minting a single token in `edition`.
     */
    event PriceSet(address indexed edition, uint128 mintId, uint96 price);

    /**
     * @dev Emitted when the `maxMintablePerAccount` is changed for (`edition`, `mintId`).
     * @param edition               Address of the song edition contract we are minting for.
     * @param mintId                The mint ID.
     * @param maxMintablePerAccount The maximum number of tokens that can be minted per account.
     */
    event MaxMintablePerAccountSet(address indexed edition, uint128 mintId, uint32 maxMintablePerAccount);

    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * @dev The number of tokens minted has exceeded the number allowed for each account.
     */
    error ExceedsMaxPerAccount();

    /**
     * @dev The max mintable per account cannot be zero.
     */
    error MaxMintablePerAccountIsZero();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Initializes a range mint instance
     * @param edition               Address of the song edition contract we are minting for.
     * @param price                 Sale price in ETH for minting a single token in `edition`.
     * @param startTime             Start timestamp of sale (in seconds since unix epoch).
     * @param endTime               End timestamp of sale (in seconds since unix epoch).
     * @param affiliateFeeBPS       The affiliate fee in basis points.
     * @param maxMintablePerAccount The maximum number of tokens that can be minted by an account.
     * @return mintId The ID for the new mint instance.
     */
    function createEditionMint(
        address edition,
        uint96 price,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS,
        uint32 maxMintablePerAccount
    ) external returns (uint128 mintId);

    /**
     * @dev Mints tokens for a given edition.
     * @param edition        Address of the song edition contract we are minting for.
     * @param mintId         The mint ID.
     * @param to             The address to mint to.
     * @param quantity       Token quantity to mint in song `edition`.
     * @param affiliate      The affiliate address.
     * @param affiliateProof The Merkle proof needed for verifying the affiliate, if any.
     * @param attributionId  The attribution ID.
     */
    function mintTo(
        address edition,
        uint128 mintId,
        address to,
        uint32 quantity,
        address affiliate,
        bytes32[] calldata affiliateProof,
        uint256 attributionId
    ) external payable;

    /**
     * @dev Mints tokens for a given edition.
     * @param edition   Address of the song edition contract we are minting for.
     * @param mintId    The mint ID.
     * @param quantity  Token quantity to mint in song `edition`.
     * @param affiliate The affiliate address.
     */
    function mint(
        address edition,
        uint128 mintId,
        uint32 quantity,
        address affiliate
    ) external payable;

    /**
     * @dev Sets the `price` for (`edition`, `mintId`).
     * @param edition Address of the song edition contract we are minting for.
     * @param mintId  The mint ID.
     * @param price   Sale price in ETH for minting a single token in `edition`.
     */
    function setPrice(
        address edition,
        uint128 mintId,
        uint96 price
    ) external;

    /**
     * @dev Sets the `maxMintablePerAccount` for (`edition`, `mintId`).
     * @param edition               Address of the song edition contract we are minting for.
     * @param mintId                The mint ID.
     * @param maxMintablePerAccount The maximum number of tokens that can be minted by an account.
     */
    function setMaxMintablePerAccount(
        address edition,
        uint128 mintId,
        uint32 maxMintablePerAccount
    ) external;

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev Returns {IEditionMaxMinterV2_1.MintInfo} instance containing the full minter parameter set.
     * @param edition The edition to get the mint instance for.
     * @param mintId  The ID of the mint instance.
     * @return mintInfo Information about this mint.
     */
    function mintInfo(address edition, uint128 mintId) external view returns (MintInfo memory);
}
