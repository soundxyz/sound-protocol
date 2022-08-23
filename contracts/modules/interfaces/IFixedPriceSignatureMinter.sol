// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

/**
 * @title IFixedPriceSignatureMinter
 * @dev Interface for the `FixedPriceSignatureMinter` module.
 */
interface IFixedPriceSignatureMinter is IMinterModule {
    /**
     * Emits event when a new fixed price signature mint is created.
     * @param edition The edition address.
     * @param mintId The mint ID.
     * @param signer The address of the signer that authorizes mints.
     * @param maxMintable The maximum number of tokens that can be minted.
     */
    event FixedPriceSignatureMintCreated(
        address indexed edition,
        uint256 indexed mintId,
        uint256 price,
        address signer,
        uint32 maxMintable
    );

    /**
     * @dev The signature is invalid.
     */
    error InvalidSignature();

    /**
     * @dev The signer can't be the zero address.
     */
    error SignerIsZeroAddress();

    /**
     * @dev Initializes a fixed-price signature mint instance.
     * @param edition The edition address.
     * @param price_ The price to mint a token.
     * @param signer The address of the signer that authorizes mints.
     * @param maxMintable_ The maximum number of tokens that can be minted.
     * @param startTime The time minting can begin.
     * @param endTime The time minting will end.
     * @return mintId The ID of the new mint instance.
     */
    function createEditionMint(
        address edition,
        uint256 price_,
        address signer,
        uint32 maxMintable_,
        uint32 startTime,
        uint32 endTime
    ) external returns (uint256 mintId);

    /**
     * @dev Mints a token for a particular mint instance.
     * @param mintId The mint ID.
     * @param quantity The quantity of tokens to mint.
     * @param signature The signed message to authorize the mint.
     */
    function mint(
        address edition,
        uint256 mintId,
        uint32 quantity,
        bytes calldata signature,
        address affiliate
    ) external payable;
}
