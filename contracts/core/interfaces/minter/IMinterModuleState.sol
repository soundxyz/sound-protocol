// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

interface IMinterModuleState {
    struct StandardMintData {
        uint32 startTime;
        uint32 endTime;
        bool mintPaused;
        uint256 price;
        uint32 maxMintable;
        uint32 maxAllowedPerWallet;
        uint32 totalMinted;
    }

    function price(address edition, uint256 mintId) external view returns (uint256);

    function maxMintable(address edition, uint256 mintId) external view returns (uint32);

    function maxAllowedPerWallet(address edition, uint256 mintId) external view returns (uint32);

    function totalMinted(address edition, uint256 mintId) external view returns (uint32);

    /**
     * @dev Returns the standard set of data about an edition mint.
     * @param edition The edition address.
     * @param mintId The mint id.
     * @return (startTime, endTime, mintPaused, price, maxMintable, maxAllowedPerWallet, totalMinted)
     */
    function standardMintData(address edition, uint256 mintId) external view returns (StandardMintData memory);
}
