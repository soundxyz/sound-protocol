// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

import "./MintControllerBase.sol";
import "../../SoundEdition/ISoundEditionV1.sol";
import "solady/utils/ECDSA.sol";
import "solady/utils/LibBitmap.sol";
import "solady/utils/Multicallable.sol";

/// @dev Minter class for range edition sales.
contract RangeEditionMinter is MintControllerBase, Multicallable {
    using ECDSA for bytes32;
    using LibBitmap for LibBitmap.Bitmap;

    // ================================
    // CUSTOM ERRORS
    // ================================

    error InvalidTimeRange(uint32 startTime, uint32 closingTime, uint32 endTime);

    error InvalidMaxMintableRange(uint32 maxMintableLower, uint32 maxMintableUpper);

    error WrongEtherValue(uint256 paid, uint256 required);

    error SoldOut(uint32 maxMintable);

    error MintPaused();

    error MintNotOpen(uint32 startTime, uint32 endTime);

    error MintDataLocked();

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

    event PausedSet(address indexed edition, bool paused);

    event Locked(address indexed edition);

    // ================================
    // STRUCTS
    // ================================

    struct EditionMintData {
        // The price at which each token will be sold, in ETH.
        uint256 price;
        // Start timestamp of sale (in seconds since unix epoch).
        uint32 startTime;
        // The timestamp (in seconds since unix epoch)
        // after which the `totalMinted` is frozen if it is
        // more than the `minToFreeze`.
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
        // Whether the data is locked.
        bool locked;
    }

    // ================================
    // STORAGE
    // ================================

    mapping(address => EditionMintData) internal _editionMintData;

    // ================================
    // CREATE AND DELETE
    // ================================

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

        _validateEditionMintData(data);

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

    function deleteEditionMint(address edition) public {
        _deleteEditionMintController(edition);
        delete _editionMintData[edition];
    }

    function editionMintData(address edition) public view returns (EditionMintData memory) {
        return _editionMintData[edition];
    }

    // ================================
    // INTERNAL HELPER FUNCTIONS
    // ================================

    function _validateEditionMintData(EditionMintData storage data) internal view {
        if (data.startTime > data.closingTime || data.closingTime > data.endTime) {
            revert InvalidTimeRange(data.startTime, data.closingTime, data.endTime);
        }
        if (data.maxMintableLower > data.maxMintableUpper) {
            revert InvalidMaxMintableRange(data.maxMintableLower, data.maxMintableUpper);
        }
        if (data.locked) {
            revert MintDataLocked();
        }
    }

    // ================================
    // MINT
    // ================================

    function mint(address edition, uint32 quantity) public payable {
        unchecked {
            EditionMintData storage data = _editionMintData[edition];
            // Require not paused.
            if (data.paused) revert MintPaused();
            // Require exact payment.
            uint256 requiredPayment = data.price * quantity;
            if (requiredPayment != msg.value) revert WrongEtherValue(msg.value, requiredPayment);
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
    }

    // ================================
    // SETTER FUNCTIONS
    // ================================

    function lock(address edition) public onlyEditionMintController(edition) {
        _editionMintData[edition].locked = true;
        emit Locked(edition);
    }

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
        _validateEditionMintData(data);
        emit TimeRangeSet(edition, startTime, closingTime, endTime);
    }

    function setMaxMintableRange(
        address edition,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    ) public onlyEditionMintController(edition) {
        EditionMintData storage data = _editionMintData[edition];
        data.maxMintableLower = maxMintableLower;
        data.maxMintableUpper = maxMintableUpper;
        _validateEditionMintData(_editionMintData[edition]);
        emit MaxMintableRangeSet(edition, maxMintableLower, maxMintableUpper);
    }

    function setPaused(address edition, bool paused) public onlyEditionMintController(edition) {
        _editionMintData[edition].paused = paused;
        _validateEditionMintData(_editionMintData[edition]);
        emit PausedSet(edition, paused);
    }

    // ================================
    // CONVENIENCE SETTER FUNCTIONS
    // ================================

    function setStartTime(address edition, uint32 startTime) public {
        setTimeRange(edition, startTime, _editionMintData[edition].closingTime, _editionMintData[edition].endTime);
    }

    function setClosingTime(address edition, uint32 closingTime) public {
        setTimeRange(edition, _editionMintData[edition].startTime, closingTime, _editionMintData[edition].endTime);
    }

    function setEndTime(address edition, uint32 endTime) public {
        setTimeRange(edition, _editionMintData[edition].startTime, _editionMintData[edition].closingTime, endTime);
    }

    function setMaxMintableLower(address edition, uint32 maxMintableLower) public {
        setMaxMintableRange(edition, maxMintableLower, _editionMintData[edition].maxMintableUpper);
    }

    function setMaxMintableUpper(address edition, uint32 maxMintableUpper) public {
        setMaxMintableRange(edition, _editionMintData[edition].maxMintableLower, maxMintableUpper);
    }

    function pause(address edition) public {
        setPaused(edition, true);
    }

    function unpause(address edition) public {
        setPaused(edition, false);
    }
}
