// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

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
        bytes calldata signature
    ) external payable;
}
