// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

/**
 * @dev Data unique to a fixed-price signature mint.
 */
struct EditionMintData {
    // The price at which each token will be sold, in ETH.
    uint256 price;
    // Whitelist signer address.
    address signer;
    // The maximum number of tokens that can can be minted for this sale.
    uint32 maxMintable;
    // The total number of tokens minted so far for this sale.
    uint32 totalMinted;
}

/**
 * @dev All the information about a fixed-price signature mint (combines EditionMintData with BaseData).
 */
struct MintInfo {
    uint32 startTime;
    uint32 endTime;
    bool mintPaused;
    uint256 price;
    uint32 maxMintable;
    uint32 maxMintablePerAccount;
    uint32 totalMinted;
    address signer;
}

/**
 * @title Mint interface for the `FixedPriceSignatureMinter`.
 */
interface IFixedPriceSignatureMinter is IMinterModule {
    event FixedPriceSignatureMintCreated(
        address indexed edition,
        uint256 indexed mintId,
        uint256 price,
        address signer,
        uint32 maxMintable
    );

    error InvalidSignature();
    error SignerIsZeroAddress();

    /**
     * @dev Initializes the configuration for an edition mint.
     */
    function createEditionMint(
        address edition,
        uint256 price_,
        address signer,
        uint32 maxMintable_,
        uint32 startTime,
        uint32 endTime
    ) external returns (uint256 mintId);

    function mint(
        address edition,
        uint256 mintId,
        uint32 quantity,
        bytes calldata signature,
        address affiliate
    ) external payable;
}
