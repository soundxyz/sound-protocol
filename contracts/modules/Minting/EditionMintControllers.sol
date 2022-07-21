// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

contract EditionMintControllers {

    event EditionMintControllerUpdated(address indexed edition, address indexed newController);

    mapping(address => address) private _controllers;

    modifier onlyEditionMintController(address edition) virtual {
        require(msg.sender == _controllers[edition], "Unauthorized.");
        _;
    }

    function _initEditionMintController(address edition) internal {
        _initEditionMintController(edition, msg.sender);
    }

    function _initEditionMintController(address edition, address editionMintController) internal {
        require(editionMintController != address(0), "Edition mint controller cannot be the zero address.");
        require(_controllers[edition] == address(0), "Edition mint controller already exists.");

        _controllers[edition] = editionMintController;

        emit EditionMintControllerUpdated(edition, editionMintController);
    }

    function _deleteEditionMintController(address edition) internal {
        require(_controllers[edition] != address(0), "Edition mint controller does not exist.");

        delete _controllers[edition];

        emit EditionMintControllerUpdated(edition, address(0));   
    }

    function _deleteEditionMintController() internal {
        _deleteEditionMintController(msg.sender);
    }

    function _editionMintController(address edition) internal view returns (address) {
        return _controllers[edition];
    }

    function setEditionMintController(
        address edition,
        address newController
    ) public virtual onlyEditionMintController(edition) {
        require(newController != address(0), "");

        _controllers[edition] = newController;
        emit EditionMintControllerUpdated(edition, newController);
    }
}
