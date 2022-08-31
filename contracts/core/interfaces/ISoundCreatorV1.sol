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
     * Thrown if the implementation address is zero.
     */
    error ImplementationAddressCantBeZero();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Deploys a Sound edition minimal proxy contract.
     * @param initData The initialization calldata to pass to the edition contract to.
     *                 The first word of the `initData` will be replaced by the `msg.sender`.
     * @return soundEdition The address of the deployed edition proxy.
     */
    function createSound(bytes calldata initData) external returns (address payable soundEdition);

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
