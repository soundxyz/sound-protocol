// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

/**
 * @dev Data unique to a fixed-price signature mint.
 */
struct EditionMintData {
    // The price at which each token will be sold, in ETH.
    uint96 price;
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
    uint16 affiliateFeeBPS;
    bool mintPaused;
    uint96 price;
    uint32 maxMintable;
    uint32 maxMintablePerAccount;
    uint32 totalMinted;
    address signer;
}

/**
 * @title IFixedPriceSignatureMinter
 * @dev Interface for the `FixedPriceSignatureMinter` module.
 * @author Sound.xyz
 */
interface IFixedPriceSignatureMinter is IMinterModule {
    /**
     * Emits event when a new fixed price signature mint is created.
     * @param edition The edition address.
     * @param mintId The mint ID.
     * @param signer The address of the signer that authorizes mints.
     * @param maxMintable The maximum number of tokens that can be minted.
     * @param startTime The time minting can begin.
     * @param endTime The time minting will end.
     * @param affiliateFeeBPS The affiliate fee in basis points.
     */
    event FixedPriceSignatureMintCreated(
        address indexed edition,
        uint128 indexed mintId,
        uint96 price,
        address signer,
        uint32 maxMintable,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS
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
     * @param price The price to mint a token.
     * @param signer The address of the signer that authorizes mints.
     * @param maxMintable_ The maximum number of tokens that can be minted.
     * @param startTime The time minting can begin.
     * @param endTime The time minting will end.
     * @param affiliateFeeBPS The affiliate fee in basis points.
     * @return mintId The ID of the new mint instance.
     */
    function createEditionMint(
        address edition,
        uint96 price,
        address signer,
        uint32 maxMintable_,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS
    ) external returns (uint128 mintId);

    /**
     * @dev Mints a token for a particular mint instance.
     * @param mintId The mint ID.
     * @param quantity The quantity of tokens to mint.
     * @param signature The signed message to authorize the mint.
     */
    function mint(
        address edition,
        uint128 mintId,
        uint32 quantity,
        bytes calldata signature,
        address affiliate
    ) external payable;

    /**
     * @dev Returns IFixedPriceSignatureMinter.MintInfo instance containing the full minter parameter set.
     * @param edition The edition to get the mint instance for.
     * @param mintId The ID of the mint instance.
     */
    function mintInfo(address edition, uint128 mintId) external view returns (MintInfo memory);
}
