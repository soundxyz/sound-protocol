// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

/**
 * @title ISoundCreatorV1
 * @notice The interface for the Sound edition factory.
 */
interface ISoundCreatorV1 {
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

    /**
     * Thrown if the implementation address is zero.
     */
    error ImplementationAddressCantBeZero();
}
