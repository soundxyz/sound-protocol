// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { BaseMinter } from "@modules/BaseMinter.sol";

struct MintInfo {
    uint32 startTime;
    uint32 endTime;
    uint16 affiliateFeeBPS;
    uint16 affiliateDiscountBPS;
    bool mintPaused;
}

contract MockMinter is BaseMinter {
    uint256 private _currentPrice;

    constructor(ISoundFeeRegistry feeRegistry_) BaseMinter(feeRegistry_) {}

    function createEditionMint(
        address edition,
        uint32 startTime,
        uint32 endTime
    ) external returns (uint256 mintId) {
        mintId = _createEditionMint(edition, startTime, endTime);
    }

    function mint(
        address edition,
        uint256 mintId,
        uint32 quantity,
        address affiliate
    ) external payable {
        _mint(edition, mintId, quantity, affiliate);
    }

    function setPrice(uint96 price) external {
        _currentPrice = price;
    }

    // ================================
    // INTERNAL FUNCTIONS
    // ================================

    function _baseTotalPrice(
        address, /* edition */
        uint256, /* mintId */
        address, /* minter */
        uint32 quantity
    ) internal view virtual override returns (uint256) {
        return _currentPrice * quantity;
    }

    function mintInfo(address edition, uint256 mintId) public view returns (MintInfo memory) {
        BaseData memory baseData = _baseData[edition][mintId];

        MintInfo memory combinedMintData = MintInfo(
            baseData.startTime,
            baseData.endTime,
            baseData.affiliateFeeBPS,
            baseData.affiliateDiscountBPS,
            baseData.mintPaused
        );

        return combinedMintData;
    }

    function moduleInterfaceId() public pure returns (bytes4) {
        return bytes4("");
    }
}
