// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

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

    /// @notice The mint is paused.
    error MintPaused();

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
        BaseData storage data = _baseData[edition];
        
        if (data.controller != address(0)) revert MintControllerAlreadyExists(data.controller);
        data.controller = msg.sender;
        data.controllerAccess = true;
        
        emit MintControllerSet(edition, msg.sender);
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
    function renounceEditionMintControllerAccess(address edition)
        public
        virtual
        onlyEditionMintController(edition)
    {
        BaseData storage data = _baseData[edition];

        data.controllerAccess = false;
        emit MintControllerAccessRenounced(edition, data.controller);
    }

    function setEditionMintPaused(address edition, bool paused)
        public
        virtual
        onlyEditionMintController(edition)
    {
        _baseData[edition].mintPaused = paused;
        emit MintPausedSet(edition, paused);
    }

    // ================================
    // HELPER REQUIRE FUNCTIONS
    // ================================

    function _requireExactPayment(uint256 requiredEtherValue) internal view {
        if (msg.value != requiredEtherValue) revert WrongEtherValue(msg.value, requiredEtherValue);
    }

    function _requireMintNotPaused(address edition) internal {
        if (_baseData[edition].mintPaused) revert MintPaused();
    }
}
