// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { LibString } from "solady/utils/LibString.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { IGoldenEggMetadata } from "@modules/interfaces/IGoldenEggMetadata.sol";

contract GoldenEggMetadata is IGoldenEggMetadata {
    /**
     * @inheritdoc IGoldenEggMetadata
     */
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        uint256 goldenEggTokenId = getGoldenEggTokenId(ISoundEditionV1(msg.sender));
        string memory baseURI = ISoundEditionV1(msg.sender).baseURI();

        if (tokenId == goldenEggTokenId) {
            return bytes(baseURI).length != 0 ? string.concat(baseURI, "goldenEgg") : "";
        }

        return bytes(baseURI).length != 0 ? string.concat(baseURI, LibString.toString(tokenId)) : "";
    }

    /**
     * @inheritdoc IGoldenEggMetadata
     */
    function getGoldenEggTokenId(ISoundEditionV1 edition) public view returns (uint256 tokenId) {
        uint256 totalMinted = edition.totalMinted();
        uint256 mintRandomness = edition.mintRandomness();

        // If the `mintRandomness` is zero, it means that it has not been revealed,
        // and the `tokenId` should be zero, which is non-existent for our editions,
        // which token IDs start from 1.
        if (mintRandomness != 0) {
            // Calculate number between 1 and `totalMinted`.
            // `mintRandomness` is set during `edition.mint()`.
            tokenId = (mintRandomness % totalMinted) + 1;
        }
    }
}
