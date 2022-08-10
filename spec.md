---
title: Sound Protocol 2.0
description: A permissionless NFT factory which enables customizations for auction formats, payments, metadata, and on-chain registries.
author: Sound Protocol Team
status: Draft
---

## Abstract

Sound Protocol 2.0 enables creators to permissinonlessly deploy gas-efficient minimal, non-upgradeable [721a](https://www.azuki.com/erc721a) proxies from a factory contract. The protocol enables support for customizing auction formats, payments, & metadata.

## Contracts

### `SoundCreatorV1.sol`
- Upgradeable via [UUPSUpgradeable](https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable)
- Deploys [minimal proxies (clones)](https://eips.ethereum.org/EIPS/eip-1167) of `SoundEditionV1.sol` & initializes them with customizable configurations.

### `SoundEditionV1.sol`
- Logic contract for the minimal proxies deployed from SoundCreatorV1.
- Extended version of the [721a implementation](https://www.azuki.com/erc721a) with `ERC721AQueryable` extension.
- Implements [EIP-2981 Royalty Standard](https://eips.ethereum.org/EIPS/eip-2981).
- Implements [EIP-165](https://eips.ethereum.org/EIPS/eip-165).
- Access control
  - Implements OpenZeppelin `OwnableUpgradeable` and `AccessControlUpgradeable` (upgradeable versions of each in order to support the proxy's `initialize` function).
  - Roles can be granted & revoked for addresses. ex: 
    - Minter contracts must have `MINTER_ROLE`.
    - Owner-defined admins must have `ADMIN_ROLE`.
- Implements "module" contracts that augment or override the base functionality for:
  - Metadata - `tokenURI`.
  - Payments - royalties & withdrawals.
  - Minting - multiple auction formats.
- Metadata
  - For on-chain custom metadata `metadataModule` is utilized, which is a contract that implements `IMetadataModule.sol` and provides `tokenURI`.
  - If `metadataModule` is not present, `tokenURI` uses `baseURI`.
  - Implements `contractURI` (https://docs.opensea.io/docs/contract-level-metadata).
  - Allows freezing of metadata, beyond which the variables can't be modified by `owner`.
- Minting
  - `editionMaxMintable` - maximum number of tokens that can be minted for the edition.
  - Authorizes contracts with `MINTER_ROLE` to call `mint`.
  - Authorizes owner or callers with `ADMIN_ROLE` to call `mint`.

### Sound Modules
#### Metadata
  - Metadata modules must implement `IMetadataModule.sol`
  - No implementations included in V1.
#### Minter
- Minter modules must inherit `MintControllerBase.sol`
- Included in V1:
  - `FixedPricePublicSaleMinter` - Mints tokens at a fixed price.
  - `FixedPricePermissionedSaleMinter` - Mints tokens at a fixed price for buyers white-listed via signature verification.
  - `RangeEditionMinter` - Mints a quantity of tokens [within a range](https://sound.mirror.xyz/hmz2pueqBV37MD-mULjvch0vQoc-VKJdsfqXf8jTB30). 
  - `MerkleDropMinter` - Enables a white-list of recipients to mint tokens at a fixed price. The price can be zero and the eligible token quantity for each recipient can be unique. They can claim up to their eligible claimable quantity of tokens for a set of addresses. in multiple transactions.

