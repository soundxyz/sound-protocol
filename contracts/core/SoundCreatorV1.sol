// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

/*
                 ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
               ▒███████████████████████████████████████████████████████████
               ▒███████████████████████████████████████████████████████████
 ▒▓▓▓▓▓▓▓▓▓▓▓▓▓████████████████▓▓▓▓▓▓▓▓▓▓▓▓▓▓██████████████████████████████▓▒▒▒▒▒▒▒▒▒▒▒▒▒
 █████████████████████████████▓              ████████████████████████████████████████████
 █████████████████████████████▓              ████████████████████████████████████████████
 █████████████████████████████▓               ▒▒▒▒▒▒▒▒▒▒▒▒▒██████████████████████████████
 █████████████████████████████▓                            ▒█████████████████████████████
 █████████████████████████████▓                             ▒████████████████████████████
 █████████████████████████████████████████████████████████▓
 ███████████████████████████████████████████████████████████
 ███████████████████████████████████████████████████████████▒
                              ███████████████████████████████████████████████████████████▒
                              ▓██████████████████████████████████████████████████████████▒
                               ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓███████████████████████████████▒
 █████████████████████████████                             ▒█████████████████████████████▒
 ██████████████████████████████                            ▒█████████████████████████████▒
 ██████████████████████████████▓▒▒▒▒▒▒▒▒▒▒▒▒▒              ▒█████████████████████████████▒
 ████████████████████████████████████████████▒             ▒█████████████████████████████▒
 ████████████████████████████████████████████▒             ▒█████████████████████████████▒
 ▒▒▒▒▒▒▒▒▒▒▒▒▒▒███████████████████████████████▓▓▓▓▓▓▓▓▓▓▓▓▓███████████████▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒
               ▓█████████████████████████████████████████████████████████▒
               ▓██████████████████████████████████████████████████████████
*/

import { Clones } from "openzeppelin/proxy/Clones.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";

import { ISoundCreatorV1 } from "./interfaces/ISoundCreatorV1.sol";
import { ISoundEditionV1 } from "./interfaces/ISoundEditionV1.sol";
import { IMetadataModule } from "./interfaces/IMetadataModule.sol";

/**
 * @title SoundCreatorV1
 * @notice A factory that deploys minimal proxies of `SoundEditionV1.sol`.
 * @dev The proxies are OpenZeppelin's Clones implementation of https://eips.ethereum.org/EIPS/eip-1167
 */
contract SoundCreatorV1 is ISoundCreatorV1, Ownable {
    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev The implementation contract delegated to by Sound edition proxies.
     */
    address public soundEditionImplementation;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor(address _soundEditionImplementation) implementationNotZero(_soundEditionImplementation) {
        soundEditionImplementation = _soundEditionImplementation;
    }

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundCreatorV1
     */
    function createSound(bytes calldata initData) external returns (address payable soundEdition) {
        // Create Sound Edition proxy
        soundEdition = payable(Clones.clone(soundEditionImplementation));

        emit SoundEditionCreated(soundEdition, msg.sender);

        // Initialize proxy
        assembly {
            // Grab the free memory pointer.
            let m := mload(0x40)
            // Copy the `initData` to the free memory.
            calldatacopy(m, initData.offset, initData.length)
            // Replace the first word in the `initData` with the `msg.sender`.
            mstore(add(m, 0x04), caller())
            // Call the initializer, and revert if the call fails.
            if iszero(
                call(
                    gas(),
                    soundEdition,
                    0, // `msg.value` of the call.
                    m, // Start of input.
                    initData.length, // Length of input
                    0x00, // Start of output.
                    0x00 // Size of output.
                )
            ) {
                // Bubble up the revert if the call reverts.
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
        }
    }

    /**
     * @inheritdoc ISoundCreatorV1
     */
    function setEditionImplementation(address newImplementation)
        external
        onlyOwner
        implementationNotZero(newImplementation)
    {
        soundEditionImplementation = newImplementation;

        emit SoundEditionImplementationSet(soundEditionImplementation);
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Reverts if the given implementation address is zero.
     * @param implementation The address of the implementation.
     */
    modifier implementationNotZero(address implementation) {
        if (implementation == address(0)) {
            revert ImplementationAddressCantBeZero();
        }
        _;
    }
}
