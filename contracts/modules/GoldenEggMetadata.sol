// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { LibString } from "solady/utils/LibString.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ISoundEditionV1_1 } from "@core/interfaces/ISoundEditionV1_1.sol";
import { IGoldenEggMetadata } from "@modules/interfaces/IGoldenEggMetadata.sol";

contract GoldenEggMetadata is IGoldenEggMetadata {
    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev The maximum `tokenId` for `edition` that has a numbered json.
     * If zero, all `tokenId`s have number jsons.
     */
    mapping(address => uint256) public numberedUpto;

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IGoldenEggMetadata
     */
    function setNumberedUpto(address edition, uint256 tokenId) external onlyEditionOwnerOrAdmin(edition) {
        numberedUpto[edition] = tokenId;
        emit NumberUptoSet(edition, tokenId);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IGoldenEggMetadata
     */
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        uint256 goldenEggTokenId = getGoldenEggTokenId(msg.sender);
        string memory baseURI = ISoundEditionV1_1(msg.sender).baseURI();

        if (bytes(baseURI).length == 0) return "";

        if (tokenId == goldenEggTokenId) return string.concat(baseURI, "goldenEgg");

        uint256 n = numberedUpto[msg.sender];
        return string.concat(baseURI, LibString.toString(n != 0 && tokenId > n ? 0 : tokenId));
    }

    /**
     * @inheritdoc IGoldenEggMetadata
     */
    function getGoldenEggTokenId(address edition) public view returns (uint256 tokenId) {
        uint256 editionMaxMintable = ISoundEditionV1_1(edition).editionMaxMintable();
        uint256 mintRandomness = ISoundEditionV1_1(edition).mintRandomness();

        // If the `mintRandomness` is zero, it means that it has not been revealed,
        // and the `tokenId` should be zero, which is non-existent for our editions,
        // which token IDs start from 1.
        if (mintRandomness != 0) {
            // Calculate number between 1 and `editionMaxMintable`.
            // `mintRandomness` is set during `edition.mint()`.
            tokenId = (mintRandomness % editionMaxMintable) + 1;
        }
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Restricts the function to be only callable by the owner or admin of `edition`.
     * @param edition The edition address.
     */
    modifier onlyEditionOwnerOrAdmin(address edition) virtual {
        if (
            msg.sender != OwnableRoles(edition).owner() &&
            !OwnableRoles(edition).hasAnyRole(msg.sender, ISoundEditionV1_1(edition).ADMIN_ROLE())
        ) revert Unauthorized();

        _;
    }
}
