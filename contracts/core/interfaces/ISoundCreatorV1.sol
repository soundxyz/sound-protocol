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
     * @dev Creates a Sound Edition proxy, initializes it,
     *      and creates mint configurations on a given set of minter addresses.
     * @param salt      The salt used for the CREATE2 to deploy the clone to a
     *                  deterministic address.
     * @param initData  The calldata to initialize created via
     *                  `abi.encodeWithSelector`.
     * @param contracts A list of contracts to call.
     * @param data      A list of calldata created via `abi.encodeWithSelector`
     *                  This must contain the same number of entries as `contracts`.
     * @return soundEdition The address of the deployed edition proxy.
     */
    function createSoundAndMints(
        bytes32 salt,
        bytes calldata initData,
        address[] calldata contracts,
        bytes[] calldata data
    ) external returns (address soundEdition);

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

    /**
     * @dev Returns the deterministic address for the sound edition clone.
     * @param salt The salt, generated on the client side.
     * @return The computed value.
     */
    function soundEditionAddress(bytes32 salt) external view returns (address);
}
