// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

interface IMinterModuleEventsAndErrors {
    /**
     * @notice Emitted when the mint configuration for an `edition` is created.
     */
    event MintConfigCreated(
        address indexed edition,
        address indexed creator,
        uint256 mintId,
        uint32 startTime,
        uint32 endTime
    );

    /**
     * @notice Emitted when the `paused` status of `edition` is updated.
     */
    event MintPausedSet(address indexed edition, uint256 mintId, bool paused);

    /**
     * @notice Emitted when the `startTime` and `endTime` are updated.
     */
    event TimeRangeSet(address indexed edition, uint256 indexed mintId, uint32 startTime, uint32 endTime);

    /**
     * The Ether value paid is not the exact value required.
     */
    error WrongEtherValue(uint256 paid, uint256 required);

    /**
     * The number minted has exceeded the max mintable amount.
     */
    error MaxMintableReached(uint32 maxMintable);

    /**
     * The mint is not opened.
     */
    error MintNotOpen(uint256 blockTimestamp, uint32 startTime, uint32 endTime);

    /**
     * The mint is paused.
     */
    error MintPaused();

    /**
     * The `startTime` is not less than the `endTime`.
     */
    error InvalidTimeRange();

    /**
     * Unauthorized caller
     */
    error Unauthorized();
}
