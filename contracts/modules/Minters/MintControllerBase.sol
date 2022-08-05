// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "../../SoundEdition/ISoundEditionV1.sol";

/// @title Mint Controller Base
/// @dev The `MintControllerBase` class maintains a central storage record of mint controllers.
abstract contract MintControllerBase {
    // ================================
    // CUSTOM ERRORS
    // ================================

    /// @notice The caller must be the the controller of this edition to perform this action.
    error MintControllerUnauthorized();

    /// @notice There is no controller assigned to this edition.
    error MintControllerNotFound();

    /// @notice A mint controller is already assigned to this edition.
    error MintControllerAlreadyExists(address controller);

    /// @notice The `paid` Ether value must be equal to the `required` Ether value.
    error WrongEtherValue(uint256 paid, uint256 required);

    /// @notice The total minted cannot exceed `maxMintable`.
    error SoldOut(uint32 maxMintable);

    /// @notice The current block timestamp must be between `startTime` and `endTime`, inclusive.
    error MintNotOpen(uint256 blockTimestamp, uint32 startTime, uint32 endTime);

    /// @notice The mint is paused.
    error MintPaused();

    /// @notice The caller must be the owner of the edition contract.
    error CallerNotEditionOwner();

    // ================================
    // EVENTS
    // ================================

    /// @notice Emitted when the mint `controller` for `edition` renounces their own access.
    event MintControllerAccessRenounced(address indexed edition, address indexed controller);

    /// @notice Emitted when the mint `controller` for `edition` is updated.
    event MintControllerSet(address indexed edition, address indexed controller);

    /// @notice Emitted when the `paused` status of `edition` is updated.
    event MintPausedSet(address indexed edition, bool paused);

    // ================================
    // STRUCTS
    // ================================

    struct BaseData {
        address controller;
        bool controllerAccess;
        bool mintPaused;
    }

    // ================================
    // STORAGE
    // ================================

    /// @dev Maps an edition to a controller.
    mapping(address => BaseData) private _baseData;

    // ================================
    // MINT CONTROLLER FUNCTIONS
    // ================================

    /// @dev Restricts the function to be only callable by the controller of `edition`.
    modifier onlyEditionMintController(address edition) virtual {
        BaseData storage data = _baseData[edition];

        if (data.controller == address(0)) revert MintControllerNotFound();
        if (msg.sender != data.controller) revert MintControllerUnauthorized();
        if (!data.controllerAccess) revert MintControllerUnauthorized();

        _;
    }

    /// @dev Assigns the current caller as the controller to `edition`.
    /// Calling conditions:
    /// - The `edition` must not have a controller.
    function _createEditionMintController(address edition) internal {
        if (!_callerIsEditionOwner(edition)) revert CallerNotEditionOwner();

        BaseData storage data = _baseData[edition];
        if (data.controller != address(0)) revert MintControllerAlreadyExists(data.controller);
        data.controller = msg.sender;
        data.controllerAccess = true;

        emit MintControllerSet(edition, msg.sender);
    }

    /// @dev Returns whether the caller is the owner of `edition`.
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

    /// @dev Convenience function for deleting a mint controller.
    /// Equivalent to `setEditionMintController(edition, address(0))`.
    function _deleteEditionMintController(address edition) internal {
        setEditionMintController(edition, address(0));
    }

    /// @dev Returns if the mint controller for `edition` has access.
    function editionMintControllerHasAccess(address edition) public view returns (bool) {
        return _baseData[edition].controllerAccess;
    }

    /// @dev Returns the mint controller for `edition`.
    function editionMintController(address edition) public view returns (address) {
        return _baseData[edition].controller;
    }

    /// @dev Sets the new `controller` for `edition`.
    /// Calling conditions:
    /// - The caller must be the current controller for `edition`.
    function setEditionMintController(address edition, address controller)
        public
        virtual
        onlyEditionMintController(edition)
    {
        _baseData[edition].controller = controller;
        emit MintControllerSet(edition, controller);
    }

    /// @dev Sets the new `controller` for `edition`.
    /// Calling conditions:
    /// - The caller must be the current controller for `edition`.
    function renounceEditionMintControllerAccess(address edition) public virtual onlyEditionMintController(edition) {
        BaseData storage data = _baseData[edition];

        data.controllerAccess = false;
        emit MintControllerAccessRenounced(edition, data.controller);
    }

    /// @dev Sets the `paused` status for `edition`.
    /// Calling conditions:
    /// - The caller must be the current controller for `edition`.
    function setEditionMintPaused(address edition, bool paused) public virtual onlyEditionMintController(edition) {
        _baseData[edition].mintPaused = paused;
        emit MintPausedSet(edition, paused);
    }

    // ================================
    // INTERNAL HELPER FUNCTIONS
    // ================================

    /// @dev Mints `quantity` of `edition` to `to` with a required payment of `requiredEtherValue`.
    function _mint(
        address edition,
        address to,
        uint32 quantity,
        uint256 requiredEtherValue
    ) internal {
        if (msg.value != requiredEtherValue) revert WrongEtherValue(msg.value, requiredEtherValue);
        if (_baseData[edition].mintPaused) revert MintPaused();
        ISoundEditionV1(edition).mint{ value: msg.value }(to, quantity);
    }

    /// @dev Requires that `startTime <= block.timestamp <= endTime`.
    function _requireMintOpen(uint32 startTime, uint32 endTime) internal view {
        if (block.timestamp < startTime) revert MintNotOpen(block.timestamp, startTime, endTime);
        if (block.timestamp > endTime) revert MintNotOpen(block.timestamp, startTime, endTime);
    }

    /// @dev Requires that `totalMinted <= maxMintable`.
    function _requireNotSoldOut(uint32 totalMinted, uint32 maxMintable) internal pure {
        if (totalMinted > maxMintable) revert SoldOut(maxMintable);
    }
}
