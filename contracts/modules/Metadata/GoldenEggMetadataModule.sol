// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;
import "./IMetadataModule.sol";
import "solady/utils/LibString.sol";

import "../../SoundEdition/ISoundEditionV1.sol";

contract GoldenEggMetadataModule is IMetadataModule {
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        uint256 goldenEggTokenId = ISoundEditionV1(msg.sender).getGoldenEggTokenId();
        string memory baseURI = ISoundEditionV1(msg.sender).baseURI();

        if (tokenId == goldenEggTokenId) {
            return bytes(baseURI).length != 0 ? string.concat(baseURI, "goldenEgg") : "";
        }

        return bytes(baseURI).length != 0 ? string.concat(baseURI, LibString.toString(tokenId)) : "";
    }
}
