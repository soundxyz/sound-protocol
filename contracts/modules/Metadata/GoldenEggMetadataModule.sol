// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;
import "./IMetadataModule.sol";
import "solady/utils/LibString.sol";

import "../Minters/GoldenEggMinter.sol";
import "../../SoundEdition/ISoundEditionV1.sol";

contract GoldenEggMetadataModule is IMetadataModule {
    GoldenEggMinter public minter;

    constructor(GoldenEggMinter _goldenEggMinter) {
        minter = _goldenEggMinter;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        uint256 goldenEggTokenId = minter.getGoldenEggTokenId(msg.sender);
        string memory baseURI = ISoundEditionV1(msg.sender).baseURI();

        if (tokenId == goldenEggTokenId) {
            return bytes(baseURI).length != 0 ? string.concat(baseURI, "goldenEgg") : "";
        }

        return bytes(baseURI).length != 0 ? string.concat(baseURI, LibString.toString(tokenId)) : "";
    }
}
