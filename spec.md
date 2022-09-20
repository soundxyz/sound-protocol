---
title: Sound Protocol 2.0
description: A permissionless NFT factory which enables customizations for auction formats, payments, metadata, and on-chain registries.
author: Sound Protocol Team
status: Draft
---

## ABSTRACT

Sound Protocol 2.0 enables creators to permissionlessly deploy gas-efficient minimal, non-upgradeable [721a](https://www.azuki.com/erc721a) proxies from a factory contract. The protocol enables support for customizing auction formats, payments, & metadata.

## Core Contracts & Interfaces

### `SoundCreatorV1.sol`

-   Deploys [minimal proxies (clones)](https://eips.ethereum.org/EIPS/eip-1167) of `SoundEditionV1.sol` & initializes them with customizable configurations.

### `SoundEditionV1.sol`

-   Logic contract for the minimal proxies deployed from SoundCreatorV1.
-   Extended version of the [721a implementation](https://www.azuki.com/erc721a) with:
    -   `ERC721AQueryableUpgradeable` - adds convenient query functions
    -   `ERC721ABurnableUpgradeable` - adds token burn functionality
-   Implements [EIP-2981 Royalty Standard](https://eips.ethereum.org/EIPS/eip-2981).
-   Implements [EIP-165](https://eips.ethereum.org/EIPS/eip-165).

Features:

-   Implements "module" contracts that augment or override the base functionality for:
    -   Metadata - `tokenURI`.
    -   Payments - royalties & withdrawals.
    -   Minting - multiple auction formats.
-   Metadata
    -   For on-chain custom metadata `metadataModule` is utilized, which is a contract that implements `IMetadataModule.sol` and provides `tokenURI`.
    -   If `metadataModule` is not present, `tokenURI` uses `baseURI`.
    -   Implements `contractURI` (https://docs.opensea.io/docs/contract-level-metadata).
    -   Allows freezing of metadata, beyond which the variables can't be modified by `owner`.
-   Payments
    -   `SoundEditionV1.fundingRecipient` - an address that receives all revenue accrued (primary sales & secondary royalty revenue). In the case where the artist is the sole recipient, this is their wallet address. If they are splitting revenue with other parties, this could be an [0xSplits SplitWallet](https://docs.0xsplits.xyz/smartcontracts/SplitWallet) or alternative splitter contract.
    -   Secondary revenue can accrue to to the edition via the `receive` function, or to a separate address (ex: a [SplitWallet](https://docs.0xsplits.xyz/smartcontracts/SplitWallet) set as the `fundingRecipient`).
    -   Minter modules created by Sound collect a platform fee governed by `SoundFeeRegistry.sol`.
-   Minting
    -   Only the owner, callers with ADMIN_ROLE, and callers with MINTER_ROLE (e.g. minter modules) can call mint.
    -   `SoundEditionV1.editionMaxMintable` - maximum number of tokens that can be minted for the edition.
        -   Can be initialized with any value up to `type(uint32).max`.
        -   Can be reduced by owner or admins after initialization down to any point above or equal to the current token count.
    -   The maximum number of tokens that can be minted is constrained by `editionMaxMintable`.
        -   Before `editionCutoffTime`, this value is `editionMaxMintableUpper`.
        -   After (inclusive) `editionCutoffTime`, this value is the maximum of `editionMaxMintableLower` and `totalMinted()`.
-   Access control
    -   Implements [solady `OwnableRoles`](https://github.com/Vectorized/solady/blob/main/src/auth/OwnableRoles.sol).
    -   Roles can be granted & revoked for addresses. ex:
        -   Minter contracts must have `MINTER_ROLE`.
        -   Owner-defined admins must have `ADMIN_ROLE`.
-   Golden egg - see `GoldenEggMetadataModule.sol` section.

### `IMinterModule.sol`

-   Interface that all minter modules must implement.

### `IMetadataModule.sol`

-   Interface that all metadata modules must implement.

### `SoundFeeRegistry.sol`

-   A contract that exposes a Sound recipient address & protocol fee used by minter modules to pay a portion of primary sales to Sound.xyz for its services.

## SOUND MODULES

### Metadata modules

-   Metadata modules must implement `IMetadataModule.sol`
-   Current modules:
    -   `GoldenEggMetadataModule.sol`
        -   Uses the `mintRandomness` on the edition to return the golden egg token ID. The Golden Egg is a single token per edition that is randomly selected from the set of minted tokens.
        -   The `mintRandomness` is determined by storing the blockhash of each mint on the edition contract, up until a token quantity threshold or timestamp (whichever comes first). NOTE: The randommness doesn't necessarily need to be used for the golden egg.
        -   `GoldenEggMetadataModule.sol` uses the `mintRandomness` on the edition to return the golden egg token ID.

### Minter modules

-   Minter modules must implement `IMinterModule.sol`
-   Minter modules are contracts authorized to mint via a `MINTER_ROLE`, which can only be granted by the edition owner (the artist).
-   Each minter can define any max token quantity, irrespective of quantities minted by other minters. However, all minters are constrained by the `SoundEditionV1.editionMaxMintable`. It is up to the artist to initialize the `editionMaxMintable` with a value high enough to accomodate all current & future mints.
-   Affiliate fee: Third parties can collect an affiliate fee by setting an address when minting. The fee is set by the artist when initializing the mint instance. Example use-case: a music blog that exposes a UI to mint songs it is promoting.
-   Current modules:
    -   `FixedPriceSignatureMinter`
        -   Mints tokens at a fixed price for buyers approved to buy via signature verification.
        -   The quantity of tokens an address can mint is controlled by the off-chain signature granting process.
        -   Each signature can only be used a single time, which is enforced via claim tickets stored in gas-efficient bitmaps.
        -   The signature is unique by `edition` address, `buyer` address, `mintId`, single-use `claimTicket`, a `signedQuantity` enforcing an upper limit for the transaction, and `affiliate` address.
    -   `RangeEditionMinter`
        -   Mints either a fixed quantity or a quantity [within a range](https://sound.mirror.xyz/hmz2pueqBV37MD-mULjvch0vQoc-VKJdsfqXf8jTB30) based on time bounds.
        -   The quantity of tokens an address can mint is constrained by `maxMintablePerAccount`.
    -   `PublicSaleMinter`
        -   Mints tokens at a fixed price.
        -   The quantity of tokens an address can mint is constrained by `maxMintablePerAccount`.
    -   `MerkleDropMinter`
        -   Enables a predefined list of recipients to mint tokens at a fixed price.
        -   The price can be zero.
        -   Each whitelisted user can claim their eligible amount in multiple transactions.
        -   The quantity of tokens an address can mint is constrained by `maxMintablePerAccount`.

#### Adding a custom minter module

The minter modules are designed with extensibility in mind in order to allow innovation around token distribution for artists. There are no mandated properties of a custom minter although we recommend all custom minters implement `BaseMinter`. This contains base functionality that allows for Pausability, Affiliate and platform fees, and IERC165 support.

Additionally for NFTs based on the `SoundEditionV1` implementation, the edition owner needs to grant `MINTER_ROLE` permissions to the minter contract.

## Security model

This section describes, from a security perspective, the expected behavior of the system. 

### Actors
- **SoundFeeRegistry owner** - 
    - The owner of the SoundFeeRegistry contract. 
    - Can update the protocol fee and recipient address.
- **SoundCreatorV1 owner** - 
    - The owner of the SoundCreatorV1 contract. 
    - Can change the SoundEdition implementation used by the edition proxies.
- **SoundEditionV1 owner**: 
    - The owner of the edition contract. 
    - Can assign role privileges to other accounts (e.g. `ADMIN_ROLE`, `MINTER_ROLE`), mint and airdrop tokens directly from the edition, and set all the settable parameters on the edition and minter contracts.
- **SoundEditionV1 admin**: 
    - An account that has been granted `ADMIN_ROLE` by the edition owner. 
    - They can perform all the edition-level actions that the owner can perform such as setting edition & minter contract parameters. 
    - They cannot assign role privileges or change the owner.
- **SoundEditionV1 funding recipient**: 
    - An account assigned as `fundingRecipient` on the edition, enabling it to receive withdrawn ETH from the edition. 
    - Only one account can be assigned as the funding recipient at a time.
- **Minter**: 
    - An account that has been granted `MINTER_ROLE` by the edition owner. 
    - Can mint tokens from the edition contract.
- **Affiliate**: 
    - An account assigned by the edition owner or admin, that receives a portion of the primary sales. 
    - It is set by passing an affiliate address to a minter contract's `mint` funtion.
- **Buyer**: 
    - An account that purchases a token from the edition contract. 
    - The term "Buyer" is irrespective of price, as mint configurations can be set with price of zero.

### Trust model
No contracts in the prevailing Sound Protocol are upgradeable, therefore trust assumptions are minimized. However, given that the protocol is designed to be modular and permissionless, and is intended to give edition owners maximum flexibility, there are some important points to consider:
- The `SoundEditionV1` owner and admins can change edition parameters after an edition has been deployed:
    - `fundingRecipient` - Account that receives ETH withdrawn from the edition. The funding recipient can be set to a contract address, the security of which is not guaranteed by the Sound Protocol. However, in this case the trust assumptions are limited to the artist and any other parties with whom they are splitting revenue.
    - `baseURI` - Location of the metadata of the edition, which can be changed if the metadata is not in a frozen state.
    - `metadataModule` - Module used to override the default edition metadata functionality, which can be changed if the metadata is not in a frozen state.
    - `royaltyBPS` - The royalty percentage paid to the funding recipient from secondary sales, used by marketplaces that support EIP-2981 royalties.
    - `editionMaxMintableRange` - The values representing the mintable range can only be reduced and never increased.
    - `cutoffTime` - This is a time threshold that is used to conditionally determine the maximum mintable quantity, and can be changed only if the minting hasn't concluded.
    - `mintRandomness` - A random number generated with each mint & used for game mechanics like the Sound Golden Egg. It can only be enabled or disabled if no tokens have been minted.
- The `SoundCreatorV1` can be set to a different edition implementation at any time, which may have different trust assumptions. Changing the edition implementation does not impact editions which have already been deployed.
- The edition owner or admins can change the following paramters on the minter modules:
    - Time values (`startTime`, `cutoffTime`, `endTime`)
    - `paused` - Whether a given mint schedule is paused or not.
    - `affiliateFeeBPS` - The affiliate fee percentage paid to the affiliate address from primary sales.
    - `price` - The price of the token in ETH.
    - `maxMintablePerAccount` - The maximum number of tokens that can be minted by a single account.
    - The mintable quantity for a given mint schedule.
    - `signer` - The signer address used to authorizing minting (only applies to `FixedPriceSignatureMinter`).
    - `merkleRootHash` - The root hash of the merkle tree of accounts allowed to mint (only applies to `MerkleDropMinter`).
- Minter or metadata modules deployed in the future may have different trust assumptions than existing minter contracts. 
