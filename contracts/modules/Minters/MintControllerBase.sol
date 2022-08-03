// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

/// @title Mint Controller Base
/// @dev The `MintControllerBase` class maintains a central storage record of mint controllers.
abstract contract MintControllerBase {
    /// @dev The caller must be the the controller of this edition to perform this action.
    error MintControllerUnauthorized();

    /// @dev There is no controller assigned to this edition.
    error MintControllerNotFound();

    /// @dev A mint controller is already assigned to this edition.
    error MintControllerAlreadyExists(address controller);

    /// @dev Emitted when the mint `controller` for `edition` is changed.
    event MintControllerUpdated(address indexed edition, address indexed controller);

    /// @dev Maps an edition to a controller.
    mapping(address => address) private _controllers;

    /// @dev Restricts the function to be only callable by the controller of `edition`.
    modifier onlyEditionMintController(address edition) virtual {
        address controller = _controllers[edition];
        if (controller == address(0)) revert MintControllerNotFound();
        if (msg.sender != controller) revert MintControllerUnauthorized();
        _;
    }

    /// @dev Assigns the current caller as the controller to `edition`.
    /// Calling conditions:
    /// - The `edition` must not have a controller.
    function _createEditionMintController(address edition) internal {
        if (_controllers[edition] != address(0)) revert MintControllerAlreadyExists(_controllers[edition]);
        _controllers[edition] = msg.sender;
        emit MintControllerUpdated(edition, msg.sender);
    }

    /// @dev Convenience function for deleting a mint controller.
    /// Equivalent to `setEditionMintController(edition, address(0))`.
    function _deleteEditionMintController(address edition) internal {
        setEditionMintController(edition, address(0));
    }

    /// @dev Returns the mint controller for `edition`.
    function editionMintController(address edition) public view returns (address) {
        return _controllers[edition];
    }

    /// @dev Sets the new `controller` for `edition`.
    /// Calling conditions:
    /// - The caller must be the current controller for `edition`.
    function setEditionMintController(address edition, address controller)
        public
        virtual
        onlyEditionMintController(edition)
    {
        _controllers[edition] = controller;
        emit MintControllerUpdated(edition, controller);
    }
}
