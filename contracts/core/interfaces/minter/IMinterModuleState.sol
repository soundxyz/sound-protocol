// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

struct StandardMintData {
    uint32 startTime;
    uint32 endTime;
    bool mintPaused;
    uint256 price;
    uint32 maxMintable;
    uint32 maxMintablePerAccount;
    uint32 totalMinted;
}

interface IMinterModuleState {
    function price(address edition, uint256 mintId) external view returns (uint256);

    function maxMintable(address edition, uint256 mintId) external view returns (uint32);

    function maxMintablePerAccount(address edition, uint256 mintId) external view returns (uint32);

    function totalMinted(address edition, uint256 mintId) external view returns (uint32);

    /**
     * @dev Returns the standard set of data about an edition mint.
     * @param edition The edition address.
     * @param mintId The mint id.
     * @return StandardMintData (startTime, endTime, mintPaused, price, maxMintable, maxMintablePerAccount, totalMinted)
     */
    function standardMintData(address edition, uint256 mintId) external view returns (StandardMintData memory);
}
