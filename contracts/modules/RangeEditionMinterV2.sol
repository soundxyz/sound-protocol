// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { IRangeEditionMinterV2, EditionMintData, MintInfo } from "./interfaces/IRangeEditionMinterV2.sol";
import { BaseMinterV2 } from "./BaseMinterV2.sol";
import { IMinterModuleV2 } from "@core/interfaces/IMinterModuleV2.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";

/*
 * @title RangeEditionMinterV2
 * @notice Module for range edition mints of Sound editions.
 * @author Sound.xyz
 */
contract RangeEditionMinterV2 is IRangeEditionMinterV2, BaseMinterV2 {
    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev Edition mint data.
     *      `_baseDataSlot(_getBaseData(edition, mintId))` => value.
     */
    mapping(bytes32 => EditionMintData) internal _editionMintData;

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IRangeEditionMinterV2
     */
    function createEditionMint(
        address edition,
        uint96 price,
        uint32 startTime,
        uint32 cutoffTime,
        uint32 endTime,
        uint16 affiliateFeeBPS,
        uint32 maxMintableLower,
        uint32 maxMintableUpper,
        uint32 maxMintablePerAccount
    ) public returns (uint128 mintId) {
        _requireValidCombinedTimeRange(startTime, cutoffTime, endTime);
        if (maxMintableLower > maxMintableUpper) revert InvalidMaxMintableRange();
        if (maxMintablePerAccount == 0) revert MaxMintablePerAccountIsZero();

        mintId = _createEditionMint(edition, startTime, endTime, affiliateFeeBPS);

        BaseData storage baseData = _getBaseDataUnchecked(edition, mintId);
        baseData.price = price;
        baseData.maxMintablePerAccount = maxMintablePerAccount;

        EditionMintData storage data = _editionMintData[_baseDataSlot(baseData)];
        data.cutoffTime = cutoffTime;
        data.maxMintableLower = maxMintableLower;
        data.maxMintableUpper = maxMintableUpper;

        // prettier-ignore
        emit RangeEditionMintCreated(
            edition,
            mintId,
            price,
            startTime,
            cutoffTime,
            endTime,
            affiliateFeeBPS,
            maxMintableLower,
            maxMintableUpper,
            maxMintablePerAccount
        );
    }

    /**
     * @inheritdoc IRangeEditionMinterV2
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
        EditionMintData storage data = _editionMintData[_baseDataSlot(baseData)];

        uint32 _maxMintable = _getMaxMintable(data);

        // Increase `totalMinted` by `quantity`.
        // Require that the increased value does not exceed `maxMintable`.
        data.totalMinted = _incrementTotalMinted(data.totalMinted, quantity, _maxMintable);

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
     * @inheritdoc IRangeEditionMinterV2
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
     * @inheritdoc IRangeEditionMinterV2
     */
    function setTimeRange(
        address edition,
        uint128 mintId,
        uint32 startTime,
        uint32 cutoffTime,
        uint32 endTime
    ) public onlyEditionOwnerOrAdmin(edition) {
        _requireValidCombinedTimeRange(startTime, cutoffTime, endTime);

        BaseData storage baseData = _getBaseData(edition, mintId);
        EditionMintData storage data = _editionMintData[_baseDataSlot(baseData)];

        data.cutoffTime = cutoffTime;
        baseData.startTime = startTime;
        baseData.endTime = endTime;

        emit CutoffTimeSet(edition, mintId, cutoffTime);
        emit TimeRangeSet(edition, mintId, startTime, endTime);
    }

    /**
     * @inheritdoc BaseMinterV2
     */
    function setTimeRange(
        address edition,
        uint128 mintId,
        uint32 startTime,
        uint32 endTime
    ) public override(BaseMinterV2, IMinterModuleV2) onlyEditionOwnerOrAdmin(edition) {
        BaseData storage baseData = _getBaseData(edition, mintId);
        EditionMintData storage data = _editionMintData[_baseDataSlot(baseData)];

        _requireValidCombinedTimeRange(startTime, data.cutoffTime, endTime);

        baseData.startTime = startTime;
        baseData.endTime = endTime;

        emit TimeRangeSet(edition, mintId, startTime, endTime);
    }

    /**
     * @inheritdoc IRangeEditionMinterV2
     */
    function setMaxMintableRange(
        address edition,
        uint128 mintId,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    ) public onlyEditionOwnerOrAdmin(edition) {
        if (maxMintableLower > maxMintableUpper) revert InvalidMaxMintableRange();
        EditionMintData storage data = _editionMintData[_baseDataSlot(_getBaseData(edition, mintId))];
        data.maxMintableLower = maxMintableLower;
        data.maxMintableUpper = maxMintableUpper;

        emit MaxMintableRangeSet(edition, mintId, maxMintableLower, maxMintableUpper);
    }

    /**
     * @inheritdoc IRangeEditionMinterV2
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
     * @inheritdoc IRangeEditionMinterV2
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
     * @inheritdoc IRangeEditionMinterV2
     */
    function mintInfo(address edition, uint128 mintId) external view returns (MintInfo memory info) {
        BaseData storage baseData = _getBaseData(edition, mintId);
        EditionMintData storage mintData = _editionMintData[_baseDataSlot(baseData)];

        info.startTime = baseData.startTime;
        info.endTime = baseData.endTime;
        info.affiliateFeeBPS = baseData.affiliateFeeBPS;
        info.mintPaused = baseData.mintPaused;
        info.price = baseData.price;
        info.maxMintableUpper = mintData.maxMintableUpper;
        info.maxMintableLower = mintData.maxMintableLower;
        info.maxMintablePerAccount = baseData.maxMintablePerAccount;
        info.totalMinted = mintData.totalMinted;
        info.cutoffTime = mintData.cutoffTime;

        info.affiliateMerkleRoot = baseData.affiliateMerkleRoot;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, BaseMinterV2) returns (bool) {
        return BaseMinterV2.supportsInterface(interfaceId) || interfaceId == type(IRangeEditionMinterV2).interfaceId;
    }

    /**
     * @inheritdoc IMinterModuleV2
     */
    function moduleInterfaceId() public pure returns (bytes4) {
        return type(IRangeEditionMinterV2).interfaceId;
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Restricts the `startTime` to be less than `cutoffTime`,
     *      and `cutoffTime` to be less than `endTime`.
     * @param startTime   The start unix timestamp of the mint.
     * @param cutoffTime  The cutoff unix timestamp of the mint.
     * @param endTime     The end unix timestamp of the mint.
     */
    function _requireValidCombinedTimeRange(
        uint32 startTime,
        uint32 cutoffTime,
        uint32 endTime
    ) internal pure {
        if (!(startTime < cutoffTime && cutoffTime < endTime)) revert InvalidTimeRange();
    }

    /**
     * @dev Gets the current maximum mintable quantity.
     * @param data The edition mint data.
     * @return The computed value.
     */
    function _getMaxMintable(EditionMintData storage data) internal view returns (uint32) {
        uint32 _maxMintable;
        if (block.timestamp < data.cutoffTime) {
            _maxMintable = data.maxMintableUpper;
        } else {
            _maxMintable = data.maxMintableLower;
        }
        return _maxMintable;
    }
}
