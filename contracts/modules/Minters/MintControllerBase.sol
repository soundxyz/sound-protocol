// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

// TODO: figure out how to adapt ISoundEdition and import that instead
import "../../SoundEdition/SoundEditionV1.sol";

/**
 * @title Mint Controller Base
 * @dev The `MintControllerBase` class maintains a central storage record of mint controllers.
 */
abstract contract MintControllerBase {
    /// @dev The caller must be the the controller of this edition to perform this action.
    error MintControllerUnauthorized();

    /// @dev There is no controller assigned to this edition.
    error MintControllerNotFound();

    /// @dev A mint controller is already assigned to this edition.
    error MintControllerAlreadyExists(address controller);

    /// @dev The caller must be the owner of the edition contract.
    error CallerNotEditionOwner();

    /// @dev Unauthorized caller
    error Unauthorized();

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

    /**
     * @dev Assigns the current caller as the controller to `edition`.
     * Calling conditions:
     * - The `edition` must not have a controller.
     */
    function _createEditionMintController(address edition) internal {
        if (!_callerIsEditionOwner(edition)) revert CallerNotEditionOwner();
        if (_controllers[edition] != address(0)) revert MintControllerAlreadyExists(_controllers[edition]);
        _controllers[edition] = msg.sender;
        emit MintControllerUpdated(edition, msg.sender);
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
    function _deleteEditionMintController(address edition) internal {
        setEditionMintController(edition, address(0));
    }

    /**
     * @dev Returns the mint controller for `edition`.
     */
    function editionMintController(address edition) public view returns (address) {
        return _controllers[edition];
    }

    /**
     * @dev Sets the new `controller` for `edition`.
     * Calling conditions:
     * - The caller must be the current controller for `edition`.
     */
    function setEditionMintController(address edition, address controller)
        public
        virtual
        onlyEditionMintController(edition)
    {
        _controllers[edition] = controller;
        emit MintControllerUpdated(edition, controller);
    }

    /// @dev Enables owner or admins to mint to a given address for no cost.
    function adminMint(
        SoundEditionV1 edition,
        address recipient,
        uint256 quantity
    ) public {
        if (edition.owner() != msg.sender && !edition.hasRole(edition.ADMIN_ROLE(), msg.sender)) revert Unauthorized();

        ISoundEditionV1(edition).mint(recipient, quantity);
    }
}
