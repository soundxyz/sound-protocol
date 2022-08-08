// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "../../SoundEdition/ISoundEditionV1.sol";

/**
 * @title Mint Controller Base
 * @dev The `MintControllerBase` class maintains a central storage record of mint controllers.
 */
abstract contract MintControllerBase {
    // ================================
    // CUSTOM ERRORS
    // ================================

    /**
     * The caller must be the the controller of this edition to perform this action.
     */
    error MintControllerUnauthorized();

    /**
     * There is no controller assigned to this edition.
     */
    error MintControllerNotFound();

    /**
     * A mint controller is already assigned to this edition.
     */
    error MintControllerAlreadyExists(address controller);

    /**
     * The `paid` Ether value must be equal to the `required` Ether value.
     */
    error WrongEtherValue(uint256 paid, uint256 required);

    /**
     * The total minted cannot exceed `maxMintable`.
     */
    error SoldOut(uint32 maxMintable);

    /**
     * The current block timestamp must be between `startTime` and `endTime`, inclusive.
     */
    error MintNotOpen(uint256 blockTimestamp, uint32 startTime, uint32 endTime);

    /**
     * The mint is paused.
     */
    error MintPaused();

    /**
     * The caller must be the owner of the edition contract.
     */
    error CallerNotEditionOwner();

    // ================================
    // EVENTS
    // ================================

    /**
     * @notice Emitted when the mint `controller` for `edition` renounces their own access.
     */
    event MintControllerAccessRenounced(address indexed edition, uint256 indexed mintId, address indexed controller);

    /**
     * @notice Emitted when the mint `controller` for `edition` is updated.
     */
    event MintControllerSet(address indexed edition, uint256 indexed mintId, address indexed controller);

    /**
     * @notice Emitted when the `paused` status of `edition` is updated.
     */
    event MintPausedSet(address indexed edition, uint256 indexed mintId, bool indexed paused);

    // ================================
    // STRUCTS
    // ================================

    struct BaseData {
        address controller;
        bool mintPaused;
    }

    // ================================
    // STORAGE
    // ================================

    /**
     * @dev Maps an edition to the it's next mint ID.
     */
    mapping(address => uint256) private _nextMintIds;

    /**
     * @dev Maps an edition and the mint ID to a controller.
     */
    mapping(address => mapping(uint256 => BaseData)) private _baseData;

    // ================================
    // MINT CONTROLLER FUNCTIONS
    // ================================

    /**
     * @dev Restricts the function to be only callable by the controller of `edition`.
     */
    modifier onlyEditionMintController(address edition, uint256 mintId) virtual {
        BaseData storage data = _baseData[edition][mintId];

        if (data.controller == address(0)) revert MintControllerNotFound();
        if (msg.sender != data.controller) revert MintControllerUnauthorized();

        _;
    }

    /**
     * @dev Assigns the current caller as the controller to `edition`.
     * Calling conditions:
     * - The `edition` must not have a controller.
     */
    function _createEditionMintController(address edition) internal returns (uint256 mintId) {
        if (!_callerIsEditionOwner(edition)) revert CallerNotEditionOwner();

        mintId = _nextMintIds[edition];

        BaseData storage data = _baseData[edition][mintId];
        if (data.controller != address(0)) revert MintControllerAlreadyExists(data.controller);
        data.controller = msg.sender;

        _nextMintIds[edition] += 1;

        emit MintControllerSet(edition, mintId, msg.sender);
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
     * @dev Convenience function for deleting a mint controller.
     * Equivalent to `setEditionMintController(edition, address(0))`.
     */
    function _deleteEditionMintController(address edition, uint256 mintId) internal {
        setEditionMintController(edition, mintId, address(0));
    }

    /**
     * @dev Returns the mint controller for `edition`.
     */
    function editionMintController(address edition, uint256 mintId) public view returns (address) {
        return _baseData[edition][mintId].controller;
    }

    /**
     * @dev Sets the new `controller` for `edition`.
     * Calling conditions:
     * - The caller must be the current controller for `edition`.
     */
    function setEditionMintController(
        address edition,
        uint256 mintId,
        address controller
    ) public virtual onlyEditionMintController(edition, mintId) {
        _baseData[edition][mintId].controller = controller;
        emit MintControllerSet(edition, mintId, controller);
    }

    /**
     * @dev Sets the `paused` status for `edition`.
     * Calling conditions:
     * - The caller must be the current controller for `edition`.
     */
    function setEditionMintPaused(
        address edition,
        uint256 mintId,
        bool paused
    ) public virtual onlyEditionMintController(edition, mintId) {
        _baseData[edition][mintId].mintPaused = paused;
        emit MintPausedSet(edition, mintId, paused);
    }

    /**
     * @dev Returns the next mint ID for `edition`.
     */
    function nextMintId(address edition) public view returns (uint256) {
        return _nextMintIds[edition];
    }

    // ================================
    // INTERNAL HELPER FUNCTIONS
    // ================================

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
        if (msg.value != requiredEtherValue) revert WrongEtherValue(msg.value, requiredEtherValue);
        if (_baseData[edition][mintId].mintPaused) revert MintPaused();
        ISoundEditionV1(edition).mint{ value: msg.value }(to, quantity);
    }

    /**
     * @dev Requires that `startTime <= block.timestamp <= endTime`.
     */
    function _requireMintOpen(uint32 startTime, uint32 endTime) internal view {
        if (block.timestamp < startTime) revert MintNotOpen(block.timestamp, startTime, endTime);
        if (block.timestamp > endTime) revert MintNotOpen(block.timestamp, startTime, endTime);
    }

    /**
     * @dev Requires that `totalMinted <= maxMintable`.
     */
    function _requireNotSoldOut(uint32 totalMinted, uint32 maxMintable) internal pure {
        if (totalMinted > maxMintable) revert SoldOut(maxMintable);
    }
}
