// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "../../interfaces/IBaseMinter.sol";
import "../../interfaces/ISoundEditionV1.sol";
import "openzeppelin-upgradeable/access/IAccessControlUpgradeable.sol";
import "openzeppelin/utils/introspection/IERC165.sol";

/**
 * @title Minter Base
 * @dev The `MinterBase` class maintains a central storage record of edition mint configurations.
 */
abstract contract MinterBase is IERC165, IBaseMinter {
    // ================================
    // CUSTOM ERRORS
    // ================================

    /**
     * The Ether value paid is not the exact value required.
     */
    error WrongEtherValue(uint256 paid, uint256 required);

    /**
     * The number minted has exceeded the max mintable amount.
     */
    error MaxMintableReached(uint32 maxMintable);

    /**
     * The mint is not opened.
     */
    error MintNotOpen(uint256 blockTimestamp, uint32 startTime, uint32 endTime);

    /**
     * The mint is paused.
     */
    error MintPaused();

    /**
     * The `startTime` is not less than the `endTime`.
     */
    error InvalidTimeRange();

    /**
     * Unauthorized caller
     */
    error Unauthorized();

    // ================================
    // EVENTS
    // ================================

    /**
     * @notice Emitted when the mint configuration for an `edition` is created.
     */
    event MintConfigCreated(
        address indexed edition,
        address indexed creator,
        uint256 mintId,
        uint32 startTime,
        uint32 endTime
    );

    /**
     * @notice Emitted when the `paused` status of `edition` is updated.
     */
    event MintPausedSet(address indexed edition, uint256 mintId, bool paused);

    /**
     * @notice Emitted when the `startTime` and `endTime` are updated.
     */
    event TimeRangeSet(address indexed edition, uint256 indexed mintId, uint32 startTime, uint32 endTime);

    // ================================
    // STRUCTS
    // ================================

    struct BaseData {
        uint32 startTime;
        uint32 endTime;
        bool mintPaused;
    }

    // ================================
    // STORAGE
    // ================================

    /**
     * @dev Maps an edition to the its next mint ID.
     */
    mapping(address => uint256) private _nextMintIds;

    /**
     * @dev Maps an edition and the mint ID to a mint's configuration.
     */
    mapping(address => mapping(uint256 => BaseData)) private _baseData;

    // ================================
    // WRITE FUNCTIONS
    // ================================

    /**
     * @dev Sets the `paused` status for `edition`.
     * Calling conditions:
     * - The caller must be the edition's owner or an admin.
     */
    function setEditionMintPaused(
        address edition,
        uint256 mintId,
        bool paused
    ) public virtual onlyEditionOwnerOrAdmin(edition) {
        _baseData[edition][mintId].mintPaused = paused;
        emit MintPausedSet(edition, mintId, paused);
    }

    /**
     * @dev Sets the time range for an edition mint.
     * Calling conditions:
     * - The caller must be the edition's owner or an admin.
     */
    function setTimeRange(
        address edition,
        uint256 mintId,
        uint32 startTime,
        uint32 endTime
    ) public virtual onlyEditionOwnerOrAdmin(edition) {
        _setTimeRange(edition, mintId, startTime, endTime);
    }

    // ================================
    // INTERNAL FUNCTIONS
    // ================================

    /**
     * @dev Restricts the start time to be less than the end time.
     */
    modifier onlyValidTimeRange(uint32 startTime, uint32 endTime) virtual {
        if (startTime >= endTime) revert InvalidTimeRange();
        _;
    }

    /**
     * @dev Creates an edition mint configuration.
     * Calling conditions:
     * - Must be owner or admin of the edition.
     */
    function _createEditionMint(
        address edition,
        uint32 startTime,
        uint32 endTime
    ) internal onlyValidTimeRange(startTime, endTime) onlyEditionOwnerOrAdmin(edition) returns (uint256 mintId) {
        mintId = _nextMintIds[edition];

        BaseData storage data = _baseData[edition][mintId];
        data.startTime = startTime;
        data.endTime = endTime;

        _nextMintIds[edition] += 1;

        emit MintConfigCreated(edition, msg.sender, mintId, startTime, endTime);
    }

    /**
     * @dev Returns whether the caller is the owner of `edition`.
     */
    function _callerIsEditionOwner(address edition) private returns (bool result) {
        // To avoid defining an interface just to call `owner()`.
        // And Solidity does not have try catch for plain old `call`.
        assembly {
            // Store the 4-byte function selector of `owner()` into scratch space.
            mstore(0x00, 0x8da5cb5b)
            // The `call` must be placed as the last argument of `and`,
            // as the arguments are evaluated right to left.
            result := and(
                and(
                    // Whether the returned address equals `msg.sender`.
                    eq(mload(0x00), caller()),
                    // Whether at least a word has been returned.
                    gt(returndatasize(), 31)
                ),
                call(
                    gas(), // Remaining gas.
                    edition, // The `edition` address.
                    0, // Send 0 Ether.
                    0x1c, // Offset of the selector in the memory.
                    0x04, // Size of the selector (4 bytes).
                    0x00, // Offset of the return data.
                    0x20 // Size of the return data (1 32-byte word).
                )
            )
        }
    }

    /**
     * @dev Sets the time range for an edition mint.
     * Note: If calling from a child contract, the child is responsible for access control.
     */
    function _setTimeRange(
        address edition,
        uint256 mintId,
        uint32 startTime,
        uint32 endTime
    ) internal onlyValidTimeRange(startTime, endTime) {
        _beforeSetTimeRange(edition, mintId, startTime, endTime);

        _baseData[edition][mintId].startTime = startTime;
        _baseData[edition][mintId].endTime = endTime;
    }

    /**
     * @dev Called at the start of _setTimeRange (for optional validation checks, etc).
     */
    function _beforeSetTimeRange(
        address edition,
        uint256 mintId,
        uint32 startTime,
        uint32 endTime
    ) internal virtual {}

    /**
     * @dev Mints `quantity` of `edition` to `to` with a required payment of `requiredEtherValue`.
     */
    function _mint(
        address edition,
        uint256 mintId,
        address to,
        uint32 quantity,
        uint256 requiredEtherValue
    ) internal {
        uint32 startTime = _baseData[edition][mintId].startTime;
        uint32 endTime = _baseData[edition][mintId].endTime;
        if (block.timestamp < startTime) revert MintNotOpen(block.timestamp, startTime, endTime);
        if (block.timestamp > endTime) revert MintNotOpen(block.timestamp, startTime, endTime);

        if (msg.value != requiredEtherValue) revert WrongEtherValue(msg.value, requiredEtherValue);
        if (_baseData[edition][mintId].mintPaused) revert MintPaused();
        ISoundEditionV1(edition).mint{ value: msg.value }(to, quantity);
    }

    /**
     * @dev Requires that `totalMinted <= maxMintable`.
     */
    function _requireNotSoldOut(uint32 totalMinted, uint32 maxMintable) internal pure {
        if (totalMinted > maxMintable) revert MaxMintableReached(maxMintable);
    }

    // ================================
    // MODIFIERS
    // ================================

    /**
     * @dev Restricts the function to be only callable by the owner or admin of `edition`.
     */
    modifier onlyEditionOwnerOrAdmin(address edition) virtual {
        if (
            !_callerIsEditionOwner(edition) &&
            !IAccessControlUpgradeable(edition).hasRole(ISoundEditionV1(edition).ADMIN_ROLE(), msg.sender)
        ) revert Unauthorized();

        _;
    }

    // ================================
    // VIEW FUNCTIONS
    // ================================

    /**
     * @dev Returns the next mint ID for `edition`.
     */
    function nextMintId(address edition) public view returns (uint256) {
        return _nextMintIds[edition];
    }

    /**
     * @dev Returns the configuration data for an edition mint.
     */
    function baseMintData(address edition, uint256 mintId) public view returns (BaseData memory) {
        return _baseData[edition][mintId];
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IBaseMinter).interfaceId;
    }
}
