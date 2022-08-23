// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { LibString } from "solady/utils/LibString.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";

contract GoldenEggMetadata is IMetadataModule {
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        uint256 goldenEggTokenId = getGoldenEggTokenId(ISoundEditionV1(msg.sender));
        string memory baseURI = ISoundEditionV1(msg.sender).baseURI();

        if (tokenId == goldenEggTokenId) {
            return bytes(baseURI).length != 0 ? string.concat(baseURI, "goldenEgg") : "";
        }

        return bytes(baseURI).length != 0 ? string.concat(baseURI, LibString.toString(tokenId)) : "";
    }

    /**
     * @dev Returns token id for the golden egg, after randomness is locked. Else returns 0
     */
    function getGoldenEggTokenId(ISoundEditionV1 edition) public view returns (uint256 tokenId) {
        if (
            edition.totalMinted() >= edition.mintRandomnessTokenThreshold() ||
            block.timestamp >= edition.mintRandomnessTimeThreshold()
        ) {
            // calculate number between 1 and mintRandomnessTokenThreshold, corresponding to the blockhash
            tokenId = (uint256(edition.mintRandomness()) % edition.mintRandomnessTokenThreshold()) + 1;
        }
    }
}
