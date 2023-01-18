// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";

/**
 * @title IGoldenEggMetadata
 * @notice The interface for the Sound Golden Egg metadata module.
 */
interface IGoldenEggMetadata is IMetadataModule {
    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when the `tokenId` for `edition` with a json is set.
     * @param edition Address of the song edition contract we are minting for.
     * @param tokenId The maximum `tokenId` for `edition` that has a numberd json.
     */
    event NumberUptoSet(address indexed edition, uint256 tokenId);

    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * @dev Unauthorized caller.
     */
    error Unauthorized();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Sets the maximum `tokenId` for `edition` that has a numbered json.
     * @param edition Address of the song edition contract we are minting for.
     * @param tokenId The maximum `tokenId` for `edition` that has a numberd json.
     */
    function setNumberedUpto(address edition, uint256 tokenId) external;

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev When registered on a SoundEdition proxy, its `tokenURI` redirects execution to this `tokenURI`.
     * @param tokenId The token ID to retrieve the token URI for.
     * @return The token URI string.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);

    /**
     * @dev Returns token ID for the golden egg after the `mintRandomness` is locked, else returns 0.
     * @param edition The edition address.
     * @return tokenId The token ID for the golden egg.
     */
    function getGoldenEggTokenId(address edition) external view returns (uint256 tokenId);
}
