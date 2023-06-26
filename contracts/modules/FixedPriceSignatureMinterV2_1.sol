// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { ECDSA } from "solady/utils/ECDSA.sol";
import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { BaseMinterV2_1 } from "@modules/BaseMinterV2_1.sol";
import { IFixedPriceSignatureMinterV2_1, EditionMintData, MintInfo } from "./interfaces/IFixedPriceSignatureMinterV2_1.sol";
import { IMinterModuleV2_1 } from "@core/interfaces/IMinterModuleV2_1.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";

/**
 * @title IFixedPriceSignatureMinterV2_1
 * @dev Module for fixed-price, signature-authorized mints of Sound editions.
 * @author Sound.xyz
 */
contract FixedPriceSignatureMinterV2_1 is IFixedPriceSignatureMinterV2_1, BaseMinterV2_1 {
    using ECDSA for bytes32;
    using LibBitmap for *;

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /**
     * @dev EIP-712 Typed structured data hash (used for checking signature validity).
     *      https://eips.ethereum.org/EIPS/eip-712
     */
    bytes32 public constant MINT_TYPEHASH =
        keccak256(
            "EditionInfo(address buyer,uint128 mintId,uint32 claimTicket,uint32 signedQuantity,address affiliate)"
        );

    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev Edition mint data
     *      `_baseDataSlot(_getBaseData(edition, mintId))` => value.
     */
    mapping(bytes32 => EditionMintData) internal _editionMintData;

    /**
     * @dev A mapping of bitmaps where each bit represents whether the ticket has been claimed.
     *      `_baseDataSlot(_getBaseData(edition, mintId))` => `index` => bit array
     */
    mapping(bytes32 => LibBitmap.Bitmap) internal _claimsBitmaps;

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IFixedPriceSignatureMinterV2_1
     */
    function createEditionMint(
        address edition,
        uint96 price,
        address signer,
        uint32 maxMintable,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS
    ) public returns (uint128 mintId) {
        if (signer == address(0)) revert SignerIsZeroAddress();
        mintId = _createEditionMint(edition, startTime, endTime, affiliateFeeBPS);

        BaseData storage baseData = _getBaseDataUnchecked(edition, mintId);
        baseData.price = price;

        EditionMintData storage data = _editionMintData[_baseDataSlot(baseData)];
        data.signer = signer;
        data.maxMintable = maxMintable;
        // prettier-ignore
        emit FixedPriceSignatureMintCreated(
            edition,
            mintId,
            price,
            signer,
            maxMintable,
            startTime,
            endTime,
            affiliateFeeBPS
        );
    }

    /**
     * @inheritdoc IFixedPriceSignatureMinterV2_1
     */
    function mintTo(
        address edition,
        uint128 mintId,
        address to,
        uint32 quantity,
        uint32 signedQuantity,
        address affiliate,
        bytes32[] calldata affiliateProof,
        bytes calldata signature,
        uint32 claimTicket,
        uint256 attributionId
    ) public payable {
        if (quantity > signedQuantity) revert ExceedsSignedQuantity();

        // Compute the digest here to avoid stack too deep.
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(MINT_TYPEHASH, to, mintId, claimTicket, signedQuantity, msg.sender))
            )
        );

        bytes32 baseDataSlot = _baseDataSlot(_getBaseData(edition, mintId));

        EditionMintData storage data = _editionMintData[baseDataSlot];

        // Just in case.
        // For an uninitialized mint, `data.maxMintable` will be zero, which will not allow any mints.
        // But we include this check, just in case the condition is removed in the future.
        if (data.signer == address(0)) revert SignerIsZeroAddress();

        data.totalMinted = _incrementTotalMinted(data.totalMinted, quantity, data.maxMintable);

        // Validate the signature.
        if (digest.recoverCalldata(signature) != data.signer) revert InvalidSignature();

        // Toggle the bit for the `claimTicket`.
        // If the toggled value is false, it means that it has already been used.
        if (!_claimsBitmaps[baseDataSlot].toggle(claimTicket)) revert SignatureAlreadyUsed();

        _mintTo(edition, mintId, to, quantity, affiliate, affiliateProof, attributionId);
    }

    /**
     * @inheritdoc IFixedPriceSignatureMinterV2_1
     */
    function mint(
        address edition,
        uint128 mintId,
        uint32 quantity,
        uint32 signedQuantity,
        address affiliate,
        bytes calldata signature,
        uint32 claimTicket
    ) public payable {
        mintTo(
            edition,
            mintId,
            msg.sender,
            quantity,
            signedQuantity,
            affiliate,
            MerkleProofLib.emptyProof(),
            signature,
            claimTicket,
            0
        );
    }

    /**
     * @inheritdoc IFixedPriceSignatureMinterV2_1
     */
    function setMaxMintable(
        address edition,
        uint128 mintId,
        uint32 maxMintable
    ) public onlyEditionOwnerOrAdmin(edition) {
        _editionMintData[_baseDataSlot(_getBaseData(edition, mintId))].maxMintable = maxMintable;
        emit MaxMintableSet(edition, mintId, maxMintable);
    }

    /**
     * @inheritdoc IFixedPriceSignatureMinterV2_1
     */
    function setPrice(
        address edition,
        uint128 mintId,
        uint96 price
    ) public onlyEditionOwnerOrAdmin(edition) {
        _getBaseData(edition, mintId).price = price;
        emit PriceSet(edition, mintId, price);
    }

    /**
     * @inheritdoc IFixedPriceSignatureMinterV2_1
     */
    function setSigner(
        address edition,
        uint128 mintId,
        address signer
    ) public onlyEditionOwnerOrAdmin(edition) {
        if (signer == address(0)) revert SignerIsZeroAddress();
        _editionMintData[_baseDataSlot(_getBaseData(edition, mintId))].signer = signer;
        emit SignerSet(edition, mintId, signer);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IFixedPriceSignatureMinterV2_1
     */
    function mintInfo(address edition, uint128 mintId) external view override returns (MintInfo memory info) {
        BaseData storage baseData = _getBaseData(edition, mintId);
        EditionMintData storage mintData = _editionMintData[_baseDataSlot(baseData)];

        info.startTime = baseData.startTime;
        info.endTime = baseData.endTime;
        info.affiliateFeeBPS = baseData.affiliateFeeBPS;
        info.mintPaused = baseData.mintPaused;
        info.price = baseData.price;
        info.maxMintable = mintData.maxMintable;
        info.maxMintablePerAccount = type(uint32).max;
        info.totalMinted = mintData.totalMinted;
        info.signer = mintData.signer;

        info.affiliateMerkleRoot = baseData.affiliateMerkleRoot;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, BaseMinterV2_1) returns (bool) {
        return
            BaseMinterV2_1.supportsInterface(interfaceId) ||
            interfaceId == type(IFixedPriceSignatureMinterV2_1).interfaceId;
    }

    /**
     * @inheritdoc IMinterModuleV2_1
     */
    function moduleInterfaceId() public pure returns (bytes4) {
        return type(IFixedPriceSignatureMinterV2_1).interfaceId;
    }

    /**
     * @inheritdoc IFixedPriceSignatureMinterV2_1
     */
    function checkClaimTickets(
        address edition,
        uint128 mintId,
        uint32[] calldata claimTickets
    ) external view returns (bool[] memory claimed) {
        LibBitmap.Bitmap storage bitmap = _claimsBitmaps[_baseDataSlot(_getBaseData(edition, mintId))];
        claimed = new bool[](claimTickets.length);
        // Will not overflow due to max block gas limit bounding the size of `claimTickets`.
        unchecked {
            for (uint256 i = 0; i < claimTickets.length; i++) {
                claimed[i] = bitmap.get(claimTickets[i]);
            }
        }
    }

    /**
     * @inheritdoc IFixedPriceSignatureMinterV2_1
     */
    function DOMAIN_SEPARATOR() public view returns (bytes32 separator) {
        separator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(uint256 chainId,address verifyingContract)"),
                block.chainid,
                address(this)
            )
        );
    }
}
