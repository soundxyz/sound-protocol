// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { LibString } from "solady/utils/LibString.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ISoundEditionV2 } from "@core/interfaces/ISoundEditionV2.sol";
import { ArweaveURILib } from "@core/utils/ArweaveURILib.sol";
import { ISoundMetadata } from "@modules/interfaces/ISoundMetadata.sol";
import { LibMulticaller } from "multicaller/LibMulticaller.sol";
import { LibOps } from "@core/utils/LibOps.sol";

contract SoundMetadata is ISoundMetadata {
    using ArweaveURILib for ArweaveURILib.URI;
    // =============================================================
    //                            STRUCTS
    // =============================================================

    /**
     * @dev Struct for storing edition metadata data configuration in storage.
     */
    struct MetadataConfig {
        // The maximum `index` for `edition` that has a numbered json.
        // `0: (default: DEFAULT_NUMBER_UP_TO), otherwise: numberedUpTo`.
        uint32 numberedUpTo;
        // Whether to use the tier token ID index instead of the token ID.
        // `0: (default: true), 1: true, 2: false`.
        uint8 useTierTokenIdIndex;
    }

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /**
     * @dev The default maximum `tokenId` for `edition` that has a numbered json.
     */
    uint32 public constant DEFAULT_NUMBER_UP_TO = 1000;

    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev A mapping of `edition` => `metadataConfig`.
     */
    mapping(address => MetadataConfig) internal _configs;

    /**
     * @dev A mapping of `editionTierId` => `baseURI`.
     */
    mapping(uint256 => ArweaveURILib.URI) internal _baseURI;

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundMetadata
     */
    function setNumberedUpTo(address edition, uint32 tokenId) external onlyEditionOwnerOrAdmin(edition) {
        _configs[edition].numberedUpTo = tokenId;
        emit NumberUpToSet(edition, tokenId);
    }

    /**
     * @inheritdoc ISoundMetadata
     */
    function setUseTierTokenIdIndex(address edition, bool value) external onlyEditionOwnerOrAdmin(edition) {
        _configs[edition].useTierTokenIdIndex = value ? 1 : 2;
        emit UseTierTokenIdIndexSet(edition, value);
    }

    /**
     * @inheritdoc ISoundMetadata
     */
    function setBaseURI(
        address edition,
        uint8 tier,
        string memory uri
    ) external onlyEditionOwnerOrAdmin(edition) {
        _baseURI[LibOps.packId(edition, tier)].update(uri);
        emit BaseURISet(edition, tier, uri);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundMetadata
     */
    function numberedUpTo(address edition) public view returns (uint32) {
        uint32 n = _configs[edition].numberedUpTo;
        return n == 0 ? DEFAULT_NUMBER_UP_TO : n;
    }

    /**
     * @inheritdoc ISoundMetadata
     */
    function useTierTokenIdIndex(address edition) public view returns (bool) {
        return _configs[edition].useTierTokenIdIndex != 2;
    }

    /**
     * @inheritdoc ISoundMetadata
     */
    function baseURI(address edition, uint8 tier) public view returns (string memory) {
        return _baseURI[LibOps.packId(edition, tier)].load();
    }

    /**
     * @inheritdoc ISoundMetadata
     */
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        uint8 tier = ISoundEditionV2(msg.sender).tokenTier(tokenId);
        string memory uri = baseURI(msg.sender, tier);

        bool hasTierBaseURI = bytes(uri).length != 0; // Whether there is a tier base URI override.

        if (!hasTierBaseURI) uri = ISoundEditionV2(msg.sender).baseURI(); // Fallback to edition's base URI.

        if (bytes(uri).length == 0) return ""; // Early return "" if no base URI on edition too.

        uint256 index = useTierTokenIdIndex(msg.sender) // The tier token ID indexes are 0-indexed, but the JSONs are 1-indexed.
            ? ISoundEditionV2(msg.sender).tierTokenIdIndex(tokenId) + 1 // Token IDs are 1-indexed, just like the JSONs.
            : tokenId;

        string memory indexString = tokenId == goldenEggTokenId(msg.sender, tier)
            ? "goldenEgg"
            : (LibString.toString(index > numberedUpTo(msg.sender) ? 0 : index)); // Fallback JSON is JSON 0.

        string memory tierPostfix = hasTierBaseURI ? "" : string.concat("_", LibString.toString(tier));

        return string.concat(uri, indexString, tierPostfix);
    }

    /**
     * @inheritdoc ISoundMetadata
     */
    function goldenEggTokenId(address edition, uint8 tier) public view returns (uint256 tokenId) {
        return ISoundEditionV2(edition).mintRandomnessOneOfOne(tier);
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Guards a function to make it callable only by the edition's owner or admin.
     * @param edition The edition address.
     */
    modifier onlyEditionOwnerOrAdmin(address edition) {
        _requireOnlyEditionOwnerOrAdmin(edition);
        _;
    }

    /**
     * @dev Requires that the caller is the owner or admin of `edition`.
     * @param edition The edition address.
     */
    function _requireOnlyEditionOwnerOrAdmin(address edition) internal view {
        address sender = LibMulticaller.sender();
        if (sender != OwnableRoles(edition).owner())
            if (!OwnableRoles(edition).hasAnyRole(sender, LibOps.ADMIN_ROLE)) LibOps.revertUnauthorized();
    }
}
