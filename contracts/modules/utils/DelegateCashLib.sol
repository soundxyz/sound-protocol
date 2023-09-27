// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library DelegateCashLib {
    address internal constant REGISTRY_V2 = 0x00000000000000447e69651d841bD8D104Bed493;

    function checkDelegateForAll(address delegate, address vault) internal view returns (bool result) {
        assembly {
            // Cache the free memory pointer.
            let m := mload(0x40)
            // Store the function selector of `checkDelegateForAll(address,address,bytes32)`.
            mstore(0x00, 0xe839bd53)
            // Store the `delegate`.
            mstore(0x20, delegate)
            // Store the `vault`.
            mstore(0x40, vault)
            // The `bytes32 right` argument points to 0x60, which is zero.

            // Arguments are evaulated last to first.
            result := and(
                // The returndata is 1, which represents a bool true.
                eq(mload(0x00), 1),
                // The staticcall is successful.
                staticcall(gas(), REGISTRY_V2, 0x1c, 0x64, 0x00, 0x20)
            )

            // Restore the free memory pointer.
            mstore(0x40, m)
        }
    }
}
