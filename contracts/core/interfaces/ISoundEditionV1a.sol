// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { ISoundEditionV1 } from "./ISoundEditionV1.sol";


/**
 * @title ISoundEditionV1a
 * @notice The interface for Sound edition contract fork with metadata module trigger on mint
 */
interface ISoundEditionV1a is ISoundEditionV1 {

    /**
     * @dev Returns the bit flag to enable the mint randomness feature on initialization.
     * @return uint8 constant value
     */
    function METADATA_TRIGGER_ENABLED_FLAG() external pure returns (uint8);


    /**
     * @dev Returns whether the `metadataTrigger` has been enabled.
     * @return bool configured value.
     */
    function metadataTriggerEnabled() external view returns (bool);


}
