// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

import "./FixedPricePublicSaleMinter.sol";

contract GoldenEggMinter is FixedPricePublicSaleMinter {
    // Used to calculate token id for golden egg
    mapping(address => bytes32) _goldenEggBlockhashForEdition;

    function mint(address edition, uint32 quantity) public payable override {
        super.mint(edition, quantity);

        _goldenEggBlockhashForEdition[edition] = blockhash(block.number - 1);
    }

    /// @notice Returns token id for the golden egg, after auction has ended. Else returns 0
    function getGoldenEggTokenId(address edition) external view returns (uint256 _tokenId) {
        uint256 totalMinted = editionMintData[edition].totalMinted;

        if (block.timestamp > editionMintData[edition].endTime || totalMinted == editionMintData[edition].maxMinted) {
            // calculate number between 1 and totalMinted, corresponding to the blockhash
            _tokenId = (uint256(_goldenEggBlockhashForEdition[edition]) % totalMinted) + 1;
        }
    }
}
