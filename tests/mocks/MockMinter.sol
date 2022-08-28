// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { ISoundFeeRegistry } from "contracts/core/interfaces/ISoundFeeRegistry.sol";
import { BaseMinter } from "contracts/modules/BaseMinter.sol";

struct MintInfo {
    uint32 startTime;
    uint32 endTime;
    uint16 affiliateFeeBPS;
    bool mintPaused;
}

contract MockMinter is BaseMinter {
    uint128 private _currentPrice;

    constructor(ISoundFeeRegistry feeRegistry_) BaseMinter(feeRegistry_) {}

    function createEditionMint(
        address edition,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS
    ) external returns (uint128 mintId) {
        mintId = _createEditionMint(edition, startTime, endTime, affiliateFeeBPS);
    }

    function mint(
        address edition,
        uint128 mintId,
        uint32 quantity,
        address affiliate
    ) external payable {
        _mint(edition, mintId, quantity, affiliate);
    }

    function setPrice(uint96 price) external {
        _currentPrice = price;
    }

    function totalPrice(
        address, /* edition */
        uint128, /* mintId */
        address, /* minter */
        uint32 quantity
    ) public view virtual override(BaseMinter) returns (uint128) {
        return _currentPrice * quantity;
    }

    function mintInfo(address edition, uint128 mintId) public view returns (MintInfo memory) {
        BaseData memory baseData = _baseData[edition][mintId];

        MintInfo memory combinedMintData = MintInfo(
            baseData.startTime,
            baseData.endTime,
            baseData.affiliateFeeBPS,
            baseData.mintPaused
        );

        return combinedMintData;
    }

    function moduleInterfaceId() public pure returns (bytes4) {
        return bytes4("");
    }
}
