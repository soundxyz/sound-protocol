// SPDX-License-Identifier: GPL-3.0-or-later
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
        uint32 mintRandomnessTokenThreshold = edition.mintRandomnessTokenThreshold();

        // If mintRandomnessTokenThreshold is zero, mintRandomness will always be zero.
        if (mintRandomnessTokenThreshold == 0) {
            return 0;
        }

        uint256 mintRandomness = edition.mintRandomness();

        if (mintRandomness != 0) {
            // Calculate number between 1 and mintRandomnessTokenThreshold.
            // mintRandomness is set during edition.mint() & corresponds to the blockhash.
            tokenId = (mintRandomness % edition.totalMinted()) + 1;
        }
    }
}
