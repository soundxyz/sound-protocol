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
    /**
     * @dev Edition mint data
     * edition => mintId => EditionMintData
     */
    mapping(address => mapping(uint256 => EditionMintData)) internal _editionMintData;
    /**
     * @dev Number of tokens minted by each buyer address
     * edition => mintId => buyer => mintedTallies
     */
    mapping(address => mapping(uint256 => mapping(address => uint256))) public mintedTallies;

    // ================================
    // MODIFIERS
    // ================================

    /**
     * @dev Restricts the start time to be less than the end time.
     */
    modifier onlyValidRangeTimes(
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime
    ) virtual {
        if (!(startTime < closingTime && closingTime < endTime)) revert InvalidTimeRange();
        _;
    }

    // ================================
    // WRITE FUNCTIONS
    // ================================

    constructor(ISoundFeeRegistry feeRegistry_) BaseMinter(feeRegistry_) {}

    /// @inheritdoc IRangeEditionMinter
    function createEditionMint(
        address edition,
        uint96 price,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime,
        uint16 affiliateFeeBPS,
        uint32 maxMintableLower,
        uint32 maxMintableUpper,
        uint32 maxMintablePerAccount_
    ) public onlyValidRangeTimes(startTime, closingTime, endTime) returns (uint256 mintId) {
        if (!(maxMintableLower < maxMintableUpper)) revert InvalidMaxMintableRange(maxMintableLower, maxMintableUpper);

        mintId = _createEditionMint(edition, startTime, endTime, affiliateFeeBPS);

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.price = price;
        data.closingTime = closingTime;
        data.maxMintableLower = maxMintableLower;
        data.maxMintableUpper = maxMintableUpper;
        data.maxMintablePerAccount = maxMintablePerAccount_;

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
            maxMintablePerAccount_
        );
    }

    /// @inheritdoc IRangeEditionMinter
    function mint(
        address edition,
        uint256 mintId,
        uint32 quantity,
        address affiliate
    ) public payable {
        EditionMintData storage data = _editionMintData[edition][mintId];

        uint32 _maxMintable = _getMaxMintable(data);

        // Increase `totalMinted` by `quantity`.
        // Require that the increased value does not exceed `maxMintable`.
        uint32 nextTotalMinted = data.totalMinted + quantity;
        _requireNotSoldOut(nextTotalMinted, _maxMintable);
        data.totalMinted = nextTotalMinted;

        uint256 userMintedBalance = mintedTallies[edition][mintId][msg.sender];
        // check the additional quantity does not exceed the set maximum
        if ((userMintedBalance + quantity) > data.maxMintablePerAccount) revert ExceedsMaxPerAccount();

        mintedTallies[edition][mintId][msg.sender] = userMintedBalance + quantity;

        _mint(edition, mintId, quantity, affiliate);
    }

    /// @inheritdoc IRangeEditionMinter
    function setTimeRange(
        address edition,
        uint256 mintId,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime
    ) public onlyEditionOwnerOrAdmin(edition) onlyValidRangeTimes(startTime, closingTime, endTime) {
        // Set closingTime first, as its stored value gets validated later in the execution.
        EditionMintData storage data = _editionMintData[edition][mintId];
        data.closingTime = closingTime;

        // This calls _beforeSetTimeRange, which does the closingTime validation.
        _setTimeRange(edition, mintId, startTime, endTime);

        emit ClosingTimeSet(edition, mintId, closingTime);
    }

    /// @inheritdoc BaseMinter
    function setTimeRange(
        address edition,
        uint256 mintId,
        uint32 startTime,
        uint32 endTime
    ) public override(BaseMinter, IMinterModule) onlyEditionOwnerOrAdmin(edition) {
        EditionMintData storage data = _editionMintData[edition][mintId];
        if (!(startTime < data.closingTime && data.closingTime < endTime)) revert InvalidTimeRange();

        _setTimeRange(edition, mintId, startTime, endTime);
    }

    /// @inheritdoc IRangeEditionMinter
    function setMaxMintableRange(
        address edition,
        uint256 mintId,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    ) public onlyEditionOwnerOrAdmin(edition) {
        if (!(maxMintableLower < maxMintableUpper)) revert InvalidMaxMintableRange(maxMintableLower, maxMintableUpper);

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.maxMintableLower = maxMintableLower;
        data.maxMintableUpper = maxMintableUpper;

        emit MaxMintableRangeSet(edition, mintId, maxMintableLower, maxMintableUpper);
    }

    // ================================
    // VIEW FUNCTIONS
    // ================================

    function totalPrice(
        address edition,
        uint256 mintId,
        address, /* minter */
        uint32 quantity
    ) public view virtual override returns (uint256) {
        return _editionMintData[edition][mintId].price * quantity;
    }

    /**
     * @dev Returns the `EditionMintData` for `edition`.
     * @param edition Address of the song edition contract we are minting for.
     */
    function editionMintData(address edition, uint256 mintId) public view returns (EditionMintData memory) {
        return _editionMintData[edition][mintId];
    }

    function mintInfo(address edition, uint256 mintId) public view returns (MintInfo memory) {
        BaseData memory baseData = _baseData[edition][mintId];
        EditionMintData storage mintData = _editionMintData[edition][mintId];

        MintInfo memory combinedMintData = MintInfo(
            baseData.startTime,
            baseData.endTime,
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

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, BaseMinter) returns (bool) {
        return BaseMinter.supportsInterface(interfaceId) || interfaceId == type(IRangeEditionMinter).interfaceId;
    }

    // @inheritdoc IMinterModule
    function moduleInterfaceId() public pure returns (bytes4) {
        return type(IRangeEditionMinter).interfaceId;
    }

    // ================================
    // INTERNAL FUNCTIONS
    // ================================

    /**
     * @dev Gets the current maximum mintable quantity.
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
