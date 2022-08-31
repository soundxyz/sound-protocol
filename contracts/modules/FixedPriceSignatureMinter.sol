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

    // =============================================================
    //                            STORAGE
    // =============================================================

    mapping(address => mapping(uint256 => EditionMintData)) internal _editionMintData;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor(ISoundFeeRegistry feeRegistry_) BaseMinter(feeRegistry_) {}

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IFixedPriceSignatureMinter
     */
    function createEditionMint(
        address edition,
        uint96 price,
        address signer,
        uint32 maxMintable_,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS
    ) public returns (uint128 mintId) {
        if (signer == address(0)) revert SignerIsZeroAddress();
        mintId = _createEditionMint(edition, startTime, endTime, affiliateFeeBPS);

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
            maxMintable_,
            startTime,
            endTime,
            affiliateFeeBPS
        );
    }

    /**
     * @inheritdoc IFixedPriceSignatureMinter
     */
    function mint(
        address edition,
        uint128 mintId,
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

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    function totalPrice(
        address edition,
        uint128 mintId,
        address, /* minter */
        uint32 quantity
    ) public view virtual override(BaseMinter, IMinterModule) returns (uint128) {
        return _editionMintData[edition][mintId].price * quantity;
    }

    /**
     * @inheritdoc IFixedPriceSignatureMinter
     */
    function mintInfo(address edition, uint128 mintId) public view override returns (MintInfo memory) {
        BaseData memory baseData = _baseData[edition][mintId];
        EditionMintData storage mintData = _editionMintData[edition][mintId];

        MintInfo memory combinedMintData = MintInfo(
            baseData.startTime,
            baseData.endTime,
            baseData.affiliateFeeBPS,
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

    /**
     * @inheritdoc IMinterModule
     */
    function moduleInterfaceId() public pure returns (bytes4) {
        return type(IFixedPriceSignatureMinter).interfaceId;
    }
}
