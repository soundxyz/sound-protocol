// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";

/**
 * @title IGoldenEggMetadata
 * @notice The interface for the Sound Golden Egg metadata module.
 */
interface IGoldenEggMetadata is IMetadataModule {
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
    function getGoldenEggTokenId(ISoundEditionV1 edition) external view returns (uint256 tokenId);
}
