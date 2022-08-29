// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

/**
 * @title ISoundFeeRegistry
 * @author Sound.xyz
 */
interface ISoundFeeRegistry {
    function soundFeeAddress() external view returns (address);

    function platformFeeBPS() external view returns (uint16);
}
