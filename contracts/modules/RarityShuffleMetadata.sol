// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { LibString } from "solady/utils/LibString.sol";
import { ISoundEditionV1a } from "@core/interfaces/ISoundEditionV1a.sol";
import { IRarityShuffleMetadata } from "@modules/interfaces/IRarityShuffleMetadata.sol";

contract RarityShuffleMetadata is IRarityShuffleMetadata {
    mapping(uint256 => uint16) public availableIds; /*Mapping to use to track used offsets*/
    uint16 public availableCount; /*Track the available count to know the id of the current max offset*/
    mapping(uint256 => uint256) public offsets; /*Store offsets once found*/
    
    uint256 public nextIndex; /*Store next index to set*/
    
    uint256[] public ranges; /*Store range sizes for song Ids*/
    uint256 public nRanges;
    
    address public edition; /*The address of the edition that can trigger metadata updates*/

    /// @notice Constructor sets the shuffle parameters
    /// @param _edition Address of collection
    /// @param _availableCount Max number of offsets
    constructor(
        address _edition,
        uint16 _availableCount,
        uint256 _nRanges,
        uint256[] memory _ranges
    ) {
        edition = _edition;
        availableCount = _availableCount; /*Set max offsets*/
        
        nRanges = _nRanges;
        for (uint256 index = 0; index < nRanges; index++) {
          ranges.push(_ranges[index]);
        }
    }
    
    function triggerMetadata(uint256 quantity) external {
        require(msg.sender == edition, "Only edition can trigger");
        
        for (uint256 index = nextIndex; index < nextIndex + quantity; index++) {
        uint256 pseudorandomness = uint256(
            keccak256(abi.encodePacked(blockhash(block.number - 1), index))
        );
            _setNextOffset(index, pseudorandomness);
        }
    }

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

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        uint256 shuffledTokenId = getShuffledTokenId(tokenId);
        string memory baseURI = ISoundEditionV1a(msg.sender).baseURI();
        return bytes(baseURI).length != 0 ? string.concat(baseURI, LibString.toString(shuffledTokenId)) : "";
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
                else if (_rangeStart < _offset) lower = center;
                else upper = center - 1;
            }
            return lower + 1;
    }
}
