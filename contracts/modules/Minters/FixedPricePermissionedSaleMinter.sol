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
    error SoldOut();
    error InvalidSignature();

    // prettier-ignore
    event FixedPricePermissionedMintCreated(
        address indexed edition,
        uint256 price,
        address signer,
        uint32 maxMinted
    );

    struct EditionMintData {
        // The price at which each token will be sold, in ETH.
        uint256 price;
        // Whitelist signer address.
        address signer;
        // The maximum number of tokens that can can be minted for this sale.
        uint32 maxMinted;
        // The total number of tokens minted so far for this sale.
        uint32 totalMinted;
    }

    mapping(address => EditionMintData) public editionMintData;

    /// @dev Initializes the configuration for an edition mint.
    function createEditionMint(
        address edition,
        uint256 price,
        address signer,
        uint32 maxMinted
    ) public {
        _createEditionMintController(edition);
        EditionMintData storage data = editionMintData[edition];
        data.price = price;
        data.signer = signer;
        data.maxMinted = maxMinted;
        // prettier-ignore
        emit FixedPricePermissionedMintCreated(
            edition,
            price,
            signer,
            maxMinted
        );
    }

    /// @dev Deletes the configuration for an edition mint.
    function deleteEditionMint(address edition) public {
        _deleteEditionMintController(edition);
        delete editionMintData[edition];
    }

    /// @dev Mints tokens for a given edition.
    function mint(
        address edition,
        uint32 quantity,
        bytes calldata signature
    ) public payable {
        EditionMintData storage data = editionMintData[edition];
        if ((data.totalMinted += quantity) > data.maxMinted) revert SoldOut();
        _requireExactPayment(data.price * quantity);

        bytes32 hash = keccak256(abi.encode(msg.sender, edition));
        hash = hash.toEthSignedMessageHash();
        if (hash.recover(signature) != data.signer) revert InvalidSignature();

        ISoundEditionV1(edition).mint{ value: msg.value }(edition, quantity);
    }
}
