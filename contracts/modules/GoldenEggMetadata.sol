// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { LibString } from "solady/utils/LibString.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";

contract GoldenEggMetadata is IMetadataModule {
    /**
     * @dev When registered on a SoundEdition proxy, its `tokenURI` redirects execution to this `tokenURI`.
     * @param tokenId The token ID to retrieve the token URI for.
     * @return The token URI string.
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
     * @dev Returns token ID for the golden egg after the edition is sold out or the `mintRandomness` is locked, else returns 0.
     * @param edition The edition address.
     * @return tokenId The token ID for the golden egg.
     */
    function getGoldenEggTokenId(ISoundEditionV1 edition) public view returns (uint256 tokenId) {
        uint32 editionMaxMintable = edition.editionMaxMintable();
        uint32 totalMinted = uint32(edition.totalMinted());
        bool isSoldOut = totalMinted == editionMaxMintable;
        uint32 mintRandomnessTokenThreshold = edition.mintRandomnessTokenThreshold();

        // Return the golden egg token id if...
        if (
            // edition is sold out, or
            isSoldOut ||
            // mintRandomnessTimeThreshold is set and it's less than or equal to total minted, or
            (mintRandomnessTokenThreshold > 0 && mintRandomnessTokenThreshold <= totalMinted) ||
            // the current time is past mintRandomnessTimeThreshold.
            block.timestamp >= edition.mintRandomnessTimeThreshold()
        ) {
            // Always use mintRandomnessTokenThreshold as the upper bound if it is set, otherwise use the total minted.
            uint32 upperBound = mintRandomnessTokenThreshold > 0 ? mintRandomnessTokenThreshold : totalMinted;
            // Calculate number between 1 and upper bound (mintRandomness corresponds to the blockhash).
            tokenId = (uint256(uint72(edition.mintRandomness())) % upperBound) + 1;
        }
    }

    function _minUint32(uint32 a, uint32 b) internal pure returns (uint32) {
        if (a < b) {
            return a;
        }
        return b;
    }
}
