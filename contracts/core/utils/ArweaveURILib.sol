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
     * @dev Helper function for storing a URI that may be an Arweave URI.
     *      Efficiently stores Arweave CIDs by converting them into a single bytes32 word.
     *      The Arweave CID is a base64 encoded sha-256 output (32 bytes when decoded).
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
        uint256 valueLength;
        bool isArweave;
        assembly {
            // Example: "ar://Hjtz2YLeVyXQkGxKTNcIYfWkKnHioDvfICulzQIAt3E"
            valueLength := mload(value)
            // If the URI is length 48 or 49 (due to a trailing slash).
            if or(eq(valueLength, 48), eq(valueLength, 49)) {
                // If starts with "ar://".
                if eq(and(mload(add(value, 5)), 0xffffffffff), 0x61723a2f2f) {
                    isArweave := 1
                    value := add(value, 5)
                    // Sets the length of the `value` to 43,
                    // such that it only contains the CID.
                    mstore(value, 43)
                }
            }
        }
        if (isArweave) {
            bytes memory decodedCIDBytes = Base64.decode(value);
            bytes32 arweaveCID;
            assembly {
                arweaveCID := mload(add(decodedCIDBytes, 0x20))
                // Restore the "ar://".
                mstore(value, 0x61723a2f2f)
                // Restore the original position of the `value` pointer.
                value := sub(value, 5)
                // Restore the original length.
                mstore(value, valueLength)
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
        return string.concat("ar://", Base64.encode(decoded, true, true), "/");
    }
}
