// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { LibString } from "solady/utils/LibString.sol";
import { ISoundEditionV1a } from "@core/interfaces/ISoundEditionV1a.sol";
import { IRarityShuffleMetadata } from "@modules/interfaces/IRarityShuffleMetadata.sol";

/**
 * @title RarityShuffleMetadata
 * @dev Module for shuffling each tokenID of a Sound protocol mint and bucketing shuffled IDs into rarity tiers
 * @author @ipatka
 */
contract RarityShuffleMetadata is IRarityShuffleMetadata {
    mapping(uint256 => uint16) public availableIds; /*Mapping to use to track used offsets*/
    uint16 public availableCount; /*Track the available count to know the id of the current max offset*/
    mapping(uint256 => uint256) public offsets; /*Store offsets once found*/

    uint256 public nextIndex; /*Store next index to set*/

    uint256[] public ranges; /*Store range sizes for song Ids*/
    uint256 public nRanges; /*Store number of rarity tiers*/

    address public edition; /*The address of the edition that can trigger metadata updates*/

    /// @notice Constructor sets the shuffle parameters
    /// @param _edition Address of collection
    /// @param _availableCount Max number of offsets
    /// @param _nRanges Number of rarity tiers
    /// @param _ranges IDs at which to start each tier, must be ordered smallest to largest
    constructor(
        address _edition,
        uint16 _availableCount,
        uint256 _nRanges,
        uint256[] memory _ranges
    ) {
        edition = _edition;
        availableCount = _availableCount; /*Set max offsets*/
        nRanges = _nRanges;
        uint256 _currentMax;
        for (uint256 index = 0; index < nRanges; index++) {
            if (_ranges[index] < _currentMax) revert RangeMustBeOrdered();
            ranges.push(_ranges[index]); /*Populate the rarity table*/
            _currentMax = _ranges[index];
        }
        emit NewModuleCreated(_edition, address(this));
    }

    /// @notice Set shuffled token IDs for a quantity of tokens, determiend by edition
    /// @param quantity Number of tokens to set
    function triggerMetadata(uint256 quantity) external {
        if (msg.sender != edition) revert OnlyEditionCanTrigger();

        // Set shuffled ID for each token
        for (uint256 index = nextIndex; index < nextIndex + quantity; index++) {
            uint256 pseudorandomness = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), index)));
            _setNextOffset(index, pseudorandomness);
        }
        nextIndex += quantity; /*Increment starting index for the next batch*/
    }

    /// @notice Set offset at index using seed
    /// @dev uses modified Zora algorithm
    /// @param _index Offset to set
    /// @param _seed Number for RNG calculations
    function _setNextOffset(uint256 _index, uint256 _seed) internal {
        if (availableCount == 0) revert NoEditionsRemain(); /*Revert once we use up all indices*/
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

    /// @notice Query tokenURI
    /// @dev Normally called by edition contract rather than called directly
    /// @param tokenId Token to query
    /// @return string of tokenURI
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        uint256 _offset = offsets[tokenId];
        uint256 shuffledTokenId = getShuffledTokenId(_offset);
        string memory baseURI = ISoundEditionV1a(msg.sender).baseURI();
        return bytes(baseURI).length != 0 ? string.concat(baseURI, LibString.toString(shuffledTokenId)) : "";
    }

    /// @notice Query shuffled & bucketed tokenID
    /// @dev Uses offset ID with rarity ranges to return edition ID. BST modified from Compound governance getPriorVotes
    /// @param _offset TokenID with offset
    /// @return uint256 of edition ID
    function getShuffledTokenId(uint256 _offset) public view returns (uint256) {
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
