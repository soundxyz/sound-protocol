// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { ECDSA } from "solady/utils/ECDSA.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { BaseMinter } from "@modules/BaseMinter.sol";
import { IFixedPriceSignatureMinter, EditionMintData, MintInfo } from "./interfaces/IFixedPriceSignatureMinter.sol";

/**
 * @title Fixed Price Permissioned Sale Minter
 * @dev Minter class for sales approved with signatures.
 */
contract FixedPriceSignatureMinter is IFixedPriceSignatureMinter, BaseMinter {
    using ECDSA for bytes32;

    mapping(address => mapping(uint256 => EditionMintData)) internal _editionMintData;

    // ================================
    // WRITE FUNCTIONS
    // ================================

    /**
     * @dev Initializes the configuration for an edition mint.
     */
    function createEditionMint(
        address edition,
        uint256 price_,
        address signer,
        uint32 maxMintable_,
        uint32 startTime,
        uint32 endTime
    ) public returns (uint256 mintId) {
        mintId = _createEditionMint(edition, startTime, endTime);
        if (signer == address(0)) revert SignerIsZeroAddress();

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.price = price_;
        data.signer = signer;
        data.maxMintable = maxMintable_;
        // prettier-ignore
        emit FixedPriceSignatureMintCreated(
            edition,
            mintId,
            price_,
            signer,
            maxMintable_
        );
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

    // ================================
    // VIEW FUNCTIONS
    // ================================

    /**
     * @dev Returns the given edition's mint configuration.
     * @param edition The edition to get the mint configuration for.
     */
    function editionMintData(address edition, uint256 mintId) public view returns (EditionMintData memory) {
        return _editionMintData[edition][mintId];
    }

    function mintInfo(address edition, uint256 mintId) public view returns (MintInfo memory) {
        BaseData memory baseData = super.baseMintData(edition, mintId);
        EditionMintData storage mintData = _editionMintData[edition][mintId];

        MintInfo memory combinedMintData = MintInfo(
            baseData.startTime,
            baseData.endTime,
            baseData.mintPaused,
            mintData.price,
            mintData.maxMintable,
            type(uint32).max, // maxMintablePerAccount
            mintData.totalMinted,
            mintData.signer
        );

        return combinedMintData;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view override(BaseMinter) returns (bool) {
        return BaseMinter.supportsInterface(interfaceId) || interfaceId == type(IFixedPriceSignatureMinter).interfaceId;
    }
}
