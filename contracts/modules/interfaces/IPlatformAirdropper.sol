// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { ISuperMinterV2 } from "./ISuperMinterV2.sol";

/**
 * @title PlatformAirdropper
 * @dev The `PlatformAirdropper` utility class to batch airdrop tokens.
 */
interface IPlatformAirdropper {
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

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev Returns the address alias registry.
     * @return The immutable value.
     */
    function addressAliasRegistry() external view returns (address);
}
