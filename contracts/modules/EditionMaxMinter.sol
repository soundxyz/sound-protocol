// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { IEditionMaxMinter, EditionMintData, MintInfo } from "./interfaces/IEditionMaxMinter.sol";
import { BaseMinter } from "./BaseMinter.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { ISoundEditionV1, EditionInfo } from "@core/interfaces/ISoundEditionV1.sol";

/*
 * @title EditionMaxMinter
 * @notice Module for unpermissioned mints of Sound editions.
 * @author Sound.xyz
 */
contract EditionMaxMinter is IEditionMaxMinter, BaseMinter {
    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev Edition mint data
     * edition => mintId => EditionMintData
     */
    mapping(address => mapping(uint128 => EditionMintData)) internal _editionMintData;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor(ISoundFeeRegistry feeRegistry_) BaseMinter(feeRegistry_) {}

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IEditionMaxMinter
     */
    function createEditionMint(
        address edition,
        uint96 price,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS,
        uint32 maxMintablePerAccount
    ) public returns (uint128 mintId) {
        if (maxMintablePerAccount == 0) revert MaxMintablePerAccountIsZero();

        mintId = _createEditionMint(edition, startTime, endTime, affiliateFeeBPS);

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.price = price;
        data.maxMintablePerAccount = maxMintablePerAccount;

        // prettier-ignore
        emit EditionMaxMintCreated(
            edition,
            mintId,
            price,
            startTime,
            endTime,
            affiliateFeeBPS,
            maxMintablePerAccount
        );
    }

    /**
     * @inheritdoc IEditionMaxMinter
     */
    function mint(
        address edition,
        uint128 mintId,
        uint32 quantity,
        address affiliate
    ) public payable {
        EditionMintData storage data = _editionMintData[edition][mintId];

        unchecked {
            // Check the additional `requestedQuantity` does not exceed the maximum mintable per account.
            uint256 numberMinted = ISoundEditionV1(edition).numberMinted(msg.sender);
            // Won't overflow. The total number of tokens minted in `edition` won't exceed `type(uint32).max`,
            // and `quantity` has 32 bits.
            if (numberMinted + quantity > data.maxMintablePerAccount) revert ExceedsMaxPerAccount();
        }

        _mint(edition, mintId, quantity, affiliate);
    }

    /**
     * @inheritdoc IEditionMaxMinter
     */
    function setPrice(
        address edition,
        uint128 mintId,
        uint96 price
    ) public onlyEditionOwnerOrAdmin(edition) {
        _editionMintData[edition][mintId].price = price;
        emit PriceSet(edition, mintId, price);
    }

    /**
     * @inheritdoc IEditionMaxMinter
     */
    function setMaxMintablePerAccount(
        address edition,
        uint128 mintId,
        uint32 maxMintablePerAccount
    ) public onlyEditionOwnerOrAdmin(edition) {
        if (maxMintablePerAccount == 0) revert MaxMintablePerAccountIsZero();
        _editionMintData[edition][mintId].maxMintablePerAccount = maxMintablePerAccount;
        emit MaxMintablePerAccountSet(edition, mintId, maxMintablePerAccount);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IMinterModule
     */
    function totalPrice(
        address edition,
        uint128 mintId,
        address, /* minter */
        uint32 quantity
    ) public view virtual override(BaseMinter, IMinterModule) returns (uint128) {
        unchecked {
            // Will not overflow, as `price` is 96 bits, and `quantity` is 32 bits. 96 + 32 = 128.
            return uint128(uint256(_editionMintData[edition][mintId].price) * uint256(quantity));
        }
    }

    /**
     * @inheritdoc IEditionMaxMinter
     */
    function mintInfo(address edition, uint128 mintId) external view returns (MintInfo memory info) {
        BaseData memory baseData = _baseData[edition][mintId];
        EditionMintData storage mintData = _editionMintData[edition][mintId];

        EditionInfo memory editionInfo = ISoundEditionV1(edition).editionInfo();

        info.startTime = baseData.startTime;
        info.endTime = baseData.endTime;
        info.affiliateFeeBPS = baseData.affiliateFeeBPS;
        info.mintPaused = baseData.mintPaused;
        info.price = mintData.price;
        info.maxMintablePerAccount = mintData.maxMintablePerAccount;
        info.maxMintableLower = editionInfo.editionMaxMintableLower;
        info.maxMintableUpper = editionInfo.editionMaxMintableUpper;
        info.cutoffTime = editionInfo.editionCutoffTime;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, BaseMinter) returns (bool) {
        return BaseMinter.supportsInterface(interfaceId) || interfaceId == type(IEditionMaxMinter).interfaceId;
    }

    /**
     * @inheritdoc IMinterModule
     */
    function moduleInterfaceId() public pure returns (bytes4) {
        return type(IEditionMaxMinter).interfaceId;
    }
}
