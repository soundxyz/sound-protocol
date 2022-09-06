// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { IRangeEditionMinter, EditionMintData, MintInfo } from "./interfaces/IRangeEditionMinter.sol";
import { BaseMinter } from "./BaseMinter.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

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

    /**
     * @dev Number of tokens minted by each buyer address
     * edition => mintId => buyer => mintedTallies
     */
    mapping(address => mapping(uint256 => mapping(address => uint256))) public mintedTallies;

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
        uint32 closingTime,
        uint32 endTime,
        uint16 affiliateFeeBPS,
        uint32 maxMintableLower,
        uint32 maxMintableUpper,
        uint32 maxMintablePerAccount
    ) public onlyValidRangeTimes(startTime, closingTime, endTime) returns (uint128 mintId) {
        if (!(maxMintableLower <= maxMintableUpper)) revert InvalidMaxMintableRange(maxMintableLower, maxMintableUpper);

        mintId = _createEditionMint(edition, startTime, endTime, affiliateFeeBPS);

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.price = price;
        data.closingTime = closingTime;
        data.maxMintableLower = maxMintableLower;
        data.maxMintableUpper = maxMintableUpper;
        data.maxMintablePerAccount = maxMintablePerAccount;

        // prettier-ignore
        emit RangeEditionMintCreated(
            edition,
            mintId,
            price,
            startTime,
            closingTime,
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
            uint256 userMintedBalance = mintedTallies[edition][mintId][msg.sender];
            // Check the additional quantity does not exceed the set maximum.
            // If `quantity` is large enough to cause an overflow,
            // `_mint` will give an out of gas error.
            uint256 tally = userMintedBalance + quantity;
            if (tally > data.maxMintablePerAccount) revert ExceedsMaxPerAccount();
            // Update the minted tally for this account
            mintedTallies[edition][mintId][msg.sender] = tally;
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
        uint32 closingTime,
        uint32 endTime
    ) public onlyEditionOwnerOrAdmin(edition) onlyValidRangeTimes(startTime, closingTime, endTime) {
        // Set closingTime first, as its stored value gets validated later in the execution.
        EditionMintData storage data = _editionMintData[edition][mintId];
        data.closingTime = closingTime;

        // This calls the overriden `setTimeRange`, which will check that
        // `startTime < closingTime < endTime`.
        RangeEditionMinter.setTimeRange(edition, mintId, startTime, endTime);

        emit ClosingTimeSet(edition, mintId, closingTime);
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

        if (!(startTime < data.closingTime && data.closingTime < endTime)) revert InvalidTimeRange();

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
        if (!(maxMintableLower <= maxMintableUpper)) revert InvalidMaxMintableRange(maxMintableLower, maxMintableUpper);

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.maxMintableLower = maxMintableLower;
        data.maxMintableUpper = maxMintableUpper;

        emit MaxMintableRangeSet(edition, mintId, maxMintableLower, maxMintableUpper);
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
            // Won't overflow, as `price` is 96 bits, and `quantity` is 32 bits.
            return _editionMintData[edition][mintId].price * quantity;
        }
    }

    /**
     * @inheritdoc IRangeEditionMinter
     */
    function mintInfo(address edition, uint128 mintId) public view returns (MintInfo memory) {
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
            mintData.closingTime
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
     * @dev Restricts the start time to be less than the end time.
     * @param startTime The start unix timestamp of the mint.
     * @param endTime   The closing unix timestamp of the mint.
     * @param endTime   The end unix timestamp of the mint.
     */
    modifier onlyValidRangeTimes(
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime
    ) virtual {
        if (!(startTime < closingTime && closingTime < endTime)) revert InvalidTimeRange();
        _;
    }

    /**
     * @dev Gets the current maximum mintable quantity.
     * @param data The edition mint data.
     * @return The computed value.
     */
    function _getMaxMintable(EditionMintData storage data) internal view returns (uint32) {
        uint32 _maxMintable;
        if (block.timestamp < data.closingTime) {
            _maxMintable = data.maxMintableUpper;
        } else {
            _maxMintable = data.maxMintableLower;
        }
        return _maxMintable;
    }
}
