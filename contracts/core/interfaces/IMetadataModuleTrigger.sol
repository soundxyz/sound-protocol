// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./IMetadataModule.sol";

/**
 * @title IMetadataModuleTrigger
 * @notice The interface for custom metadata modules with triggers
 */
interface IMetadataModuleTrigger is IMetadataModule {
    /**
     * @dev When implemented, receive a trigger from Edition contract on mint
     * @param quantity The number of tokens being minted
     */
    function triggerMetadata(uint256 quantity) external;
}
