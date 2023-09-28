// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { Base64 } from "solady/utils/Base64.sol";
import { SSTORE2 } from "solady/utils/SSTORE2.sol";
import { LibZip } from "solady/utils/LibZip.sol";
import { LibString } from "solady/utils/LibString.sol";
import { JSONParserLib } from "solady/utils/JSONParserLib.sol";
import { DynamicBufferLib } from "solady/utils/DynamicBufferLib.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ISoundEditionV2 } from "@core/interfaces/ISoundEditionV2.sol";
import { ISoundOnChainMetadata } from "@modules/interfaces/ISoundOnChainMetadata.sol";
import { SoundOnChainMetadataLib as M } from "@modules/utils/SoundOnChainMetadataLib.sol";
import { LibMulticaller } from "multicaller/LibMulticaller.sol";
import { LibOps } from "@core/utils/LibOps.sol";

contract SoundOnChainMetadata is ISoundOnChainMetadata {
    using JSONParserLib for JSONParserLib.Item;
    using DynamicBufferLib for DynamicBufferLib.DynamicBuffer;

    // =============================================================
    //                            STRUCTS
    // =============================================================

    /**
     * @dev Struct to hold the SSTORE2 address.
     */
    struct Store {
        // The SSTORE2 address of the string.
        address value;
        // Whether the string has been compressed with Solady's `LibZip.flzCompress`.
        bool isCompressed;
    }

    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev A mapping of `edition` => `values` storage contract addresses.
     */
    mapping(address => Store) internal _values;

    /**
     * @dev A mapping of `templateId` hash => `template` storage contract addresses.
     */
    mapping(bytes32 => Store) internal _templates;

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundOnChainMetadata
     */
    function createTemplate(string memory templateJSON) public returns (string memory templateId) {
        templateId = predictTemplateId(templateJSON);
        Store storage s = _templates[keccak256(bytes(templateId))];
        if (s.value != address(0)) revert TemplateIdTaken();
        s.value = SSTORE2.write(bytes(templateJSON));
        emit TemplateCreated(templateId);
    }

    /**
     * @inheritdoc ISoundOnChainMetadata
     */
    function setValues(address edition, string memory valuesJSON) public onlyEditionOwnerOrAdmin(edition) {
        _values[edition] = Store(SSTORE2.write(bytes(valuesJSON)), false);
        emit ValuesSet(edition, false);
    }

    /**
     * @inheritdoc ISoundOnChainMetadata
     */
    function setValuesCompressed(address edition, bytes memory compressed) public onlyEditionOwnerOrAdmin(edition) {
        _values[edition] = Store(SSTORE2.write(bytes(compressed)), true);
        emit ValuesSet(edition, true);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ISoundOnChainMetadata
     */
    function predictTemplateId(string memory templateJSON) public pure returns (string memory) {
        return Base64.encode(abi.encodePacked(bytes9(keccak256(bytes(templateJSON)))));
    }

    /**
     * @inheritdoc ISoundOnChainMetadata
     */
    function getTemplate(string memory templateId) public view returns (string memory) {
        address ss2 = _templates[keccak256(bytes(templateId))].value;
        if (ss2 == address(0)) revert TemplateDoesNotExist();
        return string(SSTORE2.read(ss2));
    }

    /**
     * @inheritdoc ISoundOnChainMetadata
     */
    function getValues(address edition) public view returns (string memory) {
        Store memory s = _values[edition];
        if (s.value == address(0)) revert ValuesDoNotExist();
        bytes memory data = SSTORE2.read(s.value);
        if (s.isCompressed) data = LibZip.flzDecompress(data);
        return string(data);
    }

    /**
     * @inheritdoc ISoundOnChainMetadata
     */
    function rawTokenJSON(
        address edition,
        uint256 tokenId,
        uint256 sn,
        uint8 tier,
        bool isGoldenEgg
    ) external view returns (string memory) {
        DynamicBufferLib.DynamicBuffer memory buffer;
        M.walk(tokenId, sn, tier, isGoldenEgg, getTemplate, getValues(edition), buffer);
        LibString.directReturn(buffer.s());
    }

    /**
     * @inheritdoc ISoundOnChainMetadata
     */
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        DynamicBufferLib.DynamicBuffer memory buffer;
        unchecked {
            uint256 sn = ISoundEditionV2(msg.sender).tierTokenIdIndex(tokenId) + 1;
            uint8 tier = ISoundEditionV2(msg.sender).tokenTier(tokenId);
            bool isGoldenEgg = tokenId == goldenEggTokenId(msg.sender, tier);
            M.walk(tokenId, sn, tier, isGoldenEgg, getTemplate, getValues(msg.sender), buffer);
        }
        bytes memory encoded = bytes(Base64.encode(buffer.data));
        LibString.directReturn(buffer.clear().p("data:application/json;base64,").p(encoded).s());
    }

    /**
     * @inheritdoc ISoundOnChainMetadata
     */
    function goldenEggTokenId(address edition, uint8 tier) public view returns (uint256) {
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
    function _requireOnlyEditionOwnerOrAdmin(address edition) internal view virtual {
        address sender = LibMulticaller.sender();
        if (sender != OwnableRoles(edition).owner())
            if (!OwnableRoles(edition).hasAnyRole(sender, LibOps.ADMIN_ROLE)) LibOps.revertUnauthorized();
    }
}
