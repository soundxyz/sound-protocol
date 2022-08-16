---
title: Sound Protocol 2.0
description: A permissionless NFT factory which enables customizations for auction formats, payments, metadata, and on-chain registries.
author: Sound Protocol Team
status: Draft
---

## Abstract

Sound Protocol 2.0 enables creators to permissinonlessly deploy gas-efficient NFTs (minimal, non-upgradeable proxies) from a factory contract. Initially, the NFTs will follow the 721a format. The protocol enables support for customizing auction formats, payments, metadata, and on-chain registry management.

## Contracts

- `SoundCreatorV1.sol`
  - Upgradeable via [UUPSUpgradeable](https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable)
  - Deploys [minimal proxies (clones)](https://eips.ethereum.org/EIPS/eip-1167) of `SoundEditionV1.sol` & initializes them with customizable configurations.

- `SoundEditionV1.sol`
  - Logic contract for the proxies deployed from SoundCreatorV1
  - Extended version of the [721a implementation](https://www.azuki.com/erc721a) with:
    - `ERC721AQueryableUpgradeable` - adds convenient query functions
    - `ERC721ABurnableUpgradeable` - adds token burn functionality
  - Implements EIP-2981 (`royaltyInfo`)
  - Implements EIP-165 (`supportsInterface)
  - Implements extension contracts for:
    - metadata - `tokenURI`
    - payments - royalties & withdrawals
    - minting 
    - registry management
  - Metadata
    - For on-chain custom metadata `metadataModule` is utilized, which is a contract that inherits from `IMetadataModule.sol` and provides `tokenURI`
    - `tokenURI` uses `baseURI` instead, if `metadataModule` is not present
    - Implements `contractURI` (https://docs.opensea.io/docs/contract-level-metadata)
    - Allows freezing of metadata, beyond which the variables can't be modified by `owner`
  - Minters
    - Allows authorized minting contracts (Minters) to call the `mint(address to, uint256 quantity)` function.
    - To authorize a minter, the owner must call the `grantRole(MINTER_ROLE, minter)` function.
  
- `SoundXyzRegistryV1.sol`
  - Upgradeable via [UUPSUpgradeable](https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable)
  - Stores registry of NFTs by sound.xyz artists
  - Requires signature from sound.xyz to register NFTs

- `modules/Minters/**.sol`
  - Currently only allows creation and deletion of edition mints.
  - We may want to add a feature to restrict the total number of mints per wallet in the future.
  - We may want to allow edition mint controllers to directly edit the fields in the future.
