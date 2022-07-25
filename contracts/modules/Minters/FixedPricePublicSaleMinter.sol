// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

import "./EditionMinter.sol";
import "../../SoundEdition/ISoundEditionV1.sol";

contract FixedPricePublicSaleMinter is EditionMinter {
    error MintWithWrongEtherValue();

    error MintOutOfStock();

    error MintNotStarted();

    error MintHasEnded();

    // prettier-ignore
    event FixedPricePublicSaleMintCreated(
        address indexed edition,
        uint256 price,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMinted
    );

    struct EditionMintData {
        // The price at which each token will be sold, in ETH.
        uint256 price;
        // Start timestamp of sale (in seconds since unix epoch).
        uint32 startTime;
        // End timestamp of sale (in seconds since unix epoch).
        uint32 endTime;
        // The maximum number of tokens that can can be minted for this sale.
        uint32 maxMinted;
        // The total number of tokens minted so far for this sale.
        uint32 totalMinted;
    }

    mapping(address => EditionMintData) public editionMintData;

    function createEditionMint(
        address edition,
        uint256 price,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMinted
    ) public {
        _createEditionMint(edition);
        EditionMintData storage data = editionMintData[edition];
        data.price = price;
        data.startTime = startTime;
        data.endTime = endTime;
        data.maxMinted = maxMinted;
        // prettier-ignore
        emit FixedPricePublicSaleMintCreated(
            edition,
            price,
            startTime,
            endTime,
            maxMinted
        );
    }

    function deleteEditionMint(address edition) public {
        _deleteEditionMint(edition);
        delete editionMintData[edition];
    }

    function mint(address edition, uint32 quantity) public payable virtual {
        EditionMintData storage data = editionMintData[edition];
        if ((data.totalMinted += quantity) > data.maxMinted) revert MintOutOfStock();
        if (data.price * quantity != msg.value) revert MintWithWrongEtherValue();
        if (block.timestamp < data.startTime) revert MintNotStarted();
        if (data.endTime < block.timestamp) revert MintHasEnded();
        ISoundEditionV1(edition).mint{ value: msg.value }(edition, quantity);
    }
}
