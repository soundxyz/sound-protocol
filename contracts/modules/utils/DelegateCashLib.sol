// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library DelegateCashLib {
    address internal constant REGISTRY = 0x00000000000076A84feF008CDAbe6409d2FE638B;

    function checkDelegateForAll(address delegate, address vault) internal view returns (bool result) {
        assembly {
            // Cache the free memory pointer.
            let m := mload(0x40)
            // Store the function selector of `checkDelegateForAll(address,address)`.
            mstore(0x00, 0x9c395bc2)
            // Store the `delegate`.
            mstore(0x20, delegate)
            // Store the `vault`.
            mstore(0x40, vault)

            // Arguments are evaulated last to first.
            result := and(
                // The returndata is 1, which represents a bool true.
                eq(mload(0x00), 1),
                // The staticcall is successful.
                staticcall(gas(), REGISTRY, 0x1c, 0x44, 0x00, 0x20)
            )

            // Restore the free memory pointer.
            mstore(0x40, m)
        }
    }
}
