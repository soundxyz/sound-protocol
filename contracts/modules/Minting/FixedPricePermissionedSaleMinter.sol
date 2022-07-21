// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

import "./EditionMintControllers.sol";
import "../../SoundEdition/ISoundEditionV1.sol";

contract FixedPricePermissionedMinter is EditionMintControllers {

    struct EditionMintData {
        // The price at which each token will be sold, in ETH.
        uint256 price;
        // Whitelist signer address.
        address signer;
        // The maximum number of tokens that can can be minted for this sale.
        uint32 maxMinted;
        // The total number of tokens minted so far for this sale.
        uint32 totalMinted;
    }

    mapping(address => EditionMintData) public editionMintData;
    
    function createEditionMint(
        address edition,
        uint256 price,
        address signer,
        uint32 maxMinted
    ) public {
        _initEditionMintController(edition);
        EditionMintData storage data = editionMintData[edition];
        data.price = price;
        data.signer = signer;
        data.maxMinted = maxMinted;
    }

    function deleteMintee(address edition) public onlyEditionMintController(edition) {
        _deleteEditionMintController();
        delete editionMintData[edition];
    }

    function mint(address edition, uint256 quantity) public payable {
        // EditionMintData storage data = editionMintData[edition];
        // require(data.startTime <= block.timestamp, "Mint not started.");
        // require(data.endTime > block.timestamp, "Mint has ended.");
        // require(data.price * quantity == msg.value, "Wrong ether value.");
        // require((data.totalMinted += quantity) <= data.maxMinted, "No more mints.");
        ISoundEditionV1(edition).mint{value: msg.value}(edition, quantity);
    }
}
