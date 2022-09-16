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
     * @dev Thrown if the lengths of the input arrays are not equal.
     */
    error ArrayLengthsMismatch();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Creates a Sound Edition proxy, initializes it,
     *      and creates mint configurations on a given set of minter addresses.
     * @param salt      The salt used for the CREATE2 to deploy the clone to a
     *                  deterministic address.
     * @param initData  The calldata to initialize SoundEdition via
     *                  `abi.encodeWithSelector`.
     * @param contracts A list of contracts to call.
     * @param data      A list of calldata created via `abi.encodeWithSelector`
     *                  This must contain the same number of entries as `contracts`.
     * @return results The results of calling the contracts.
     *                 Use `abi.decode` to decode them.
     */
    function createSoundAndMints(
        bytes32 salt,
        bytes calldata initData,
        address[] calldata contracts,
        bytes[] calldata data
    ) external returns (bytes[] memory results);

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
     * @param by   The caller of the {createSoundAndMints} function.
     * @param salt The salt, generated on the client side.
     * @return The computed value and whether the contract exists.
     */
    function soundEditionAddress(address by, bytes32 salt) external view returns (address, bool);
}
