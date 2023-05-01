// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { IEditionMaxMinterV2, MintInfo } from "./interfaces/IEditionMaxMinterV2.sol";
import { BaseMinterV2 } from "./BaseMinterV2.sol";
import { IMinterModuleV2 } from "@core/interfaces/IMinterModuleV2.sol";
import { ISoundEditionV1, EditionInfo } from "@core/interfaces/ISoundEditionV1.sol";

/*
 * @title EditionMaxMinterV2
 * @notice Module for unpermissioned mints of Sound editions.
 * @author Sound.xyz
 */
contract EditionMaxMinterV2 is IEditionMaxMinterV2, BaseMinterV2 {
    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IEditionMaxMinterV2
     */
    function createEditionMint(
        address edition,
        uint96 price,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS,
        uint32 maxMintablePerAccount
    ) public returns (uint128 mintId) {
        if (maxMintablePerAccount == 0) revert MaxMintablePerAccountIsZero();

        mintId = _createEditionMint(edition, startTime, endTime, affiliateFeeBPS);

        BaseData storage data = _getBaseDataUnchecked(edition, mintId);
        data.price = price;
        data.maxMintablePerAccount = maxMintablePerAccount;

        // prettier-ignore
        emit EditionMaxMintCreated(
            edition,
            mintId,
            price,
            startTime,
            endTime,
            affiliateFeeBPS,
            maxMintablePerAccount
        );
    }

    /**
     * @inheritdoc IEditionMaxMinterV2
     */
    function mintTo(
        address edition,
        uint128 mintId,
        address to,
        uint32 quantity,
        address affiliate,
        bytes32[] calldata affiliateProof,
        uint256 attributionId
    ) public payable {
        BaseData storage baseData = _getBaseData(edition, mintId);

        unchecked {
            // Check the additional `requestedQuantity` does not exceed the maximum mintable per account.
            uint256 numberMinted = ISoundEditionV1(edition).numberMinted(to);
            // Won't overflow. The total number of tokens minted in `edition` won't exceed `type(uint32).max`,
            // and `quantity` has 32 bits.
            if (numberMinted + quantity > baseData.maxMintablePerAccount) revert ExceedsMaxPerAccount();
        }

        _mintTo(edition, mintId, to, quantity, affiliate, affiliateProof, attributionId);
    }

    /**
     * @inheritdoc IEditionMaxMinterV2
     */
    function mint(
        address edition,
        uint128 mintId,
        uint32 quantity,
        address affiliate
    ) public payable {
        mintTo(edition, mintId, msg.sender, quantity, affiliate, MerkleProofLib.emptyProof(), 0);
    }

    /**
     * @inheritdoc IEditionMaxMinterV2
     */
    function setPrice(
        address edition,
        uint128 mintId,
        uint96 price
    ) public onlyEditionOwnerOrAdmin(edition) {
        _getBaseData(edition, mintId).price = price;
        emit PriceSet(edition, mintId, price);
    }

    /**
     * @inheritdoc IEditionMaxMinterV2
     */
    function setMaxMintablePerAccount(
        address edition,
        uint128 mintId,
        uint32 maxMintablePerAccount
    ) public onlyEditionOwnerOrAdmin(edition) {
        if (maxMintablePerAccount == 0) revert MaxMintablePerAccountIsZero();
        _getBaseData(edition, mintId).maxMintablePerAccount = maxMintablePerAccount;
        emit MaxMintablePerAccountSet(edition, mintId, maxMintablePerAccount);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IEditionMaxMinterV2
     */
    function mintInfo(address edition, uint128 mintId) external view returns (MintInfo memory info) {
        BaseData memory baseData = _getBaseData(edition, mintId);

        EditionInfo memory editionInfo = ISoundEditionV1(edition).editionInfo();

        info.startTime = baseData.startTime;
        info.endTime = baseData.endTime;
        info.affiliateFeeBPS = baseData.affiliateFeeBPS;
        info.mintPaused = baseData.mintPaused;
        info.price = baseData.price;
        info.maxMintablePerAccount = baseData.maxMintablePerAccount;

        info.maxMintableLower = editionInfo.editionMaxMintableLower;
        info.maxMintableUpper = editionInfo.editionMaxMintableUpper;
        info.totalMinted = uint32(editionInfo.totalMinted);
        info.cutoffTime = editionInfo.editionCutoffTime;

        info.affiliateMerkleRoot = baseData.affiliateMerkleRoot;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, BaseMinterV2) returns (bool) {
        return BaseMinterV2.supportsInterface(interfaceId) || interfaceId == type(IEditionMaxMinterV2).interfaceId;
    }

    /**
     * @inheritdoc IMinterModuleV2
     */
    function moduleInterfaceId() public pure returns (bytes4) {
        return type(IEditionMaxMinterV2).interfaceId;
    }
}
