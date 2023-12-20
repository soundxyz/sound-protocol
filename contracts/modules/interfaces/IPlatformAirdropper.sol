// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { ISuperMinterV2 } from "./ISuperMinterV2.sol";

/**
 * @title PlatformAirdropper
 * @dev The `PlatformAirdropper` utility class to batch airdrop tokens.
 */
interface IPlatformAirdropper {
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
     * @dev Performs a platform airdrop.
     *      To save on calldata costs, you can optionally replace each address entry in `p.to` with its alias.
     *      Aliases are registered on-the-fly when a new address is seen.
     * @param superMinter The superminter which has a `platformAirdrop` function.
     * @param p           The platform airdrop parameters.
     * @return fromTokenId The first token ID minted.
     * @return aliases     The aliases of `p.to`.
     */
    function platformAirdrop(address superMinter, ISuperMinterV2.PlatformAirdrop memory p)
        external
        returns (uint256 fromTokenId, address[] memory aliases);

    /**
     * @dev Performs a platform airdrop.
     *      To save on calldata costs, you can optionally replace each address entry in `p.to` with its alias.
     *      Aliases are registered on-the-fly when a new address is seen.
     * @param superMinter The superminter which has a `platformAirdrop` function.
     * @param p           The platform airdrop parameters.
     * @return fromTokenIds The first token IDs minted.
     * @return aliases      The aliases of each `p.to`.
     */
    function platformAirdropMulti(address superMinter, ISuperMinterV2.PlatformAirdrop[] memory p)
        external
        returns (uint256[] memory fromTokenIds, address[][] memory aliases);

    /**
     * @dev Registers the addresses as aliases.
     *      If an address already has an alias, then it will be an no-op for the address.
     * @param addresses The addresses to register.
     * @return aliases The aliases for the addresses.
     */
    function registerAliases(address[] memory addresses) external returns (address[] memory aliases);

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev Returns the current number of aliases.
     * @return The latest value.
     */
    function numAliases() external view returns (uint32);

    /**
     * @dev Returns an array of aliases corresponding to each address.
     * If the alias has not been registered, the address will be the zero address.
     * @param addresses The array of addresses to query.
     * @return aliases The array of aliases.
     */
    function addressesToAliases(address[] memory addresses) external view returns (address[] memory aliases);

    /**
     * @dev Returns an array of addresses corresponding to each alias.
     * If the address has not been registered, the alias will be the zero address.
     * @param aliases The array of aliases to query.
     * @return addresses The array of addresses.
     */
    function aliasesToAddresses(address[] memory aliases) external view returns (address[] memory addresses);
}
