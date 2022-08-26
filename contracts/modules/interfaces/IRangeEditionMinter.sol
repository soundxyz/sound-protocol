// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

/**
 * @dev Data unique to a range edition mint.
 */
struct EditionMintData {
    // The price at which each token will be sold, in ETH.
    uint256 price;
    // The timestamp (in seconds since unix epoch) after which the
    // max amount of tokens mintable will drop from
    // `maxMintableUpper` to `maxMintableLower`.
    uint32 closingTime;
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
    bool mintPaused;
    uint256 price;
    uint32 maxMintable;
    uint32 maxMintablePerAccount;
    uint32 totalMinted;
    uint32 closingTime;
}

/**
 * @title Interface for the standard mint function.
 */
interface IRangeEditionMinter is IMinterModule {
    event RangeEditionMintCreated(
        address indexed edition,
        uint256 indexed mintId,
        uint256 price,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime,
        uint32 maxMintableLower,
        uint32 maxMintableUpper,
        uint32 maxMintablePerAccount
    );

    event ClosingTimeSet(address indexed edition, uint256 indexed mintId, uint32 closingTime);

    event MaxMintableRangeSet(
        address indexed edition,
        uint256 indexed mintId,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    );

    /**
     * The following condition must hold: `maxMintableLower` < `maxMintableUpper`.
     */
    error InvalidMaxMintableRange(uint32 maxMintableLower, uint32 maxMintableUpper);

    // The number of tokens minted has exceeded the number allowed for each wallet.
    error ExceedsMaxPerAccount();

    /*
     * @dev Initializes the configuration for an edition mint.
     * @param edition Address of the song edition contract we are minting for.
     * @param price Sale price in ETH for minting a single token in `edition`.
     * @param startTime Start timestamp of sale (in seconds since unix epoch).
     * @param closingTime The timestamp (in seconds since unix epoch) after which the
     * max amount of tokens mintable will drop from
     * `maxMintableUpper` to `maxMintableLower`.
     * @param endTime End timestamp of sale (in seconds since unix epoch).
     * @param maxMintableLower The lower limit of the maximum number of tokens that can be minted.
     * @param maxMintableUpper The upper limit of the maximum number of tokens that can be minted.
     */
    function createEditionMint(
        address edition,
        uint256 price_,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime,
        uint32 maxMintableLower,
        uint32 maxMintableUpper,
        uint32 maxMintablePerAccount_
    ) external returns (uint256 mintId);

    /*
     * @dev Sets the time range.
     * @param edition Address of the song edition contract we are minting for.
     * @param startTime Start timestamp of sale (in seconds since unix epoch).
     * @param closingTime The timestamp (in seconds since unix epoch) after which the
     * max amount of tokens mintable will drop from
     * `maxMintableUpper` to `maxMintableLower`.
     * @param endTime End timestamp of sale (in seconds since unix epoch).
     */
    function setTimeRange(
        address edition,
        uint256 mintId,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime
    ) external;

    /*
     * @dev Sets the max mintable range.
     * @param edition Address of the song edition contract we are minting for.
     * @param maxMintableLower The lower limit of the maximum number of tokens that can be minted.
     * @param maxMintableUpper The upper limit of the maximum number of tokens that can be minted.
     */
    function setMaxMintableRange(
        address edition,
        uint256 mintId,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    ) external;

    /*
     * @dev Mints tokens for a given edition.
     * @param edition Address of the song edition contract we are minting for.
     * @param quantity Token quantity to mint in song `edition`.
     */
    function mint(
        address edition,
        uint256 mintId,
        uint32 quantity,
        address affiliate
    ) external payable;
}
