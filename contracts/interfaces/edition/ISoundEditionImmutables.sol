// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

interface ISoundEditionImmutables {
    /// Getter for minter role hash
    function MINTER_ROLE() external view returns (bytes32);

    /// Getter for admin role hash
    function ADMIN_ROLE() external view returns (bytes32);
}
