// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";
import { ISoundEditionV2 } from "@core/interfaces/ISoundEditionV2.sol";

/**
 * @title ISoundOnChainMetadata
 * @notice Sound metadata module with on-chain JSON.
 */
interface ISoundOnChainMetadata is IMetadataModule {
    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when a new template is created.
     * @param templateId The template ID for the template.
     */
    event TemplateCreated(string templateId);

    /**
     * @dev Emitted when the values for a (`edition`, `tier`) is set.
     * @param edition    The address of the Sound Edition.
     * @param compressed Whether the values JSON is compressed with `solady.LibZip.flzCompress`.
     */
    event ValuesSet(address indexed edition, bool compressed);

    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * @dev Unauthorized caller.
     */
    error Unauthorized();

    /**
     * @dev The template ID has been taken.
     */
    error TemplateIdTaken();

    /**
     * @dev The template does not exist.
     */
    error TemplateDoesNotExist();

    /**
     * @dev The values do not exist.
     */
    error ValuesDoNotExist();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Creates a new template.
     * @param templateJSON The template JSON.
     * @return templateId The ID for the template.
     */
    function createTemplate(string memory templateJSON) external returns (string memory templateId);

    /**
     * @dev Sets the values for the (`edition`, `tier`).
     * @param edition    The address of the Sound Edition.
     * @param valuesJSON The JSON string of values.
     */
    function setValues(address edition, string memory valuesJSON) external;

    /**
     * @dev Sets the values for the (`edition`, `tier`).
     * @param edition    The address of the Sound Edition.
     * @param compressed The JSON string of values, in compressed form.
     */
    function setValuesCompressed(address edition, bytes memory compressed) external;

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev Returns the deterministic template ID.
     * @param templateJSON The template JSON.
     * @return templateId The template ID.
     */
    function predictTemplateId(string memory templateJSON) external view returns (string memory templateId);

    /**
     * @dev Returns the template JSON for the template ID.
     * @param templateId The template ID.
     * @return templateJSON The template JSON.
     */
    function getTemplate(string memory templateId) external view returns (string memory templateJSON);

    /**
     * @dev Returns the template ID and the values JSON for the (`edition`, `tier`).
     * @param edition The address of the Sound Edition.
     * @return valuesJSON The values JSON.
     */
    function getValues(address edition) external view returns (string memory valuesJSON);

    /**
     * @dev Returns the JSON string, assuming the following parameters.
     * @param edition     The edition address.
     * @param tokenId     The token ID.
     * @param sn          The serial number of the token (index of the token in its tier + 1).
     * @param tier        The token tier.
     * @param isGoldenEgg Whether the token is a golden egg.
     * @return json The JSON string.
     */
    function rawTokenJSON(
        address edition,
        uint256 tokenId,
        uint256 sn,
        uint8 tier,
        bool isGoldenEgg
    ) external view returns (string memory json);

    /**
     * @dev When registered on a SoundEdition proxy, its `tokenURI` redirects execution to this `tokenURI`.
     * @param tokenId The token ID to retrieve the token URI for.
     * @return uri The token URI string.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory uri);

    /**
     * @dev Returns token ID for the golden egg after the `mintRandomness` is locked, else returns 0.
     * @param edition The edition address.
     * @param tier    The tier of the token,
     * @return tokenId The token ID for the golden egg.
     */
    function goldenEggTokenId(address edition, uint8 tier) external view returns (uint256 tokenId);
}
