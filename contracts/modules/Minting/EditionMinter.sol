// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

contract EditionMinter {
    error MintControllerUnauthorized();

    error MintControllerSetToZeroAddress();

    error MintNotFound();

    error MintAlreadyExists();

    event MintControllerUpdated(address indexed edition, address indexed controller);

    mapping(address => address) private _controllers;

    modifier onlyEditionMintController(address edition) virtual {
        address controller = _controllers[edition];
        if (controller == address(0)) revert MintNotFound();
        if (msg.sender != controller) revert MintControllerUnauthorized();
        _;
    }

    function _createEditionMint(address edition) internal {
        _createEditionMint(edition, msg.sender);
    }

    function _createEditionMint(address edition, address controller) internal {
        if (controller == address(0)) revert MintControllerSetToZeroAddress();
        if (_controllers[edition] != address(0)) revert MintAlreadyExists();

        _controllers[edition] = controller;

        emit MintControllerUpdated(edition, controller);
    }

    function _deleteEditionMint(address edition) internal {
        address controller = _controllers[edition];
        if (controller == address(0)) revert MintNotFound();
        if (msg.sender != controller) revert MintControllerUnauthorized();
        delete _controllers[edition];
        emit MintControllerUpdated(edition, address(0));
    }

    function editionMintController(address edition) public view returns (address) {
        return _controllers[edition];
    }

    function setEditionMintController(address edition, address controller)
        public
        virtual
        onlyEditionMintController(edition)
    {
        if (controller == address(0)) revert MintControllerSetToZeroAddress();

        _controllers[edition] = controller;
        emit MintControllerUpdated(edition, controller);
    }
}
