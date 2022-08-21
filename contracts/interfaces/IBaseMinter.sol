// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { StandardMintData } from "./MinterStructs.sol";

/**
 * @title Interface for the base minter functionality, excluding the mint function.
 */
interface IBaseMinter {
    /**
     * @dev The price of the token for a given edition mint ID.
     */
    function price(address edition, uint256 mintId) external view returns (uint256);

    /**
     * @dev The maximum mintable token quantity for a given edition mint ID.
     */
    function maxMintable(address edition, uint256 mintId) external view returns (uint32);

    /**
     * @dev The maximum mintable quantity per account for a given edition mint ID.
     * A return value of zero indicates there is no on-chain maximum.
     */
    function maxAllowedPerWallet(address edition, uint256 mintId) external view returns (uint32);

    /**
     * @dev Returns the standard set of data about an edition mint.
     * @param edition The edition address.
     * @param mintId The mint id.
     * @return (startTime, endTime, mintPaused, price, maxMintable, maxAllowedPerWallet, totalMinted)
     */
    function standardMintData(address edition, uint256 mintId) external view returns (StandardMintData memory);
}
