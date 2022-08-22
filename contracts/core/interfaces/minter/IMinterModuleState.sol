// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { StandardMintData } from "./minterStructs.sol";

interface IMinterModuleState {
    /**
     * @dev Returns the standard set of data about an edition mint.
     * @param edition The edition address.
     * @param mintId The mint id.
     * @return (startTime, endTime, mintPaused, price, maxMintable, maxAllowedPerWallet, totalMinted)
     */
    function standardMintData(address edition, uint256 mintId) external view returns (StandardMintData memory);
}
