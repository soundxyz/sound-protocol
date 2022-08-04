// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

import "./MintControllerBase.sol";
import "../../SoundEdition/ISoundEditionV1.sol";

/// @dev Minter class for sales at a fixed price within a time range.
contract FixedPricePublicSaleMinter is MintControllerBase {
    error WrongEtherValue();

    error SoldOut();

    error MintNotStarted();

    error MintHasEnded();

    // prettier-ignore
    event FixedPricePublicSaleMintCreated(
        address indexed edition,
        uint256 price,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMintable
    );

    struct EditionMintData {
        // The price at which each token will be sold, in ETH.
        uint256 price;
        // Start timestamp of sale (in seconds since unix epoch).
        uint32 startTime;
        // End timestamp of sale (in seconds since unix epoch).
        uint32 endTime;
        // The maximum number of tokens that can can be minted for this sale.
        uint32 maxMintable;
        // The total number of tokens minted so far for this sale.
        uint32 totalMinted;
    }

    mapping(address => EditionMintData) internal _editionMintData;

    function createEditionMint(
        address edition,
        uint256 price,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMintable
    ) public {
        _createEditionMintController(edition);
        EditionMintData storage data = _editionMintData[edition];
        data.price = price;
        data.startTime = startTime;
        data.endTime = endTime;
        data.maxMintable = maxMintable;
        // prettier-ignore
        emit FixedPricePublicSaleMintCreated(
            edition,
            price,
            startTime,
            endTime,
            maxMintable
        );
    }

    function deleteEditionMint(address edition) public {
        _deleteEditionMintController(edition);
        delete _editionMintData[edition];
    }

    function editionMintData(address edition) public view returns (EditionMintData memory) {
        return _editionMintData[edition];
    }

    function mint(address edition, uint32 quantity) public payable {
        EditionMintData storage data = _editionMintData[edition];
        if ((data.totalMinted += quantity) > data.maxMintable) revert SoldOut();
        if (data.price * quantity != msg.value) revert WrongEtherValue();
        if (block.timestamp < data.startTime) revert MintNotStarted();
        if (data.endTime < block.timestamp) revert MintHasEnded();
        ISoundEditionV1(edition).mint{ value: msg.value }(msg.sender, quantity);
    }
}
