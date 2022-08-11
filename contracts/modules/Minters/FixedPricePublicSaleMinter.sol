// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

import "./MintControllerBase.sol";

/**
 * @title Fixed Price Public Sale Minter
 * @dev Minter class for sales at a fixed price within a time range.
 */
contract FixedPricePublicSaleMinter is MintControllerBase {
    /**
     * The number of tokens minted has exceeded the number allowed for each wallet.
     */
    error ExceedsMaxPerWallet();

    // prettier-ignore
    event FixedPricePublicSaleMintCreated(
        address indexed edition,
        uint256 indexed mintId, 
        uint256 price,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMintable,
        uint32 maxAllowedPerWallet
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
        // The maximum number of tokens that a wallet can mint.
        uint32 maxAllowedPerWallet;
        // The total number of tokens minted so far for this sale.
        uint32 totalMinted;
    }

    mapping(address => mapping(uint256 => EditionMintData)) internal _editionMintData;

    /**
     * @dev Initializes the configuration for an edition mint.
     * @param edition Address of the song edition contract we are minting for.
     * @param price Sale price in ETH for minting a single token in `edition`.
     * @param startTime Start timestamp of sale (in seconds since unix epoch).
     * @param endTime End timestamp of sale (in seconds since unix epoch).
     * @param maxMintable The maximum number of tokens that can can be minted for this sale.
     * @param maxAllowedPerWallet The maximum number of tokens that a wallet can mint.
     */
    function createEditionMint(
        address edition,
        uint256 price,
        uint32 startTime,
        uint32 endTime,
        uint32 maxMintable,
        uint32 maxAllowedPerWallet
    ) public returns (uint256 mintId) {
        mintId = _createEditionMintController(edition);

        EditionMintData storage data = _editionMintData[edition][mintId];
        data.price = price;
        data.startTime = startTime;
        data.endTime = endTime;
        data.maxMintable = maxMintable;
        data.maxAllowedPerWallet = maxAllowedPerWallet;
        // prettier-ignore
        emit FixedPricePublicSaleMintCreated(
            edition,
            mintId, 
            price,
            startTime,
            endTime,
            maxMintable,
            maxAllowedPerWallet
        );
    }

    /**
     * @dev Deletes a given edition's mint configuration.
     * @param edition The edition to delete the mint configuration for.
     */
    function deleteEditionMint(address edition, uint256 mintId) public {
        _deleteEditionMintController(edition, mintId);
        delete _editionMintData[edition][mintId];
    }

    /**
     * @dev Returns the given edition's mint configuration.
     * @param edition The edition to get the mint configuration for.
     */
    function editionMintData(address edition, uint256 mintId) public view returns (EditionMintData memory) {
        return _editionMintData[edition][mintId];
    }

    /**
     * @dev Mints the required `quantity` in song `edition.
     * @param edition Address of the song edition contract we are minting for.
     * @param quantity Token quantity to mint in song `edition`.
     */
    function mint(
        address edition,
        uint256 mintId,
        uint32 quantity
    ) public payable {
        EditionMintData storage data = _editionMintData[edition][mintId];

        uint256 userBalance = ISoundEditionV1(edition).balanceOf(msg.sender);
        // If the maximum allowed per wallet is set (i.e. is different to 0)
        // check the required additional quantity does not exceed the set maximum
        if (data.maxAllowedPerWallet > 0 && ((userBalance + quantity) > data.maxAllowedPerWallet))
            revert ExceedsMaxPerWallet();

        uint32 nextTotalMinted = data.totalMinted + quantity;
        _requireNotSoldOut(nextTotalMinted, data.maxMintable);
        data.totalMinted = nextTotalMinted;

        _requireMintOpen(data.startTime, data.endTime);

        _mint(edition, mintId, msg.sender, quantity, data.price * quantity);
    }
}
