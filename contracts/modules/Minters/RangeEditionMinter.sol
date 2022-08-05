// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

import "./MintControllerBase.sol";
import "../../SoundEdition/ISoundEditionV1.sol";
import "solady/utils/Multicallable.sol";

/// @dev Minter class for range edition sales.
contract RangeEditionMinter is MintControllerBase, Multicallable {
    // ================================
    // CUSTOM ERRORS
    // ================================

    error InvalidTimeRange(uint32 startTime, uint32 closingTime, uint32 endTime);

    error InvalidMaxMintableRange(uint32 maxMintableLower, uint32 maxMintableUpper);

    error SoldOut(uint32 maxMintable);

    error MintNotOpen(uint32 startTime, uint32 endTime);

    // ================================
    // EVENTS
    // ================================

    // prettier-ignore
    event RangeEditionMintCreated(
        address indexed edition,
        uint256 price,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    );

    event TimeRangeSet(address indexed edition, uint32 startTime, uint32 closingTime, uint32 endTime);

    event MaxMintableRangeSet(address indexed edition, uint32 maxMintableLower, uint32 maxMintableUpper);

    // ================================
    // STRUCTS
    // ================================

    struct EditionMintData {
        // The price at which each token will be sold, in ETH.
        uint256 price;
        // Start timestamp of sale (in seconds since unix epoch).
        uint32 startTime;
        // The timestamp (in seconds since unix epoch) after which the
        // max amount of tokens mintable will drop from
        // `maxMintableUpper` to `maxMintableLower`.
        uint32 closingTime;
        // End timestamp of sale (in seconds since unix epoch).
        uint32 endTime;
        // The total number of tokens minted. Includes permissioned mints.
        uint32 totalMinted;
        // The upper limit of the maximum number of tokens that can be minted.
        uint32 maxMintableUpper;
        // The lower limit of the maximum number of tokens that can be minted.
        uint32 maxMintableLower;
        // Whether the sale is paused.
        bool paused;
    }

    // ================================
    // STORAGE
    // ================================

    mapping(address => EditionMintData) internal _editionMintData;

    // ================================
    // CREATE AND DELETE
    // ================================

    /// @dev Initializes the configuration for an edition mint.
    function createEditionMint(
        address edition,
        uint256 price,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    ) public {
        _createEditionMintController(edition);

        EditionMintData storage data = _editionMintData[edition];
        data.price = price;
        data.startTime = startTime;
        data.closingTime = closingTime;
        data.endTime = endTime;
        data.maxMintableLower = maxMintableLower;
        data.maxMintableUpper = maxMintableUpper;

        if (!(data.startTime < data.closingTime && data.closingTime < data.endTime))
            revert InvalidTimeRange(data.startTime, data.closingTime, data.endTime);

        if (!(data.maxMintableLower < data.maxMintableUpper))
            revert InvalidMaxMintableRange(data.maxMintableLower, data.maxMintableUpper);

        // prettier-ignore
        emit RangeEditionMintCreated(
            edition,
            price,
            startTime,
            closingTime,
            endTime,
            maxMintableLower,
            maxMintableUpper
        );
    }

    /// @dev Deletes the configuration for an edition mint.
    function deleteEditionMint(address edition) public {
        _deleteEditionMintController(edition);
        delete _editionMintData[edition];
    }

    /// @dev Returns the `EditionMintData` for `edition.
    function editionMintData(address edition) public view returns (EditionMintData memory) {
        return _editionMintData[edition];
    }

    // ================================
    // MINT
    // ================================

    /// @dev Mints tokens for a given edition.
    function mint(address edition, uint32 quantity) public payable {
        EditionMintData storage data = _editionMintData[edition];
        // Require not paused.
        _requireMintNotPaused(edition);
        // Require exact payment.
        _requireExactPayment(data.price * quantity);
        // Require started.
        if (block.timestamp < data.startTime) revert MintNotOpen(data.startTime, data.endTime);
        // Require not ended.
        if (block.timestamp > data.endTime) revert MintNotOpen(data.startTime, data.endTime);

        uint32 maxMintable;
        if (block.timestamp < data.closingTime) {
            maxMintable = data.maxMintableUpper;
        } else {
            maxMintable = data.maxMintableLower;
        }
        // Increase `totalMinted` by `quantity`.
        // Require that the increased value does not exceed `maxMintable`.
        if ((data.totalMinted += quantity) > maxMintable) revert SoldOut(maxMintable);

        ISoundEditionV1(edition).mint{ value: msg.value }(msg.sender, quantity);
    }

    // ================================
    // SETTER FUNCTIONS
    // ================================

    /// @dev Sets the time range.
    function setTimeRange(
        address edition,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime
    ) public onlyEditionMintController(edition) {
        EditionMintData storage data = _editionMintData[edition];
        data.startTime = startTime;
        data.closingTime = closingTime;
        data.endTime = endTime;

        if (!(data.startTime < data.closingTime && data.closingTime < data.endTime))
            revert InvalidTimeRange(data.startTime, data.closingTime, data.endTime);

        emit TimeRangeSet(edition, startTime, closingTime, endTime);
    }

    /// @dev Sets the max mintable range.
    function setMaxMintableRange(
        address edition,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    ) public onlyEditionMintController(edition) {
        EditionMintData storage data = _editionMintData[edition];
        data.maxMintableLower = maxMintableLower;
        data.maxMintableUpper = maxMintableUpper;

        if (!(data.maxMintableLower < data.maxMintableUpper))
            revert InvalidMaxMintableRange(data.maxMintableLower, data.maxMintableUpper);

        emit MaxMintableRangeSet(edition, maxMintableLower, maxMintableUpper);
    }

}
