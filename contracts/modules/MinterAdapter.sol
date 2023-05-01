// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { IEditionMaxMinter } from "./interfaces/IEditionMaxMinter.sol";
import { ISAM } from "./interfaces/ISAM.sol";
import { IMinterAdapter, IERC165 } from "./interfaces/IMinterAdapter.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/**
 * @title Minter Adapter
 * @dev A minter adapter for minting to user specified addresses on
 *      old EditionMaxMinterV2s and RangeEditionMinterV2s,
 *      which do not have a `mintTo` function.
 */
contract MinterAdapter is IMinterAdapter {
    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IMinterAdapter
     */
    function mintTo(
        address minter,
        address edition,
        uint128 mintId,
        address to,
        uint32 quantity,
        address affiliate,
        uint256 attributionId
    ) public payable {
        uint256 tokenId = ISoundEditionV1(edition).nextTokenId();

        // This supports the old `mint` function on both
        // `IEditionMaxMinter` and `IRangeEditionMinter`.
        IEditionMaxMinter(minter).mint{ value: msg.value }(edition, mintId, quantity, affiliate);

        emit AdapterMinted(minter, edition, tokenId, quantity, to, attributionId);

        uint256 end = tokenId + uint256(quantity);
        while (tokenId != end) {
            ISoundEditionV1(edition).transferFrom(address(this), to, tokenId);
            unchecked {
                ++tokenId;
            }
        }

        if (address(this).balance != 0) {
            SafeTransferLib.forceSafeTransferETH(msg.sender, address(this).balance);
        }
    }

    /**
     * @inheritdoc IMinterAdapter
     */
    function samBuy(
        address sam,
        address edition,
        address to,
        uint32 quantity,
        address affiliate,
        bytes32[] calldata affiliateProof,
        uint256 attributionId,
        address excessRefundTo
    ) public payable {
        uint256 tokenId = ISoundEditionV1(edition).nextTokenId();

        ISAM(sam).buy{ value: msg.value }(edition, to, quantity, affiliate, affiliateProof, attributionId);

        emit AdapterMinted(sam, edition, tokenId, quantity, to, attributionId);

        if (address(this).balance != 0) {
            if (excessRefundTo == address(0)) {
                excessRefundTo = msg.sender;
            }
            SafeTransferLib.forceSafeTransferETH(excessRefundTo, address(this).balance);
        }
    }

    receive() external payable {}

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public pure override(IERC165) returns (bool) {
        return interfaceId == this.supportsInterface.selector || interfaceId == type(IMinterAdapter).interfaceId;
    }

    /**
     * @inheritdoc IMinterAdapter
     */
    function moduleInterfaceId() public pure returns (bytes4) {
        return type(IMinterAdapter).interfaceId;
    }
}
