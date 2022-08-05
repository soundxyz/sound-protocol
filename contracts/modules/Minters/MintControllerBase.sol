// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

/// @title Mint Controller Base
/// @dev The `MintControllerBase` class maintains a central storage record of mint controllers.
abstract contract MintControllerBase {
    struct ControllerData {
        address addr;
        bool access;
    }

    /// @dev The caller must be the the controller of this edition to perform this action.
    error MintControllerUnauthorized();

    /// @dev There is no controller assigned to this edition.
    error MintControllerNotFound();

    /// @dev A mint controller is already assigned to this edition.
    error MintControllerAlreadyExists(address controller);

    /// @dev Emitted when the mint `controller` for `edition` renounces their own access.
    event MintControllerAccessRenounced(address indexed edition, address indexed controller);

    /// @dev Emitted when the mint `controller` for `edition` is changed.
    event MintControllerUpdated(address indexed edition, address indexed controller);

    /// @dev Maps an edition to a controller.
    mapping(address => ControllerData) private _controllerData;

    /// @dev Restricts the function to be only callable by the controller of `edition`.
    modifier onlyEditionMintController(address edition) virtual {
        ControllerData memory controllerData = _controllerData[edition];
        address controller = controllerData.addr;
        
        if (controllerData.addr == address(0)) revert MintControllerNotFound();
        if (msg.sender != controllerData.addr) revert MintControllerUnauthorized();
        if (!controllerData.access) revert MintControllerUnauthorized();
        
        _;
    }

    /// @dev Assigns the current caller as the controller to `edition`.
    /// Calling conditions:
    /// - The `edition` must not have a controller.
    function _createEditionMintController(address edition) internal {
        ControllerData memory controllerData = _controllerData[edition];
        address controller = controllerData.addr;
        
        if (controller != address(0)) revert MintControllerAlreadyExists(controller);
        _controllerData[edition].addr = msg.sender;
        _controllerData[edition].access = true;
        
        emit MintControllerUpdated(edition, msg.sender);
    }

    /// @dev Convenience function for deleting a mint controller.
    /// Equivalent to `setEditionMintController(edition, address(0))`.
    function _deleteEditionMintController(address edition) internal {
        setEditionMintController(edition, address(0));
    }

    /// @dev Returns if the mint controller for `edition` has access.
    function editionMintControllerHasAccess(address edition) public view returns (bool) {
        return _controllerData[edition].access;
    }

    /// @dev Returns the mint controller for `edition`.
    function editionMintController(address edition) public view returns (address) {
        return _controllerData[edition].addr;
    }

    /// @dev Sets the new `controller` for `edition`.
    /// Calling conditions:
    /// - The caller must be the current controller for `edition`.
    function setEditionMintController(address edition, address controller)
        public
        virtual
        onlyEditionMintController(edition)
    {
        _controllerData[edition].addr = controller;
        emit MintControllerUpdated(edition, controller);
    }

    /// @dev Sets the new `controller` for `edition`.
    /// Calling conditions:
    /// - The caller must be the current controller for `edition`.
    function renounceEditionMintControllerAccess(address edition)
        public
        virtual
        onlyEditionMintController(edition)
    {
        _controllerData[edition].access = false;
        emit MintControllerAccessRenounced(edition, _controllerData[edition].addr);
    }
}
