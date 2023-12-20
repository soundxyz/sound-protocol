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

    event RegisteredAlias(address indexed address_, address indexed alias_);

    // =============================================================
    //                            ERRORS
    // =============================================================

    error AliasOrAddressCannotBeZero();

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    function platformAirdrop(address superMinter, ISuperMinterV2.PlatformAirdrop memory p)
        external
        returns (uint256 fromTokenId, address[] memory aliases);

    function platformAirdropMulti(address superMinter, ISuperMinterV2.PlatformAirdrop[] memory p)
        external
        returns (uint256[] memory fromTokenIds, address[][] memory aliases);

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    function addressesToAliases(address[] memory addresses) external view returns (address[] memory aliases);

    function aliasesToAddresses(address[] memory aliases) external view returns (address[] memory addresses);
}
