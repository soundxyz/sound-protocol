// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

interface IBaseMinter {
    function price(address edition, uint256 mintId) external view returns (uint256);

    function maxMintable(address edition, uint256 mintId) external view returns (uint32);

    function maxAllowedPerWallet(address edition, uint256 mintId) external view returns (uint32);
}
