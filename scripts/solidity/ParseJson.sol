// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

interface ParseJson {
    function parseJson(string calldata, string calldata) external returns (bytes memory);

    function parseJson(string calldata) external returns (bytes memory);
}
