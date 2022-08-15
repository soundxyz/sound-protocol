// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

import "./MintControllerBase.sol";

/*
 * @dev Minter class for range edition sales.
 */
contract RangeEditionMinter is MintControllerBase {
    // ================================
    // CUSTOM ERRORS
    // ================================

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
        uint32 maxMintableUpper,
        uint32 maxAllowedPerWallet
    );

    event ClosingTimeSet(address indexed edition, uint256 indexed mintId, uint32 closingTime);

    event MaxMintableRangeSet(
        address indexed edition,
        uint256 indexed mintId,
        uint32 maxMintableLower,
        uint32 maxMintableUpper
    );

    // The number of tokens minted has exceeded the number allowed for each wallet.
    error ExceedsMaxPerWallet();

    // ================================
    // STRUCTS
    // ================================

    struct EditionMintData {
        // The price at which each token will be sold, in ETH.
        uint256 price;
        // The timestamp (in seconds since unix epoch) after which the
        // max amount of tokens mintable will drop from
        // `maxMintableUpper` to `maxMintableLower`.
        uint32 closingTime;
        // The total number of tokens minted. Includes permissioned mints.
        uint32 totalMinted;
        // The lower limit of the maximum number of tokens that can be minted.
        uint32 maxMintableLower;
        // The upper limit of the maximum number of tokens that can be minted.
        uint32 maxMintableUpper;
        // The maximum number of tokens that a wallet can mint.
        uint32 maxAllowedPerWallet;
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
        uint32 maxMintableUpper,
        uint32 maxAllowedPerWallet
    ) public returns (uint256 mintId) {
        mintId = _createEditionMintController(edition, startTime, endTime);

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.price = price;
        data.closingTime = closingTime;
        data.maxMintableLower = maxMintableLower;
        data.maxMintableUpper = maxMintableUpper;
        data.maxAllowedPerWallet = maxAllowedPerWallet;

        if (!(startTime < closingTime && closingTime < endTime)) revert InvalidTimeRange();

        if (!(maxMintableLower < maxMintableUpper)) revert InvalidMaxMintableRange(maxMintableLower, maxMintableUpper);

        // prettier-ignore
        emit RangeEditionMintCreated(
            edition,
            mintId,
            price,
            startTime,
            closingTime,
            endTime,
            maxMintableLower,
            maxMintableUpper,
            maxAllowedPerWallet
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
        uint32 requestedQuantity
    ) public payable {
        EditionMintData storage data = _editionMintData[edition][mintId];

        uint32 maxMintable;
        if (block.timestamp < data.closingTime) {
            maxMintable = data.maxMintableUpper;
        } else {
            maxMintable = data.maxMintableLower;
        }
        // Increase `totalMinted` by `quantity`.
        // Require that the increased value does not exceed `maxMintable`.
        uint32 nextTotalMinted = data.totalMinted + requestedQuantity;
        _requireNotSoldOut(nextTotalMinted, maxMintable);
        data.totalMinted = nextTotalMinted;

        uint256 userBalance = ISoundEditionV1(edition).balanceOf(msg.sender);
        // If the maximum allowed per wallet is set (i.e. is different to 0)
        // check the required additional quantity does not exceed the set maximum
        if (data.maxAllowedPerWallet > 0 && ((userBalance + requestedQuantity) > data.maxAllowedPerWallet))
            revert ExceedsMaxPerWallet();

        _mint(edition, mintId, msg.sender, requestedQuantity, requestedQuantity * data.price);
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
        if (!(startTime < closingTime && closingTime < endTime)) revert InvalidTimeRange();

        _setTimeRange(edition, mintId, startTime, endTime);

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.closingTime = closingTime;

        emit ClosingTimeSet(edition, mintId, closingTime);
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
