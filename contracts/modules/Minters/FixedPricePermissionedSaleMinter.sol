// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

import "./MintControllerBase.sol";
import "solady/utils/ECDSA.sol";

/**
 * @title Fixed Price Permissioned Sale Minter
 * @dev Minter class for sales approved with signatures.
 */
contract FixedPricePermissionedSaleMinter is MintControllerBase {
    using ECDSA for bytes32;

    error InvalidSignature();
    error SignerIsZeroAddress();

    // prettier-ignore
    event FixedPricePermissionedMintCreated(
        address indexed edition,
        uint256 indexed mintId,
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

    mapping(address => mapping(uint256 => EditionMintData)) internal _editionMintData;

    /**
     * @dev Initializes the configuration for an edition mint.
     */
    function createEditionMint(
        address edition,
        uint256 price_,
        address signer,
        uint32 maxMintable_
    ) public returns (uint256 mintId) {
        mintId = _createEditionMintController(edition, 0, type(uint32).max);
        if (signer == address(0)) revert SignerIsZeroAddress();

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.price = price_;
        data.signer = signer;
        data.maxMintable = maxMintable_;
        // prettier-ignore
        emit FixedPricePermissionedMintCreated(
            edition,
            mintId,
            price_,
            signer,
            maxMintable_
        );
    }

    /**
     * @dev Returns the given edition's mint configuration.
     * @param edition The edition to get the mint configuration for.
     */
    function editionMintData(address edition, uint256 mintId) public view returns (EditionMintData memory) {
        return _editionMintData[edition][mintId];
    }

    /**
     * @dev Deletes the configuration for an edition mint.
     */
    function deleteEditionMint(address edition, uint256 mintId) public {
        _deleteEditionMintController(edition, mintId);
        delete _editionMintData[edition][mintId];
    }

    /**
     * @dev Mints tokens for a given edition.
     */
    function mint(
        address edition,
        uint256 mintId,
        uint32 quantity,
        bytes calldata signature
    ) public payable {
        EditionMintData storage data = _editionMintData[edition][mintId];
        uint32 nextTotalMinted = data.totalMinted + quantity;
        _requireNotSoldOut(nextTotalMinted, data.maxMintable);
        data.totalMinted = nextTotalMinted;

        bytes32 hash = keccak256(abi.encode(msg.sender, edition, mintId));
        hash = hash.toEthSignedMessageHash();
        if (hash.recover(signature) != data.signer) revert InvalidSignature();

        _mint(edition, mintId, msg.sender, quantity, data.price * quantity);
    }

    function price(address edition, uint256 mintId) external view returns (uint256) {
        return _editionMintData[edition][mintId].price;
    }

    function maxMintable(address edition, uint256 mintId) external view returns (uint32) {
        return _editionMintData[edition][mintId].maxMintable;
    }

    function maxAllowedPerWallet(address, uint256) external pure returns (uint32) {
        return type(uint32).max;
    }
}
