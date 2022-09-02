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
import { OwnableUpgradeable } from "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { ISoundCreatorV1 } from "./interfaces/ISoundCreatorV1.sol";
import { ISoundEditionV1 } from "./interfaces/ISoundEditionV1.sol";
import { IMetadataModule } from "./interfaces/IMetadataModule.sol";
import { IMinterModule } from "./interfaces/IMinterModule.sol";

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

/**
 * @title SoundCreatorV1
 * @notice A factory that deploys minimal proxies of `SoundEditionV1.sol`.
 * @dev The proxies are OpenZeppelin's Clones implementation of https://eips.ethereum.org/EIPS/eip-1167
 */
contract SoundCreatorV1 is ISoundCreatorV1, OwnableUpgradeable, UUPSUpgradeable {
    // =============================================================
    //                            CONSTANTS
    // =============================================================

    /**
     * @dev Used for search and replace in the calldata to be forwarded.
     *      `keccak256(bytes("soundxyz.SoundCreator.PLACEHOLDER_ADDRESS"))`
     */
    address public constant PLACEHOLDER_ADDRESS = 0xEBef849c9501107C20e13685050941D44C362E43;

    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev The implementation contract delegated to by Sound edition proxies.
     */
    address public soundEditionImplementation;

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundCreatorV1
     */
    function initialize(address _soundEditionImplementation)
        public
        implementationNotZero(_soundEditionImplementation)
        initializer
    {
        __Ownable_init_unchained();

        soundEditionImplementation = _soundEditionImplementation;
    }

    /**
     * @inheritdoc ISoundCreatorV1
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
    ) external returns (address payable soundEdition) {
        // Create Sound Edition proxy
        soundEdition = payable(Clones.clone(soundEditionImplementation));
        // Initialize proxy
        ISoundEditionV1(soundEdition).initialize(
            msg.sender,
            name,
            symbol,
            metadataModule,
            baseURI,
            contractURI,
            fundingRecipient,
            royaltyBPS,
            editionMaxMintable,
            mintRandomnessTokenThreshold,
            mintRandomnessTimeThreshold
        );

        emit SoundEditionCreated(soundEdition, msg.sender);
    }

    /**
     * @inheritdoc ISoundCreatorV1
     */
    function createSoundAndMints(
        bytes calldata initData,
        address[] calldata contracts,
        bytes[] calldata data
    ) external returns (address payable soundEdition) {
        // Create Sound Edition proxy
        soundEdition = payable(Clones.clone(soundEditionImplementation));

        // Initialize proxy.
        assembly {
            // Grab the free memory pointer.
            let m := mload(0x40)
            // Copy the `initData` to the free memory.
            calldatacopy(m, initData.offset, initData.length)
            // Replace the first argument of `initData` with the `address(this)`.
            mstore(add(m, 0x04), address())
            // Call the initializer, and revert if the call fails.
            if iszero(
                call(
                    gas(), // Gas remaining.
                    soundEdition, // Address of the edition.
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

        _callMinters(soundEdition, contracts, data);

        OwnableRoles(soundEdition).transferOwnership(msg.sender);

        emit SoundEditionCreated(soundEdition, msg.sender);
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
     * @dev Call the `contracts` in order with `data`.
     * @param contracts The addresses of the contracts.
     * @param data      The `abi.encodeWithSelector` calldata for each of the contracts.
     */
    function _callMinters(
        address soundEdition,
        address[] calldata contracts,
        bytes[] calldata data
    ) internal {
        if (contracts.length != data.length) revert ArrayLengthsMismatch();

        assembly {
            // Grab the free memory pointer.
            let m := mload(0x40)
            // Compute the end of the data.
            let dataLengthsEnd := add(data.offset, shl(5, data.length))
            // prettier-ignore
            for { let i := data.offset } iszero(eq(i, dataLengthsEnd)) { i := add(i, 0x20) } {
                // The location of the current bytes in calldata.
                let o := add(data.offset, calldataload(i))
                // The length of the current bytes.
                let l := calldataload(o)
                // Copy the current bytes from calldata to the memory.
                calldatacopy(
                    m, // Start of the current bytes in memory.
                    add(o, 0x20), // The offset of the current bytes' bytes.
                    l // The length of the current bytes.
                )
                // The end of the current bytes in memory.
                let e := add(m, l)
                // Replace the first instance of `PLACEHOLDER_ADDRESS` in the data with `soundEdition`.
                // prettier-ignore
                for { let j := add(m, 0x04) } lt(j, e) { j := add(0x20, j) } {
                    if eq(mload(j), PLACEHOLDER_ADDRESS) {
                        mstore(j, soundEdition)
                        break
                    }
                }
                // The current contract to call.
                let c := calldataload(add(contracts.offset, sub(i, data.offset)))
                // If `c == PLACEHOLDER_ADDRESS`, replace it with `soundEdition`.
                if eq(c, PLACEHOLDER_ADDRESS) {
                    c := soundEdition
                }
                // Try to call, and bubble up the revert if any.
                if iszero(call(
                    gas(), // Remaining gas.
                    c, // The contract to call.
                    0, // Zero ETH sent.
                    m, // Start of the current bytes in memory.
                    l, // The length of the current bytes.
                    0x00, // Zero return data expected.
                    0x00 // Zero return data expected.
                )) {
                    // Bubble up the revert if the call reverts.
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }
            }
        }
    }

    /**
     * @dev Enables the owner to upgrade the contract.
     *      Required by `UUPSUpgradeable`.
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

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
