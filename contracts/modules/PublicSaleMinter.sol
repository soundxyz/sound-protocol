// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.16;

import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { IPublicSaleMinter, EditionMintData, MintInfo } from "./interfaces/IPublicSaleMinter.sol";
import { BaseMinter } from "./BaseMinter.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

/*
 * @title PublicSaleMinter
 * @notice Module for range edition mints of Sound editions.
 * @author Sound.xyz
 */
contract PublicSaleMinter is IPublicSaleMinter, BaseMinter {
    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev Edition mint data
     * edition => mintId => EditionMintData
     */
    mapping(address => mapping(uint128 => EditionMintData)) internal _editionMintData;

    /**
     * @dev Number of tokens minted by each buyer address
     * edition => mintId => buyer => mintedTallies
     */
    mapping(address => mapping(uint256 => mapping(address => uint256))) public mintedTallies;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor(ISoundFeeRegistry feeRegistry_) BaseMinter(feeRegistry_) {}

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IPublicSaleMinter
     */
    function createEditionMint(
        address edition,
        uint96 price,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS,
        uint32 maxMintablePerAccount
    ) public returns (uint128 mintId) {
        mintId = _createEditionMint(edition, startTime, endTime, affiliateFeeBPS);

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.price = price;
        data.maxMintablePerAccount = maxMintablePerAccount;

        // prettier-ignore
        emit PublicSaleMintCreated(
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
     * @inheritdoc IPublicSaleMinter
     */
    function mint(
        address edition,
        uint128 mintId,
        uint32 quantity,
        address affiliate
    ) public payable {
        EditionMintData storage data = _editionMintData[edition][mintId];

        uint32 _maxMintable = _getMaxMintable(ISoundEditionV1(edition), data);

        // Require that the increased `totalMinted()` value does not exceed `maxMintable`.
        _incrementTotalMinted(uint32(ISoundEditionV1(edition).totalMinted()), quantity, _maxMintable);

        unchecked {
            uint256 userMintedBalance = mintedTallies[edition][mintId][msg.sender];
            // Check the additional quantity does not exceed the set maximum.
            // If `quantity` is large enough to cause an overflow,
            // `_mint` will give an out of gas error.
            uint256 tally = userMintedBalance + quantity;
            if (tally > data.maxMintablePerAccount) revert ExceedsMaxPerAccount();
            // Update the minted tally for this account
            mintedTallies[edition][mintId][msg.sender] = tally;
        }

        _mint(edition, mintId, quantity, affiliate);
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
     * @inheritdoc IPublicSaleMinter
     */
    function mintInfo(address edition, uint128 mintId) public view returns (MintInfo memory) {
        BaseData memory baseData = _baseData[edition][mintId];
        EditionMintData storage mintData = _editionMintData[edition][mintId];

        MintInfo memory combinedMintData = MintInfo(
            baseData.startTime,
            baseData.endTime,
            baseData.affiliateFeeBPS,
            baseData.mintPaused,
            mintData.price,
            mintData.maxMintablePerAccount
        );

        return combinedMintData;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, BaseMinter) returns (bool) {
        return BaseMinter.supportsInterface(interfaceId) || interfaceId == type(IPublicSaleMinter).interfaceId;
    }

    /**
     * @inheritdoc IMinterModule
     */
    function moduleInterfaceId() public pure returns (bytes4) {
        return type(IPublicSaleMinter).interfaceId;
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Gets the current maximum mintable quantity.
     * @param edition The sound edition.
     * @param data    The edition mint data.
     * @return The computed value.
     */
    function _getMaxMintable(ISoundEditionV1 edition, EditionMintData storage data) internal view returns (uint32) {
        if (block.timestamp < edition.mintRandomnessTimeThreshold()) {
            return edition.editionMaxMintable();
        } else {
            return edition.mintRandomnessTokenThreshold();
        }
    }
}
