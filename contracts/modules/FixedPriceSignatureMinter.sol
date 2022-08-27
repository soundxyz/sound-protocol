// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { ECDSA } from "solady/utils/ECDSA.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { BaseMinter } from "@modules/BaseMinter.sol";
import { IFixedPriceSignatureMinter, EditionMintData, MintInfo } from "./interfaces/IFixedPriceSignatureMinter.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

/**
 * @title IFixedPriceSignatureMinter
 * @dev Module for fixed-price, signature-authorizd mints of Sound editions.
 * @author Sound.xyz
 */
contract FixedPriceSignatureMinter is IFixedPriceSignatureMinter, BaseMinter {
    using ECDSA for bytes32;

    mapping(address => mapping(uint256 => EditionMintData)) internal _editionMintData;

    // ================================
    // WRITE FUNCTIONS
    // ================================

    constructor(ISoundFeeRegistry feeRegistry_) BaseMinter(feeRegistry_) {}

    /// @inheritdoc IFixedPriceSignatureMinter
    function createEditionMint(
        address edition,
        uint96 price,
        address signer,
        uint32 maxMintable_,
        uint32 startTime,
        uint32 endTime
    ) public returns (uint256 mintId) {
        mintId = _createEditionMint(edition, startTime, endTime);
        if (signer == address(0)) revert SignerIsZeroAddress();

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.price = price;
        data.signer = signer;
        data.maxMintable = maxMintable_;
        // prettier-ignore
        emit FixedPriceSignatureMintCreated(
            edition,
            mintId,
            price,
            signer,
            maxMintable_
        );
    }

    /// @inheritdoc IFixedPriceSignatureMinter
    function mint(
        address edition,
        uint256 mintId,
        uint32 quantity,
        bytes calldata signature,
        address affiliate
    ) public payable {
        EditionMintData storage data = _editionMintData[edition][mintId];
        uint32 nextTotalMinted = data.totalMinted + quantity;
        _requireNotSoldOut(nextTotalMinted, data.maxMintable);
        data.totalMinted = nextTotalMinted;

        bytes32 hash = keccak256(abi.encode(msg.sender, edition, mintId));
        hash = hash.toEthSignedMessageHash();
        if (hash.recover(signature) != data.signer) revert InvalidSignature();

        _mint(edition, mintId, quantity, affiliate);
    }

    // ================================
    // VIEW FUNCTIONS
    // ================================

    /**
     * @dev Returns the given edition's mint instance.
     * @param edition The edition to get the mint instance for.
     * @param mintId The ID of the mint instance.
     */
    function editionMintData(address edition, uint256 mintId) public view returns (EditionMintData memory) {
        return _editionMintData[edition][mintId];
    }

    function mintInfo(address edition, uint256 mintId) public view returns (MintInfo memory) {
        BaseData memory baseData = _baseData[edition][mintId];
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

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, BaseMinter) returns (bool) {
        return BaseMinter.supportsInterface(interfaceId) || interfaceId == type(IFixedPriceSignatureMinter).interfaceId;
    }

    /// @inheritdoc IMinterModule
    function minterInterfaceId() public pure returns (bytes4) {
        return type(IFixedPriceSignatureMinter).interfaceId;
    }

    // ================================
    // INTERNAL FUNCTIONS
    // ================================

    function _baseTotalPrice(
        address edition,
        uint256 mintId,
        address, /* minter */
        uint32 quantity
    ) internal view virtual override returns (uint256) {
        return _editionMintData[edition][mintId].price * quantity;
    }
}
