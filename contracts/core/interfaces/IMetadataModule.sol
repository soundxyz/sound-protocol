// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

/**
 * @title IMetadataModule
 * @notice The interface for custom Sound metadata modules.
 */
interface IMetadataModule {
    /**
     * @dev When implemented, SoundEdition's `tokenURI` redirects execution to this `tokenURI`.
     * @param tokenId The token ID to retrieve the token URI for.
     * @return The token URI string.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
