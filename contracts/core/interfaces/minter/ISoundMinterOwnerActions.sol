// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

interface ISoundMinterOwnerActions {
    /**
     * @dev Sets the `paused` status for `edition`.
     * Calling conditions:
     * - The caller must be the edition's owner or an admin.
     */
    function setEditionMintPaused(
        address edition,
        uint256 mintId,
        bool paused
    ) external;

    /**
     * @dev Sets the time range for an edition mint.
     * Calling conditions:
     * - The caller must be the edition's owner or an admin.
     */
    function setTimeRange(
        address edition,
        uint256 mintId,
        uint32 startTime,
        uint32 endTime
    ) external;
}
