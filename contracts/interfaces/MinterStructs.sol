// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

struct BaseData {
    uint32 startTime;
    uint32 endTime;
    bool mintPaused;
}

struct StandardMintData {
    uint32 startTime;
    uint32 endTime;
    bool mintPaused;
    uint256 price;
    uint32 maxMintable;
    uint32 maxAllowedPerWallet;
    uint32 totalMinted;
}
