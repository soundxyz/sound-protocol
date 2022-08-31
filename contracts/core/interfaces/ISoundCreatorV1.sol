// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IMetadataModule } from "./IMetadataModule.sol";

/**
 * @title ISoundCreatorV1
 * @notice The interface for the Sound edition factory.
 */
interface ISoundCreatorV1 {
    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when an edition is created.
     * @param soundEdition The address of the edition.
     * @param deployer     The address of the deployer.
     */
    event SoundEditionCreated(address indexed soundEdition, address indexed deployer);

    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * Thrown if the implementation address is zero.
     */
    error ImplementationAddressCantBeZero();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Deploys a Sound edition minimal proxy contract.
     * @param name                         The name of the edition.
     * @param symbol                       The symbol of the edition.
     * @param metadataModule               The address of the metadata module.
     * @param baseURI                      The base URI of the edition's metadata.
     * @param contractURI                  The contract URI of the edition.
     * @param fundingRecipient             The edition's funding recipient address.
     * @param royaltyBPS                   The secondary sales royalty in basis points.
     * @param editionMaxMintable           The maximum number of tokens that can be minted.
     * @param mintRandomnessTokenThreshold The token count after which
     *                                     `SoundEdition.mintRandomness` gets locked.
     * @param mintRandomnessTimeThreshold  The timestamp after which
     *                                     `SoundEdition.mintRandomness` gets locked.
     * @return soundEdition The address of the deployed edition proxy.
     */
    function createSound(
        string memory name,
        string memory symbol,
        IMetadataModule metadataModule,
        string memory baseURI,
        string memory contractURI,
        address fundingRecipient,
        uint16 royaltyBPS,
        uint32 editionMaxMintable,
        uint32 mintRandomnessTokenThreshold,
        uint32 mintRandomnessTimeThreshold
    ) external returns (address payable soundEdition);

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev The address of the sound edition implementation.
     * @return The configured value.
     */
    function soundEditionImplementation() external returns (address);
}
