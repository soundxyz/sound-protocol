// SPDX-License-Identifier: MIT
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

import { ISoundCreatorV1 } from "./interfaces/ISoundCreatorV1.sol";
import { ISoundEditionV1 } from "./interfaces/ISoundEditionV1.sol";
import { IMetadataModule } from "./interfaces/IMetadataModule.sol";

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

/**
 * @title SoundCreatorV1
 * @notice A factory that deploys minimal proxies of `SoundEditionV1.sol`.
 * @dev The proxies are OpenZeppelin's Clones implementation of https://eips.ethereum.org/EIPS/eip-1167
 */
contract SoundCreatorV1 is ISoundCreatorV1, OwnableRoles {
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
        _initializeOwner(msg.sender);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundCreatorV1
     */
    function createSoundAndMints(
        bytes32 salt,
        bytes calldata initData,
        address[] calldata contracts,
        bytes[] calldata data
    ) external returns (address soundEdition, bytes[] memory results) {
        // Create Sound Edition proxy.
        soundEdition = payable(Clones.cloneDeterministic(soundEditionImplementation, _saltedSalt(msg.sender, salt)));

        // Initialize proxy.
        assembly {
            // Grab the free memory pointer.
            let m := mload(0x40)
            // Copy the `initData` to the free memory.
            calldatacopy(m, initData.offset, initData.length)
            // Call the initializer, and revert if the call fails.
            if iszero(
                call(
                    gas(), // Gas remaining.
                    soundEdition, // Address of the edition.
                    0, // `msg.value` of the call: 0 ETH.
                    m, // Start of input.
                    initData.length, // Length of input.
                    0x00, // Start of output. Not used.
                    0x00 // Size of output. Not used.
                )
            ) {
                // Bubble up the revert if the call reverts.
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
        }

        results = _callContracts(contracts, data);

        OwnableRoles(soundEdition).transferOwnership(msg.sender);

        emit SoundEditionCreated(soundEdition, msg.sender, initData, contracts, data, results);
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
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundCreatorV1
     */
    function soundEditionAddress(address by, bytes32 salt) external view returns (address addr, bool exists) {
        addr = Clones.predictDeterministicAddress(soundEditionImplementation, _saltedSalt(by, salt), address(this));
        exists = addr.code.length > 0;
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Call the `contracts` in order with `data`.
     * @param contracts The addresses of the contracts.
     * @param data      The `abi.encodeWithSelector` calldata for each of the contracts.
     * @return results The results of calling the contracts.
     */
    function _callContracts(address[] calldata contracts, bytes[] calldata data)
        internal
        returns (bytes[] memory results)
    {
        if (contracts.length != data.length) revert ArrayLengthsMismatch();

        assembly {
            // Grab the free memory pointer.
            // We will use the free memory to construct the `results` array,
            // and also as a temporary space for the calldata.
            results := mload(0x40)
            // Set `results.length` to be equal to `data.length`.
            mstore(results, data.length)
            // Skip the first word, which is used to store the length
            let resultsOffsets := add(results, 0x20)
            // Compute the location of the last calldata offset in `data`.
            // `shl(5, n)` is a gas-saving shorthand for `mul(0x20, n)`.
            let dataOffsetsEnd := add(data.offset, shl(5, data.length))
            // This is the start of the unused free memory.
            // We use it to temporarily store the calldata to call the contracts.
            let m := add(resultsOffsets, shl(5, data.length))

            // Loop through `contacts` and `data` together.
            // prettier-ignore
            for { let i := data.offset } iszero(eq(i, dataOffsetsEnd)) { i := add(i, 0x20) } {
                // Location of `bytes[i]` in calldata.
                let o := add(data.offset, calldataload(i))
                // Copy `bytes[i]` from calldata to the free memory.
                calldatacopy(
                    m, // Start of the unused free memory.
                    add(o, 0x20), // Location of starting byte of `data[i]` in calldata.
                    calldataload(o) // The length of the `bytes[i]`.
                )
                // Grab `contracts[i]` from the calldata.
                // As `contracts` is the same length as `data`,
                // `sub(i, data.offset)` gives the relative offset to apply to
                // `contracts.offset` for `contracts[i]` to match `data[i]`.
                let c := calldataload(add(contracts.offset, sub(i, data.offset)))
                // Call the contract, and revert if the call fails.
                if iszero(
                    call(
                        gas(), // Gas remaining.
                        c, // `contracts[i]`.
                        0, // `msg.value` of the call: 0 ETH.
                        m, // Start of the copy of `bytes[i]` in memory.
                        calldataload(o), // The length of the `bytes[i]`.
                        0x00, // Start of output. Not used.
                        0x00 // Size of output. Not used.
                    )
                ) {
                    // Bubble up the revert if the call reverts.
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }
                // Append the current `m` into `resultsOffsets`.
                mstore(resultsOffsets, m)
                resultsOffsets := add(resultsOffsets, 0x20)

                // Append the `returndatasize()` to `results`.
                mstore(m, returndatasize())
                // Append the return data to `results`.
                returndatacopy(add(m, 0x20), 0x00, returndatasize())
                // Advance `m` by `returndatasize() + 0x20`,
                // rounded up to the next multiple of 32.
                // `0x3f = 32 + 31`. The mask is `type(uint64).max & ~31`,
                // which is big enough for all purposes (see memory expansion costs).
                m := and(add(add(m, returndatasize()), 0x3f), 0xffffffffffffffe0)
            }
            // Allocate the memory for `results` by updating the free memory pointer.
            mstore(0x40, m)
        }
    }

    /**
     * @dev Returns the salted salt.
     *      To prevent griefing and accidental collisions from clients that don't
     *      generate their salt properly.
     * @param by   The caller of the {createSoundAndMints} function.
     * @param salt The salt, generated on the client side.
     * @return result The computed value.
     */
    function _saltedSalt(address by, bytes32 salt) internal pure returns (bytes32 result) {
        assembly {
            // Store the variables into the scratch space.
            mstore(0x00, by)
            mstore(0x20, salt)
            // Equivalent to `keccak256(abi.encode(by, salt))`.
            result := keccak256(0x00, 0x40)
        }
    }

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
