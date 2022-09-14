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
               ▓██████████████████████████████████████████████████████████▒
               ▓██████████████████████████████████████████████████████████
*/

import { Base64 } from "solady/utils/Base64.sol";

library ArweaveURILib {
    // =============================================================
    //                            STRUCTS
    // =============================================================

    struct URI {
        bytes32 arweave;
        string regular;
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Helper function for storing a URI that may be an arweave URI.
     *      Efficiently stores arweave CIDs by converting them into a single bytes32 word.
     *      The arweave CID is a base64 encoded sha-256 output (32 bytes when decoded).
     *      See: https://docs.arweave.org/developers/server/http-api
     * @param uri      The URI storage reference.
     * @param value    The string representation of the URI.
     * @param isUpdate Whether this is called in an update.
     */
    function store(
        URI storage uri,
        string memory value,
        bool isUpdate
    ) internal {
        string memory arweaveURICopy;
        bool isArweave;
        assembly {
            // Example: "ar://Hjtz2YLeVyXQkGxKTNcIYfWkKnHioDvfICulzQIAt3E"
            let n := mload(value)
            // If the URI is length 48 or 49 (due to a trailing slash).
            if or(eq(n, 48), eq(n, 49)) {
                // If starts with "ar://".
                if eq(and(mload(add(5, value)), 0xffffffffff), 0x61723a2f2f) {
                    isArweave := 1
                    // Copy `value`.
                    // First, grab the free memory pointer.
                    arweaveURICopy := mload(0x40)
                    // Allocate 3 memory slots.
                    // 1 slot for the length, 2 slots for the bytes.
                    mstore(0x40, add(arweaveURICopy, 0x60))
                    // Copy the 2 slots containing the bytes.
                    mstore(add(arweaveURICopy, 0x20), mload(add(value, 0x20)))
                    mstore(add(arweaveURICopy, 0x40), mload(add(value, 0x40)))
                    // Make the `arweaveURICopy` skip the first 5 bytes.
                    arweaveURICopy := add(5, arweaveURICopy)
                    // Sets the length of the `arweaveURICopy` to 43,
                    // such that it only contains the CID.
                    mstore(arweaveURICopy, 43)
                }
            }
        }
        if (isArweave) {
            bytes memory decodedCIDBytes = Base64.decode(arweaveURICopy);
            bytes32 arweaveCID;
            assembly {
                arweaveCID := mload(add(decodedCIDBytes, 0x20))
            }
            uri.arweave = arweaveCID;
            if (isUpdate) delete uri.regular;
        } else {
            uri.regular = value;
            if (isUpdate) delete uri.arweave;
        }
    }

    /**
     * @dev Equivalent to `store(uri, value, false)`.
     * @param uri      The URI storage reference.
     * @param value    The string representation of the URI.
     */
    function initialize(URI storage uri, string memory value) internal {
        store(uri, value, false);
    }

    /**
     * @dev Equivalent to `store(uri, value, true)`.
     * @param uri      The URI storage reference.
     * @param value    The string representation of the URI.
     */
    function update(URI storage uri, string memory value) internal {
        store(uri, value, true);
    }

    /**
     * @dev Helper function for retrieving a URI stored with {_setURI}.
     * @param uri The URI storage reference.
     */
    function load(URI storage uri) internal view returns (string memory) {
        bytes32 arweaveCID = uri.arweave;
        if (arweaveCID == bytes32(0)) {
            return uri.regular;
        }
        bytes memory decoded;
        assembly {
            // Copy `arweaveCID`.
            // First, grab the free memory pointer.
            decoded := mload(0x40)
            // Allocate 2 slots.
            // 1 slot for the length, 1 slot for the bytes.
            mstore(0x40, add(decoded, 0x40))
            mstore(decoded, 0x20) // Set the length (32 bytes).
            mstore(add(decoded, 0x20), arweaveCID) // Set the bytes.
        }
        string memory encoded = Base64.encode(decoded, true, true);

        return string.concat("ar://", encoded, "/");
    }
}
