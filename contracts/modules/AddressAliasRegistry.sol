// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IAddressAliasRegistry } from "@modules/interfaces/IAddressAliasRegistry.sol";
import { LibZip } from "solady/utils/LibZip.sol";

/**
 * @title AddressAliasRegistry
 * @dev A registry for registering addresses with aliases.
 */
contract AddressAliasRegistry is IAddressAliasRegistry {
    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev The current number of aliases.
     */
    uint32 public numAliases;

    /**
     * @dev Maps an alias to its original address.
     */
    mapping(address => address) internal _aliasToAddress;

    /**
     * @dev Maps an address to its alias.
     */
    mapping(address => address) internal _addressToAlias;

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IAddressAliasRegistry
     */
    function resolveAndRegister(address[] memory a)
        public
        returns (address[] memory aliases, address[] memory addresses)
    {
        unchecked {
            uint256 n = a.length;
            aliases = new address[](n);
            addresses = new address[](n);
            for (uint256 i; i != n; ++i) {
                (aliases[i], addresses[i]) = _resolveAndRegister(a[i]);
            }
        }
    }

    // Misc functions:
    // ---------------

    /**
     * @dev For calldata compression.
     */
    fallback() external payable {
        LibZip.cdFallback();
    }

    /**
     * @dev For calldata compression.
     */
    receive() external payable {
        LibZip.cdFallback();
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IAddressAliasRegistry
     */
    function resolve(address[] memory a) public view returns (address[] memory aliases, address[] memory addresses) {
        unchecked {
            uint256 n = a.length;
            aliases = new address[](n);
            addresses = new address[](n);
            for (uint256 i; i != n; ++i) {
                (aliases[i], addresses[i]) = _resolve(a[i]);
            }
        }
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Returns the alias and address for `aliasOrAddress`.
     *      If the `aliasOrAddress` is less than `2**31 - 1`, it is treated as an alias.
     *      Otherwise, it is treated as an address, and it's alias will be registered on-the-fly.
     * @param aliasOrAddress The alias or address.
     * @return alias_   The alias.
     * @return address_ The address.
     */
    function _resolveAndRegister(address aliasOrAddress) internal returns (address alias_, address address_) {
        // If the `aliasOrAddress` is less than or equal to `2**32 - 1`, we will consider it an alias.
        if (uint160(aliasOrAddress) <= type(uint32).max) {
            alias_ = aliasOrAddress;
            address_ = _aliasToAddress[alias_];
            if (address_ == address(0)) revert AliasNotFound();
        } else {
            address_ = aliasOrAddress;
            alias_ = _registerAlias(address_);
        }
    }

    /**
     * @dev Returns the alias and address for `aliasOrAddress`.
     *      If the `aliasOrAddress` is less than `2**31 - 1`, it is treated as an alias.
     *      Otherwise, it is treated as an address.
     * @param aliasOrAddress The alias or address.
     * @return alias_   The alias.
     * @return address_ The address.
     */
    function _resolve(address aliasOrAddress) internal view returns (address alias_, address address_) {
        // If the `aliasOrAddress` is less than or equal to `2**32 - 1`, we will consider it an alias.
        if (uint160(aliasOrAddress) <= type(uint32).max) {
            alias_ = aliasOrAddress;
            address_ = _aliasToAddress[alias_];
        } else {
            address_ = aliasOrAddress;
            alias_ = _addressToAlias[address_];
        }
    }

    /**
     * @dev Registers the alias for the address on-the-fly.
     * @param address_ The address.
     * @return alias_ The alias registered for the address.
     */
    function _registerAlias(address address_) internal returns (address alias_) {
        if (uint160(address_) <= type(uint32).max) revert AddressTooSmall();

        alias_ = _addressToAlias[address_];
        // If the address has no alias, register it's alias.
        if (alias_ == address(0)) {
            // Increment the `numAliases` and cast it into an alias.
            alias_ = address(uint160(++numAliases));
            // Add to the mappings.
            _aliasToAddress[alias_] = address_;
            _addressToAlias[address_] = alias_;
            emit RegisteredAlias(address_, alias_);
        }
    }
}
