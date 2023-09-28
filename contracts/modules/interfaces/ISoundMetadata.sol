// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";
import { ISoundEditionV2 } from "@core/interfaces/ISoundEditionV2.sol";

/**
 * @title ISoundMetadata
 * @notice The interface for the Sound Golden Egg metadata module with open edition compatibility.
 */
interface ISoundMetadata is IMetadataModule {
    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when the `tokenId` for `edition` with a json is set.
     * @param edition The address of the Sound Edition.
     * @param tokenId The maximum `tokenId` for `edition` that has a numberd json.
     */
    event NumberUpToSet(address indexed edition, uint32 tokenId);

    /**
     * @dev Emitted when the base URI for (`edition`, `tier`) is set.
     * @param edition The address of the Sound Edition.
     * @param tier    The tier.
     * @param uri     The base URI.
     */
    event BaseURISet(address indexed edition, uint8 tier, string uri);

    /**
     * @dev Emitted when the option use the tier token ID is set.
     * @param edition The address of the Sound Edition.
     * @param value   Whether to use the tier token ID for `edition`.
     */
    event UseTierTokenIdIndexSet(address indexed edition, bool value);

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
     * @param edition The address of the Sound Edition.
     * @param tokenId The maximum `tokenId` for `edition` that has a numberd json.
     */
    function setNumberedUpTo(address edition, uint32 tokenId) external;

    /**
     * @dev Sets the base URI for (`edition`, `tier`).
     * @param edition The address of the Sound Edition.
     * @param tier    The tier.
     * @param uri     The base URI.
     */
    function setBaseURI(
        address edition,
        uint8 tier,
        string calldata uri
    ) external;

    /**
     * @dev Sets whether to use the tier token ID index Defaults to true.
     * @param edition The address of the Sound Edition.
     * @param value   Whether to use the tier token ID index for `edition`.
     */
    function setUseTierTokenIdIndex(address edition, bool value) external;

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev Returns the default maximum `tokenId` for `edition` that has a numbered json.
     * @return The constant value
     */
    function DEFAULT_NUMBER_UP_TO() external pure returns (uint32);

    /**
     * @dev Returns the maximum `tokenId` for `edition` that has a numbered json.
     * @param edition The address of the Sound Edition.
     * @return The configured value.
     */
    function numberedUpTo(address edition) external view returns (uint32);

    /**
     * @dev Returns whether to use the tier token ID index. Defaults to true.
     * @param edition The address of the Sound Edition.
     * @return The configured value.
     */
    function useTierTokenIdIndex(address edition) external view returns (bool);

    /**
     * @dev Returns the base URI override for the (`edition`, `tier`).
     * @param edition The address of the Sound Edition.
     * @param tier    The tier.
     * @return The configured value.
     */
    function baseURI(address edition, uint8 tier) external view returns (string memory);

    /**
     * @dev When registered on a SoundEdition proxy, its `tokenURI` redirects execution to this `tokenURI`.
     * @param tokenId The token ID to retrieve the token URI for.
     * @return The token URI string.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);

    /**
     * @dev Returns token ID for the golden egg after the `mintRandomness` is locked, else returns 0.
     * @param edition The edition address.
     * @param tier    The tier of the token,
     * @return tokenId The token ID for the golden egg.
     */
    function goldenEggTokenId(address edition, uint8 tier) external view returns (uint256 tokenId);
}
