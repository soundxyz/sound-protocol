---
title: Sound Protocol 2.0
description: A permissionless NFT factory which enables customizations for auction formats, payments, metadata, and on-chain registries.
author: Sound Protocol Team
status: Draft
---

## ABSTRACT

Sound Protocol 2.0 enables creators to permissionlessly deploy gas-efficient minimal, non-upgradeable [721a](https://www.azuki.com/erc721a) proxies from a factory contract. The protocol enables support for customizing auction formats, payments, & metadata.

## CONTRACTS

### `SoundCreatorV1.sol`
- Upgradeable via [UUPSUpgradeable](https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable)
- Deploys [minimal proxies (clones)](https://eips.ethereum.org/EIPS/eip-1167) of `SoundEditionV1.sol` & initializes them with customizable configurations.
- Logic contract for the minimal proxies deployed from SoundCreatorV1.
- Extended version of the [721a implementation](https://www.azuki.com/erc721a) with `ERC721AQueryable` extension.
- Implements [EIP-2981 Royalty Standard](https://eips.ethereum.org/EIPS/eip-2981).
- Implements [EIP-165](https://eips.ethereum.org/EIPS/eip-165).

Features:
- Implements "module" contracts that augment or override the base functionality for:
  - Metadata - `tokenURI`.
  - Payments - royalties & withdrawals.
  - Minting - multiple auction formats.
- Metadata
  - For on-chain custom metadata `metadataModule` is utilized, which is a contract that implements `IMetadataModule.sol` and provides `tokenURI`.
  - If `metadataModule` is not present, `tokenURI` uses `baseURI`.
  - Implements `contractURI` (https://docs.opensea.io/docs/contract-level-metadata).
  - Allows freezing of metadata, beyond which the variables can't be modified by `owner`.
- Payments
  - `SoundEditionV1.fundingRecipient` - an address that receives all revenue accrued (primary sales & secondary royalty revenue). In the case where the artist is the sole recipient, this is their wallet address. If they are splitting revenue with other parties, this could be an [0xSplits SplitWallet](https://docs.0xsplits.xyz/smartcontracts/SplitWallet) or alternative splitter contract.
  - Secondary revenue can accrue to to the edition via the `receive` function, or to a separate address (ex: a [SplitWallet](https://docs.0xsplits.xyz/smartcontracts/SplitWallet) set as the `fundingRecipient`).
  - Minter modules pay a fee to Sound.xyz exposed by `SoundFeeRegistry.sol`. Minters technically don't need to pay the fee, but it is a requirement for editions to appear on sound.xyz.
  - Minter modules can also optionally pay fees to secondary recipients (e.g. developer fee for third-party integrations).
- Minting
  - The owner, callers with `ADMIN_ROLE`, and callers with `MINTER_ROLE` (e.g. minter modules) can all call `mint`.
  - `SoundEditionV1.maxSupply` - maximum number of tokens that can be minted for the edition.
    - Can be initialized with any value up to `type(uint32).max`.
    - Can be "frozen" by owner or `ADMIN_ROLE` at the current token count to prevent any further minting.
- Access control
  - Implements OpenZeppelin `OwnableUpgradeable` and `AccessControlUpgradeable` (upgradeable versions of each in order to support the proxy's `initialize` function).
  - Roles can be granted & revoked for addresses. ex: 
    - Minter contracts must have `MINTER_ROLE`.
    - Owner-defined admins must have `ADMIN_ROLE`.
- Golden egg - see `GoldenEggMetadataModule.sol` section.
### `SoundFeeRegistry.sol` 
- A contract that exposes a Sound protocol fee used by minter modules to pay a portion of primary sales to Sound.xyz for its services.

### SOUND MODULES
#### Metadata modules
- Metadata modules must implement `IMetadataModule.sol`
- Current modules: 
  - `GoldenEggMetadataModule.sol`
    - Uses the `mintRandomness` on the edition to return the golden egg token ID. The Golden Egg is a single token per edition that is randomly selected from the set of minted tokens.
    - The `mintRandomness` is determined by storing the blockhash of each mint on the edition contract, up until a token quantity threshold or timestamp (whichever comes first). NOTE: The randommness doesn't necessarily need to be used for the golden egg.
    - `GoldenEggMetadataModule.sol` uses the `mintRandomness` on the edition to return the golden egg token ID.

#### Minter modules
- Minter modules are contracts authorized to mint via a `MINTER_ROLE`, which can only be granted by the edition owner (the artist).
- Minter modules must inherit `MintControllerBase.sol`
- Each minter can define any max token quantity, irrespective of quantities minted by other minters. However, all minters are constrained by the `SoundEditionV1.maxSupply`. It is up to the artist to initialize the `maxSupply` with a value high enough to accomodate all current & future mints.
- Minter modules pay a fee to Sound.xyz exposed by `SoundFeeRegistry.sol`. Minters technically don't need to pay the fee, but it is a requirement for editions to appear on sound.xyz.
- Referral fee: TODO
- Current modules:
  - `FixedPricePublicSaleMinter` - Mints tokens at a fixed price.
  - `FixedPricePermissionedSaleMinter` - Mints tokens at a fixed price for buyers approved to buy via signature verification.
  - `RangeEditionMinter` - Mints a quantity of tokens [within a range](https://sound.mirror.xyz/hmz2pueqBV37MD-mULjvch0vQoc-VKJdsfqXf8jTB30). 
  - `MerkleDropMinter` - Enables a predefined list of recipients to mint tokens at a fixed price. The price can be zero and the eligible token quantity for each recipient can be unique. They can claim up to their eligible claimable quantity of tokens for a set of addresses. in multiple transactions.

