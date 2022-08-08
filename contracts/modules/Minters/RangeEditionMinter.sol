// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

import "./MintControllerBase.sol";
import "solady/utils/Multicallable.sol";

/*
 * @dev Minter class for range edition sales.
 */
contract RangeEditionMinter is MintControllerBase, Multicallable {
    // ================================
    // CUSTOM ERRORS
    // ================================

    /**
     * The following condition must hold: `startTime` < `closingTime` < `endTime`.
     */
    error InvalidTimeRange(uint32 startTime, uint32 closingTime, uint32 endTime);

    /**
     * The following condition must hold: `maxMintableLower` < `maxMintableUpper`.
     */
    error InvalidMaxMintableRange(uint32 maxMintableLower, uint32 maxMintableUpper);

    // ================================
    // EVENTS
    // ================================

    // prettier-ignore
    event RangeEditionMintCreated(
        address indexed edition,
        uint256 indexed mintId, 
        uint256 price,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    );

    event TimeRangeSet(
        address indexed edition,
        uint256 indexed mintId,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime
    );

    event MaxMintableRangeSet(
        address indexed edition,
        uint256 indexed mintId,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    );

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
        // The lower limit of the maximum number of tokens that can be minted.
        uint32 maxMintableLower;
        // The upper limit of the maximum number of tokens that can be minted.
        uint32 maxMintableUpper;
    }

    // ================================
    // STORAGE
    // ================================

    mapping(address => mapping(uint256 => EditionMintData)) internal _editionMintData;

    // ================================
    // CREATE AND DELETE
    // ================================

    /*
     * @dev Initializes the configuration for an edition mint.
     * @param edition Address of the song edition contract we are minting for.
     * @param price Sale price in ETH for minting a single token in `edition`.
     * @param startTime Start timestamp of sale (in seconds since unix epoch).
     * @param closingTime The timestamp (in seconds since unix epoch) after which the
     * max amount of tokens mintable will drop from
     * `maxMintableUpper` to `maxMintableLower`.
     * @param endTime End timestamp of sale (in seconds since unix epoch).
     * @param maxMintableLower The lower limit of the maximum number of tokens that can be minted.
     * @param maxMintableUpper The upper limit of the maximum number of tokens that can be minted.
     */
    function createEditionMint(
        address edition,
        uint256 price,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    ) public returns (uint256 mintId) {
        mintId = _createEditionMintController(edition);

        EditionMintData storage data = _editionMintData[edition][mintId];
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
            mintId, 
            price,
            startTime,
            closingTime,
            endTime,
            maxMintableLower,
            maxMintableUpper
        );
    }

    /*
     * @dev Deletes the configuration for an edition mint.
     * @param edition Address of the song edition contract we are minting for.
     */
    function deleteEditionMint(address edition, uint256 mintId) public {
        _deleteEditionMintController(edition, mintId);
        delete _editionMintData[edition][mintId];
    }

    /**
     * @dev Returns the `EditionMintData` for `edition.
     * @param edition Address of the song edition contract we are minting for.
     */
    function editionMintData(address edition, uint256 mintId) public view returns (EditionMintData memory) {
        return _editionMintData[edition][mintId];
    }

    // ================================
    // MINT
    // ================================

    /*
     * @dev Mints tokens for a given edition.
     * @param edition Address of the song edition contract we are minting for.
     * @param quantity Token quantity to mint in song `edition`.
     */
    function mint(
        address edition,
        uint256 mintId,
        uint32 quantity
    ) public payable {
        EditionMintData storage data = _editionMintData[edition][mintId];

        _requireMintOpen(data.startTime, data.endTime);

        uint32 maxMintable;
        if (block.timestamp < data.closingTime) {
            maxMintable = data.maxMintableUpper;
        } else {
            maxMintable = data.maxMintableLower;
        }
        // Increase `totalMinted` by `quantity`.
        // Require that the increased value does not exceed `maxMintable`.
        uint32 nextTotalMinted = data.totalMinted + quantity;
        _requireNotSoldOut(nextTotalMinted, maxMintable);
        data.totalMinted = nextTotalMinted;

        _mint(edition, mintId, msg.sender, quantity, quantity * data.price);
    }

    // ================================
    // SETTER FUNCTIONS
    // ================================

    /*
     * @dev Sets the time range.
     * @param edition Address of the song edition contract we are minting for.
     * @param startTime Start timestamp of sale (in seconds since unix epoch).
     * @param closingTime The timestamp (in seconds since unix epoch) after which the
     * max amount of tokens mintable will drop from
     * `maxMintableUpper` to `maxMintableLower`.
     * @param endTime End timestamp of sale (in seconds since unix epoch).
     */
    function setTimeRange(
        address edition,
        uint256 mintId,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime
    ) public onlyEditionMintController(edition, mintId) {
        EditionMintData storage data = _editionMintData[edition][mintId];
        data.startTime = startTime;
        data.closingTime = closingTime;
        data.endTime = endTime;

        if (!(data.startTime < data.closingTime && data.closingTime < data.endTime))
            revert InvalidTimeRange(data.startTime, data.closingTime, data.endTime);

        emit TimeRangeSet(edition, mintId, startTime, closingTime, endTime);
    }

    /*
     * @dev Sets the max mintable range.
     * @param edition Address of the song edition contract we are minting for.
     * @param maxMintableLower The lower limit of the maximum number of tokens that can be minted.
     * @param maxMintableUpper The upper limit of the maximum number of tokens that can be minted.
     */
    function setMaxMintableRange(
        address edition,
        uint256 mintId,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    ) public onlyEditionMintController(edition, mintId) {
        EditionMintData storage data = _editionMintData[edition][mintId];
        data.maxMintableLower = maxMintableLower;
        data.maxMintableUpper = maxMintableUpper;

        if (!(data.maxMintableLower < data.maxMintableUpper))
            revert InvalidMaxMintableRange(data.maxMintableLower, data.maxMintableUpper);

        emit MaxMintableRangeSet(edition, mintId, maxMintableLower, maxMintableUpper);
    }
}
