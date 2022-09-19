// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

/**
 * @dev Data unique to a range edition mint.
 */
struct EditionMintData {
    // The price at which each token will be sold, in ETH.
    uint96 price;
    // The timestamp (in seconds since unix epoch) after which the
    // max amount of tokens mintable will drop from
    // `maxMintableUpper` to `maxMintableLower`.
    uint32 cutoffTime;
    // The total number of tokens minted. Includes permissioned mints.
    uint32 totalMinted;
    // The lower limit of the maximum number of tokens that can be minted.
    uint32 maxMintableLower;
    // The upper limit of the maximum number of tokens that can be minted.
    uint32 maxMintableUpper;
    // The maximum number of tokens that a wallet can mint.
    uint32 maxMintablePerAccount;
}

/**
 * @dev All the information about a range edition mint (combines EditionMintData with BaseData).
 */
struct MintInfo {
    uint32 startTime;
    uint32 endTime;
    uint16 affiliateFeeBPS;
    bool mintPaused;
    uint96 price;
    uint32 maxMintableUpper;
    uint32 maxMintableLower;
    uint32 maxMintablePerAccount;
    uint32 totalMinted;
    uint32 cutoffTime;
}

/**
 * @title IRangeEditionMinter
 * @dev Interface for the `RangeEditionMinter` module.
 * @author Sound.xyz
 */
interface IRangeEditionMinter is IMinterModule {
    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when a range edition is created.
     * @param edition          Address of the song edition contract we are minting for.
     * @param mintId           The mint ID.
     * @param price            Sale price in ETH for minting a single token in `edition`.
     * @param startTime        Start timestamp of sale (in seconds since unix epoch).
     * @param cutoffTime       The timestamp (in seconds since unix epoch) after which the
     *                         max amount of tokens mintable will drop from
     *                         `maxMintableUpper` to `maxMintableLower`.
     * @param endTime          End timestamp of sale (in seconds since unix epoch).
     * @param affiliateFeeBPS  The affiliate fee in basis points.
     * @param maxMintableLower The lower limit of the maximum number of tokens that can be minted.
     * @param maxMintableUpper The upper limit of the maximum number of tokens that can be minted.
     */
    event RangeEditionMintCreated(
        address indexed edition,
        uint128 indexed mintId,
        uint96 price,
        uint32 startTime,
        uint32 cutoffTime,
        uint32 endTime,
        uint16 affiliateFeeBPS,
        uint32 maxMintableLower,
        uint32 maxMintableUpper,
        uint32 maxMintablePerAccount
    );

    event CutoffTimeSet(address indexed edition, uint128 indexed mintId, uint32 cutoffTime);

    /**
     * @dev Emitted when the max mintable range is updated.
     * @param edition          Address of the song edition contract we are minting for.
     * @param mintId           The mint ID.
     * @param maxMintableLower The lower limit of the maximum number of tokens that can be minted.
     * @param maxMintableUpper The upper limit of the maximum number of tokens that can be minted.
     */
    event MaxMintableRangeSet(
        address indexed edition,
        uint128 indexed mintId,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    );

    /**
     * @dev Emitted when the `price` is changed for (`edition`, `mintId`).
     * @param edition Address of the song edition contract we are minting for.
     * @param mintId  The mint ID.
     * @param price   Sale price in ETH for minting a single token in `edition`.
     */
    event PriceSet(address indexed edition, uint128 indexed mintId, uint96 price);

    /**
     * @dev Emitted when the `maxMintablePerAccount` is changed for (`edition`, `mintId`).
     * @param edition               Address of the song edition contract we are minting for.
     * @param mintId                The mint ID.
     * @param maxMintablePerAccount The maximum number of tokens that can be minted per account.
     */
    event MaxMintablePerAccountSet(address indexed edition, uint128 indexed mintId, uint32 maxMintablePerAccount);

    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * @dev The `maxMintableLower` must not be greater than `maxMintableUpper`.
     */
    error InvalidMaxMintableRange();

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

    /*
     * @dev Initializes a range mint instance
     * @param edition                Address of the song edition contract we are minting for.
     * @param price                  Sale price in ETH for minting a single token in `edition`.
     * @param startTime              Start timestamp of sale (in seconds since unix epoch).
     * @param cutoffTime             The timestamp (in seconds since unix epoch) after which the
     *                               max amount of tokens mintable will drop from
     *                               `maxMintableUpper` to `maxMintableLower`.
     * @param endTime                End timestamp of sale (in seconds since unix epoch).
     * @param affiliateFeeBPS        The affiliate fee in basis points.
     * @param maxMintableLower       The lower limit of the maximum number of tokens that can be minted.
     * @param maxMintableUpper       The upper limit of the maximum number of tokens that can be minted.
     * @param maxMintablePerAccount_ The maximum number of tokens that can be minted by an account.
     * @return mintId The ID for the new mint instance.
     */
    function createEditionMint(
        address edition,
        uint96 price,
        uint32 startTime,
        uint32 cutoffTime,
        uint32 endTime,
        uint16 affiliateFeeBPS,
        uint32 maxMintableLower,
        uint32 maxMintableUpper,
        uint32 maxMintablePerAccount_
    ) external returns (uint128 mintId);

    /*
     * @dev Sets the time range.
     * @param edition     Address of the song edition contract we are minting for.
     * @param startTime   Start timestamp of sale (in seconds since unix epoch).
     * @param cutoffTime  The timestamp (in seconds since unix epoch) after which the
     *                    max amount of tokens mintable will drop from
     *                    `maxMintableUpper` to `maxMintableLower`.
     * @param endTime     End timestamp of sale (in seconds since unix epoch).
     */
    function setTimeRange(
        address edition,
        uint128 mintId,
        uint32 startTime,
        uint32 cutoffTime,
        uint32 endTime
    ) external;

    /*
     * @dev Sets the max mintable range.
     * @param edition          Address of the song edition contract we are minting for.
     * @param maxMintableLower The lower limit of the maximum number of tokens that can be minted.
     * @param maxMintableUpper The upper limit of the maximum number of tokens that can be minted.
     */
    function setMaxMintableRange(
        address edition,
        uint128 mintId,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    ) external;

    /*
     * @dev Mints tokens for a given edition.
     * @param edition  Address of the song edition contract we are minting for.
     * @param quantity Token quantity to mint in song `edition`.
     */
    function mint(
        address edition,
        uint128 mintId,
        uint32 quantity,
        address affiliate
    ) external payable;

    /*
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

    /*
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
     * @dev Returns {IRangeEditionMinter.MintInfo} instance containing the full minter parameter set.
     * @param edition The edition to get the mint instance for.
     * @param mintId  The ID of the mint instance.
     * @return mintInfo Information about this mint.
     */
    function mintInfo(address edition, uint128 mintId) external view returns (MintInfo memory);
}
