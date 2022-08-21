// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

import "../core/BaseMinter.sol";
import "./interfaces/IStandardMint.sol";
import "openzeppelin/utils/introspection/IERC165.sol";

/*
 * @dev Minter class for range edition sales.
 */
contract RangeEditionMinter is IERC165, BaseMinter, IStandardMint {
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

    /**
     * @dev Edition mint data
     * edition => mintId => EditionMintData
     */
    mapping(address => mapping(uint256 => EditionMintData)) internal _editionMintData;
    /**
     * @dev Number of tokens minted by each buyer address, used to mitigate buyers minting more than maxAllowedPerWallet.
     * This is a weak mitigation since buyers can still buy from multiple addresses, but creates more friction than balanceOf.
     * edition => mintId => buyer => mintedTallies
     */
    mapping(address => mapping(uint256 => mapping(address => uint256))) mintedTallies;

    // ================================
    // WRITE FUNCTIONS
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
        uint256 price_,
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime,
        uint32 maxMintableLower,
        uint32 maxMintableUpper,
        uint32 maxAllowedPerWallet_
    ) public returns (uint256 mintId) {
        if (!(startTime < closingTime && closingTime < endTime)) revert InvalidTimeRange();
        if (!(maxMintableLower < maxMintableUpper)) revert InvalidMaxMintableRange(maxMintableLower, maxMintableUpper);

        mintId = _createEditionMint(edition, startTime, endTime);

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.price = price_;
        data.closingTime = closingTime;
        data.maxMintableLower = maxMintableLower;
        data.maxMintableUpper = maxMintableUpper;
        data.maxAllowedPerWallet = maxAllowedPerWallet_;

        // prettier-ignore
        emit RangeEditionMintCreated(
            edition,
            mintId,
            price_,
            startTime,
            closingTime,
            endTime,
            maxMintableLower,
            maxMintableUpper,
            maxAllowedPerWallet_
        );
    }

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

        uint32 _maxMintable;
        if (block.timestamp < data.closingTime) {
            _maxMintable = data.maxMintableUpper;
        } else {
            _maxMintable = data.maxMintableLower;
        }
        // Increase `totalMinted` by `quantity`.
        // Require that the increased value does not exceed `maxMintable`.
        uint32 nextTotalMinted = data.totalMinted + quantity;
        _requireNotSoldOut(nextTotalMinted, _maxMintable);
        data.totalMinted = nextTotalMinted;

        uint256 userMintedBalance = mintedTallies[edition][mintId][msg.sender];
        // If the maximum allowed per wallet is set (i.e. is different to 0)
        // check the required additional quantity does not exceed the set maximum
        if ((userMintedBalance + quantity) > maxAllowedPerWallet(edition, mintId)) revert ExceedsMaxPerWallet();

        mintedTallies[edition][mintId][msg.sender] += quantity;

        _mint(edition, mintId, msg.sender, quantity, quantity * data.price);
    }

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
    ) public onlyEditionOwnerOrAdmin(edition) {
        // Set closingTime first, as its stored value gets validated later in the execution.
        EditionMintData storage data = _editionMintData[edition][mintId];
        data.closingTime = closingTime;

        // This calls _beforeSetTimeRange, which does the closingTime validation.
        _setTimeRange(edition, mintId, startTime, endTime);

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
    ) public onlyEditionOwnerOrAdmin(edition) {
        EditionMintData storage data = _editionMintData[edition][mintId];
        data.maxMintableLower = maxMintableLower;
        data.maxMintableUpper = maxMintableUpper;

        if (!(data.maxMintableLower < data.maxMintableUpper))
            revert InvalidMaxMintableRange(data.maxMintableLower, data.maxMintableUpper);

        emit MaxMintableRangeSet(edition, mintId, maxMintableLower, maxMintableUpper);
    }

    // ================================
    // INTERNAL FUNCTIONS
    // ================================

    /**
     * @dev Optional validation function that gets called by _setTimeRange()
     */
    function _beforeSetTimeRange(
        address edition,
        uint256 mintId,
        uint32 startTime,
        uint32 endTime
    ) internal view override {
        uint32 closingTime = _editionMintData[edition][mintId].closingTime;
        if (!(startTime < closingTime && closingTime < endTime)) revert InvalidTimeRange();
    }

    // ================================
    // EXTERNAL VIEW
    // ================================

    function price(address edition, uint256 mintId) public view returns (uint256) {
        return _editionMintData[edition][mintId].price;
    }

    function maxMintable(address edition, uint256 mintId) public view returns (uint32) {
        EditionMintData storage data = _editionMintData[edition][mintId];

        if (block.timestamp < data.closingTime) {
            return data.maxMintableUpper;
        } else {
            return data.maxMintableLower;
        }
    }

    function maxAllowedPerWallet(address edition, uint256 mintId) public view returns (uint32) {
        return
            _editionMintData[edition][mintId].maxAllowedPerWallet > 0
                ? _editionMintData[edition][mintId].maxAllowedPerWallet
                : type(uint32).max;
    }

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
    // VIEW FUNCTIONS
    // ================================

    /**
     * @dev Returns the `EditionMintData` for `edition.
     * @param edition Address of the song edition contract we are minting for.
     */
    function editionMintData(address edition, uint256 mintId) public view returns (EditionMintData memory) {
        return _editionMintData[edition][mintId];
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, BaseMinter) returns (bool) {
        return BaseMinter.supportsInterface(interfaceId) || interfaceId == type(IStandardMint).interfaceId;
    }
}
