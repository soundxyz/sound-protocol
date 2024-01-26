// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/**
 * @title AddressAliasRegistry
 * @dev A registry for registering addresses with aliases.
 */
interface IAddressAliasRegistry {
    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @dev Emitted when an address is registered with an alias.
     */
    event RegisteredAlias(address address_, address alias_);

    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * @dev The alias has not been registered.
     */
    error AliasNotFound();

    /**
     * @dev The address to be registered must be larger than `2**32 - 1`.
     */
    error AddressTooSmall();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @dev Resolve the addresses or aliases.
     *      If an address does not have an aliases, an alias will be registered for it.
     * @param a An array of addresses, which can be aliases.
     * @return addresses The resolved addresses.
     * @return aliases   The aliases for the addresses.
     */
    function resolveAndRegister(address[] memory a)
        external
        returns (address[] memory addresses, address[] memory aliases);

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev Returns the current number of aliases.
     * @return The latest value.
     */
    function numAliases() external view returns (uint32);

    /**
     * @dev Resolve the addresses or aliases.
     *      If an address does not have an aliases, it's corresponding returned alias will be zero.
     *      If an alias does not have an address, it's corresponding returned address will be zero.
     * @param a An array of addresses, which can be aliases.
     * @return addresses The resolved addresses.
     * @return aliases   The aliases for the addresses.
     */
    function resolve(address[] memory a) external view returns (address[] memory addresses, address[] memory aliases);
}
