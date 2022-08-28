// SPDX-License-Identifier: GPL-3.0-or-later
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
    uint16 affiliateFeeBPS;
    bool mintPaused;
    uint96 price;
    uint32 maxMintableUpper;
    uint32 maxMintableLower;
    uint32 maxMintablePerAccount;
    uint32 totalMinted;
    uint32 closingTime;
}

/**
 * @title IRangeEditionMinter
 * @dev Interface for the `RangeEditionMinter` module.
 * @author Sound.xyz
 */
interface IRangeEditionMinter is IMinterModule {
    event RangeEditionMintCreated(
        address indexed edition,
        uint256 indexed mintId,
        uint96 price,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime,
        uint16 affiliateFeeBPS,
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

    // The number of tokens minted has exceeded the number allowed for each account.
    error ExceedsMaxPerAccount();

    /*
     * @dev Initializes a range mint instance
     * @param edition Address of the song edition contract we are minting for.
     * @param price Sale price in ETH for minting a single token in `edition`.
     * @param startTime Start timestamp of sale (in seconds since unix epoch).
     * @param closingTime The timestamp (in seconds since unix epoch) after which the
     * max amount of tokens mintable will drop from
     * `maxMintableUpper` to `maxMintableLower`.
     * @param endTime End timestamp of sale (in seconds since unix epoch).
     * @param affiliateFeeBPS The affiliate fee in basis points.
     * @param maxMintableLower The lower limit of the maximum number of tokens that can be minted.
     * @param maxMintableUpper The upper limit of the maximum number of tokens that can be minted.
     * @return mintId The ID for the new mint instance.
     */
    function createEditionMint(
        address edition,
        uint96 price,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime,
        uint16 affiliateFeeBPS,
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
