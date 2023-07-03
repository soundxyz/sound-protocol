// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { BaseMinterV2_1 } from "@modules/BaseMinterV2_1.sol";

struct MintInfo {
    uint32 startTime;
    uint32 endTime;
    uint16 affiliateFeeBPS;
    bool mintPaused;
}

contract MockMinterV2_1 is BaseMinterV2_1 {
    uint96 private _currentPrice;

    function createEditionMint(
        address edition,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS
    ) external returns (uint128 mintId) {
        mintId = _createEditionMint(edition, startTime, endTime, affiliateFeeBPS);
    }

    function mintTo(
        address edition,
        uint128 mintId,
        address to,
        uint32 quantity,
        address affiliate,
        bytes32[] calldata affiliateProof,
        uint256 attributionId
    ) public payable {
        _mintTo(edition, mintId, to, quantity, affiliate, affiliateProof, attributionId);
    }

    function mint(
        address edition,
        uint128 mintId,
        uint32 quantity,
        address affiliate
    ) external payable {
        mintTo(edition, mintId, msg.sender, quantity, affiliate, MerkleProofLib.emptyProof(), 0);
    }

    function setPrice(
        address edition,
        uint128 mintId,
        uint96 price
    ) external {
        _getBaseData(edition, mintId).price = price;
    }

    function requiredEtherValue(
        address edition,
        uint128 mintId,
        uint32 quantity
    ) external view returns (uint256) {
        (uint256 total, , , , ) = totalPriceAndFees(edition, mintId, quantity);
        return total;
    }

    function mintInfo(address edition, uint128 mintId) external view returns (MintInfo memory) {
        BaseData memory baseData = _getBaseData(edition, mintId);

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
