// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { LibString } from "solady/utils/LibString.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { IRarityShuffleMetadata } from "./interfaces/IRarityShuffleMetadata";

contract RarityShuffleMetadata is IRarityShuffleMetadata {
    mapping(uint256 => uint16) public availableIds; /*Mapping to use to track used offsets*/
    uint16 public availableCount; /*Track the available count to know the id of the current max offset*/
    mapping(uint256 => uint256) public offsets; /*Store offsets once found*/
    
    uint256[] public ranges; /*Store range sizes for song Ids*/
    uint256 public nRanges;

    // TODO initializaer?
    /// @notice Constructor sets the shuffle parameters
    /// @param _availableCount Max number of offsets
    /// @param batchSize_ Number of consecutive tokens using the same offset
    /// @param startShuffledId_ Offset to add to all token IDs
    constructor(
        uint16 _availableCount,
        uint256 batchSize_,
        uint256 startShuffledId_,
        uint256 _nRanges,
        uint256[] _ranges
    ) {
        availableCount = _availableCount; /*Set max offsets*/
        
        nRanges = _nRanges;
        for (uint256 index = 0; index < nRanges; index++) {
          ranges[index] = _ranges[index];
        }
    }
    
    // TODO admin interface to set offset for a mint

    /// @notice Set offset at index using seed
    /// @param _index Offset to set
    /// @param _seed Number fr RNG
    function _setNextOffset(uint256 _index, uint256 _seed) internal {
        require(availableCount > 0, "Sold out"); /*Revert once we use up all indices*/
        // Get index of ID to mint from available ids
        uint256 swapIndex = _seed % availableCount;
        // Load in new id
        uint256 newId = availableIds[swapIndex];
        // If unset, assume equals index
        if (newId == 0) {
            newId = swapIndex;
        }
        uint16 lastIndex = availableCount - 1;
        uint16 lastId = availableIds[lastIndex];
        if (lastId == 0) {
            lastId = lastIndex;
        }
        // Set last value as swapped index
        availableIds[swapIndex] = lastId;

        availableCount--;

        offsets[_index] = newId;
    }

    /**
     * @inheritdoc 
     */
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        // TODO revert if does not exist

        return getShuffledTokenId(tokenId);
    }

    function getShuffledTokenId(uint256 tokenId) public view returns (uint256) {
        uint256 _offset = offsets[tokenId];

            uint256 lower = 0;
            uint256 upper = nRanges - 1;
            while (upper > lower) {
                /* Binary search to look for range associated with offset token ID */
                uint256 center = upper - (upper - lower) / 2;
                uint256 _rangeStart = ranges[center];
                if (_offset == _rangeStart) return center + 1;
                else if (_rangeStart < center) lower = center;
                else upper = center - 1;
            }
            return lower + 1;
    }
}
