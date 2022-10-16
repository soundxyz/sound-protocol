// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/*
                 ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
               ▒███████████████████████████████████████████████████████████
               ▒███████████████████████████████████████████████████████████
 ▒▓▓▓▓▓▓▓▓▓▓▓▓▓████████████████▓▓▓▓▓▓▓▓▓▓▓▓▓▓██████████████████████████████▓▒▒▒▒▒▒▒▒▒▒▒▒▒
 █████████████████████████████▓              ████████████████████████████████████████████
 █████████████████████████████▓              ████████████████████████████████████████████
 █████████████████████████████▓               ▒▒▒▒▒▒▒▒▒▒▒▒▒██████████████████████████████
 █████████████████████████████▓                            ▒█████████████████████████████
 █████████████████████████████▓                             ▒████████████████████████████
 █████████████████████████████████████████████████████████▓
 ███████████████████████████████████████████████████████████
 ███████████████████████████████████████████████████████████▒
                              ███████████████████████████████████████████████████████████▒
                              ▓██████████████████████████████████████████████████████████▒
                               ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓███████████████████████████████▒
 █████████████████████████████                             ▒█████████████████████████████▒
 ██████████████████████████████                            ▒█████████████████████████████▒
 ██████████████████████████████▓▒▒▒▒▒▒▒▒▒▒▒▒▒              ▒█████████████████████████████▒
 ████████████████████████████████████████████▒             ▒█████████████████████████████▒
 ████████████████████████████████████████████▒             ▒█████████████████████████████▒
 ▒▒▒▒▒▒▒▒▒▒▒▒▒▒███████████████████████████████▓▓▓▓▓▓▓▓▓▓▓▓▓███████████████▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒
               ▓██████████████████████████████████████████████████████████▒
               ▓██████████████████████████████████████████████████████████
*/


import { ISoundEditionV1a} from "./interfaces/ISoundEditionV1a.sol";
import { ISoundEditionV1} from "./interfaces/ISoundEditionV1.sol";
import { SoundEditionV1 } from "./SoundEditionV1.sol";

import { IMetadataModuleTrigger } from "./interfaces/IMetadataModuleTrigger.sol";

/**
 * @title SoundEditionV1a
 * @notice The Sound Edition contract fork with per token randomness
 */
contract SoundEditionV1a is ISoundEditionV1a, SoundEditionV1{

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /**
     * @dev The boolean flag on whether the `mintRandomness` is enabled.
     */
    uint8 public constant METADATA_TRIGGER_ENABLED_FLAG = 1 << 2;


    // =============================================================
    //                            STORAGE
    // =============================================================



    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundEditionV1a
     */
    function metadataTriggerEnabled() public view returns (bool) {
        return _flags & METADATA_TRIGGER_ENABLED_FLAG != 0;
    }

    /**
     * @inheritdoc SoundEditionV1
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(SoundEditionV1, ISoundEditionV1)
        returns (bool)
    {
        return
            interfaceId == type(ISoundEditionV1a).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================
    /**
     * @dev Triggers the metadata module
     */
    modifier triggersMetadataUpdate(uint256 quantity) {
        if (metadataTriggerEnabled() && metadataModule != address(0)) {
          IMetadataModuleTrigger(metadataModule).triggerMetadata(quantity);
        }
        _;
    }

    function _mint(address to, uint256 quantity) internal override 
    triggersMetadataUpdate(quantity)
    {
      super._mint(to, quantity);
    }

}
