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
     * @param soundEdition the address of the edition.
     * @param deployer The address of the deployer.
     */
    event SoundEditionCreated(address indexed soundEdition, address indexed deployer);

    /**
     * @dev Emitted when the edition implementation address is set.
     * @param newImplementation The new implementation address to be set.
     */
    event SoundEditionImplementationSet(address newImplementation);

    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * @dev Thrown if the implementation address is zero.
     */
    error ImplementationAddressCantBeZero();

    /**
     * @dev Thrown if the lengths the input arrays are not equal.
     */
    error ArrayLengthsMismatch();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Initialize the creator proxy with the edition implementation.
     * @param _soundEditionImplementation The address of the Sound edition implementation.
     */
    function initialize(address _soundEditionImplementation) external;

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

    /**
     * @dev Creates a Sound Edition proxy, initializes it,
     *      and creates mint configurations on a given set of minter addresses.
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
     * @param contracts                    A list of contracts to call. Entries equal to the
     *                                     sound creator factory's address will be replaced
     *                                     with the sound edition address.
     * @param data                         A list of calldata created via `abi.encodeWithSelector`
     *                                     that are to be passed to the contracts.
     *                                     Any word equal to the sound creator factory's address
     *                                     will be replaced with the sound edition address.
     * @return soundEdition The address of the deployed edition proxy.
     */
    function createSoundAndMints(
        string memory name,
        string memory symbol,
        IMetadataModule metadataModule,
        string memory baseURI,
        string memory contractURI,
        address fundingRecipient,
        uint16 royaltyBPS,
        uint32 editionMaxMintable,
        uint32 mintRandomnessTokenThreshold,
        uint32 mintRandomnessTimeThreshold,
        address[] memory contracts,
        bytes[] memory data
    ) external returns (address payable soundEdition);

    /**
     * @dev Changes the SoundEdition implementation contract address.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract.
     *
     * @param newImplementation The new implementation address to be set.
     */
    function setEditionImplementation(address newImplementation) external;

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev The address of the sound edition implementation.
     * @return The configured value.
     */
    function soundEditionImplementation() external returns (address);
}
