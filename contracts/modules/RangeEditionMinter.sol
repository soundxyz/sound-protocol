// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { IRangeEditionMinter, EditionMintData, MintInfo } from "./interfaces/IRangeEditionMinter.sol";
import { BaseMinter } from "./BaseMinter.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";

/*
 * @title RangeEditionMinter
 * @notice Module for range edition mints of Sound editions.
 * @author Sound.xyz
 */
contract RangeEditionMinter is IRangeEditionMinter, BaseMinter {
    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev Edition mint data
     * edition => mintId => EditionMintData
     */
    mapping(address => mapping(uint128 => EditionMintData)) internal _editionMintData;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor(ISoundFeeRegistry feeRegistry_) BaseMinter(feeRegistry_) {}

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IRangeEditionMinter
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
    ) public onlyValidCombinedTimeRange(startTime, cutoffTime, endTime) returns (uint128 mintId) {
        if (maxMintableLower > maxMintableUpper) revert InvalidMaxMintableRange();
        if (maxMintablePerAccount == 0) revert MaxMintablePerAccountIsZero();

        mintId = _createEditionMint(edition, startTime, endTime, affiliateFeeBPS);

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.price = price;
        data.cutoffTime = cutoffTime;
        data.maxMintableLower = maxMintableLower;
        data.maxMintableUpper = maxMintableUpper;
        data.maxMintablePerAccount = maxMintablePerAccount;

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
     * @inheritdoc IRangeEditionMinter
     */
    function mint(
        address edition,
        uint128 mintId,
        uint32 quantity,
        address affiliate
    ) public payable {
        EditionMintData storage data = _editionMintData[edition][mintId];

        uint32 _maxMintable = _getMaxMintable(data);

        // Increase `totalMinted` by `quantity`.
        // Require that the increased value does not exceed `maxMintable`.
        data.totalMinted = _incrementTotalMinted(data.totalMinted, quantity, _maxMintable);

        unchecked {
            // Check the additional `requestedQuantity` does not exceed the maximum mintable per account.
            uint256 numberMinted = ISoundEditionV1(edition).numberMinted(msg.sender);
            // Won't overflow. The total number of tokens minted in `edition` won't exceed `type(uint32).max`,
            // and `quantity` has 32 bits.
            if (numberMinted + quantity > data.maxMintablePerAccount) revert ExceedsMaxPerAccount();
        }

        _mint(edition, mintId, quantity, affiliate);
    }

    /**
     * @inheritdoc IRangeEditionMinter
     */
    function setTimeRange(
        address edition,
        uint128 mintId,
        uint32 startTime,
        uint32 cutoffTime,
        uint32 endTime
    ) public onlyEditionOwnerOrAdmin(edition) onlyValidCombinedTimeRange(startTime, cutoffTime, endTime) {
        // Set cutoffTime first, as its stored value gets validated later in the execution.
        EditionMintData storage data = _editionMintData[edition][mintId];
        data.cutoffTime = cutoffTime;

        // This calls the overriden `setTimeRange`, which will check that
        // `startTime < cutoffTime < endTime`.
        RangeEditionMinter.setTimeRange(edition, mintId, startTime, endTime);

        emit CutoffTimeSet(edition, mintId, cutoffTime);
    }

    /**
     * @inheritdoc BaseMinter
     */
    function setTimeRange(
        address edition,
        uint128 mintId,
        uint32 startTime,
        uint32 endTime
    ) public override(BaseMinter, IMinterModule) onlyEditionOwnerOrAdmin(edition) {
        EditionMintData storage data = _editionMintData[edition][mintId];

        if (!(startTime < data.cutoffTime && data.cutoffTime < endTime)) revert InvalidTimeRange();

        BaseMinter.setTimeRange(edition, mintId, startTime, endTime);
    }

    /**
     * @inheritdoc IRangeEditionMinter
     */
    function setMaxMintableRange(
        address edition,
        uint128 mintId,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    ) public onlyEditionOwnerOrAdmin(edition) {
        if (maxMintableLower > maxMintableUpper) revert InvalidMaxMintableRange();

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.maxMintableLower = maxMintableLower;
        data.maxMintableUpper = maxMintableUpper;

        emit MaxMintableRangeSet(edition, mintId, maxMintableLower, maxMintableUpper);
    }

    /**
     * @inheritdoc IRangeEditionMinter
     */
    function setPrice(
        address edition,
        uint128 mintId,
        uint96 price
    ) public onlyEditionOwnerOrAdmin(edition) {
        _editionMintData[edition][mintId].price = price;
        emit PriceSet(edition, mintId, price);
    }

    /**
     * @inheritdoc IRangeEditionMinter
     */
    function setMaxMintablePerAccount(
        address edition,
        uint128 mintId,
        uint32 maxMintablePerAccount
    ) public onlyEditionOwnerOrAdmin(edition) {
        if (maxMintablePerAccount == 0) revert MaxMintablePerAccountIsZero();
        _editionMintData[edition][mintId].maxMintablePerAccount = maxMintablePerAccount;
        emit MaxMintablePerAccountSet(edition, mintId, maxMintablePerAccount);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IMinterModule
     */
    function totalPrice(
        address edition,
        uint128 mintId,
        address, /* minter */
        uint32 quantity
    ) public view virtual override(BaseMinter, IMinterModule) returns (uint128) {
        unchecked {
            // Will not overflow, as `price` is 96 bits, and `quantity` is 32 bits. 96 + 32 = 128.
            return uint128(uint256(_editionMintData[edition][mintId].price) * uint256(quantity));
        }
    }

    /**
     * @inheritdoc IRangeEditionMinter
     */
    function mintInfo(address edition, uint128 mintId) external view returns (MintInfo memory) {
        BaseData memory baseData = _baseData[edition][mintId];
        EditionMintData storage mintData = _editionMintData[edition][mintId];

        MintInfo memory combinedMintData = MintInfo(
            baseData.startTime,
            baseData.endTime,
            baseData.affiliateFeeBPS,
            baseData.mintPaused,
            mintData.price,
            mintData.maxMintableUpper,
            mintData.maxMintableLower,
            mintData.maxMintablePerAccount,
            mintData.totalMinted,
            mintData.cutoffTime
        );

        return combinedMintData;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, BaseMinter) returns (bool) {
        return BaseMinter.supportsInterface(interfaceId) || interfaceId == type(IRangeEditionMinter).interfaceId;
    }

    /**
     * @inheritdoc IMinterModule
     */
    function moduleInterfaceId() public pure returns (bytes4) {
        return type(IRangeEditionMinter).interfaceId;
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
    modifier onlyValidCombinedTimeRange(
        uint32 startTime,
        uint32 cutoffTime,
        uint32 endTime
    ) {
        if (!(startTime < cutoffTime && cutoffTime < endTime)) revert InvalidTimeRange();
        _;
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
