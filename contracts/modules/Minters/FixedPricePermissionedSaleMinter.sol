// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

import "./MintControllerBase.sol";
import "../../SoundEdition/ISoundEditionV1.sol";
import "solady/utils/ECDSA.sol";

/// @title Fixed Price Permissioned Sale Minter
/// @dev Minter class for sales approved with signatures.
contract FixedPricePermissionedSaleMinter is MintControllerBase {
    using ECDSA for bytes32;

    // ERRORS
    error InvalidSignature();

    error SignerIsZeroAddress();

    // prettier-ignore
    event FixedPricePermissionedMintCreated(
        address indexed edition,
        uint256 price,
        address signer,
        uint32 maxMintable
    );

    struct EditionMintData {
        // The price at which each token will be sold, in ETH.
        uint256 price;
        // Whitelist signer address.
        address signer;
        // The maximum number of tokens that can can be minted for this sale.
        uint32 maxMintable;
        // The total number of tokens minted so far for this sale.
        uint32 totalMinted;
    }

    mapping(address => EditionMintData) internal _editionMintData;

    /// @dev Initializes the configuration for an edition mint.
    function createEditionMint(
        address edition,
        uint256 price,
        address signer,
        uint32 maxMintable
    ) public {
        _createEditionMintController(edition);
        if (signer == address(0)) revert SignerIsZeroAddress();

        EditionMintData storage data = _editionMintData[edition];
        data.price = price;
        data.signer = signer;
        data.maxMintable = maxMintable;
        // prettier-ignore
        emit FixedPricePermissionedMintCreated(
            edition,
            price,
            signer,
            maxMintable
        );
    }

    function editionMintData(address edition) public view returns (EditionMintData memory) {
        return _editionMintData[edition];
    }

    /// @dev Deletes the configuration for an edition mint.
    function deleteEditionMint(address edition) public {
        _deleteEditionMintController(edition);
        delete _editionMintData[edition];
    }

    /// @dev Mints tokens for a given edition.
    function mint(
        address edition,
        uint32 quantity,
        bytes calldata signature
    ) public payable {
        EditionMintData storage data = _editionMintData[edition];
        _requireNotSoldOut(data.totalMinted += quantity, data.maxMintable);

        bytes32 hash = keccak256(abi.encode(msg.sender, edition));
        hash = hash.toEthSignedMessageHash();
        if (hash.recover(signature) != data.signer) revert InvalidSignature();

        _mint(edition, msg.sender, quantity, data.price * quantity);
    }
}
