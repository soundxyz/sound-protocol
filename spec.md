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
  - Extended version of the [721a implementation](https://www.azuki.com/erc721a)
  - Implements EIP-2981 (`royaltyInfo`)
  - Implements `contractURI` (https://docs.opensea.io/docs/contract-level-metadata)
  - Implements EIP-165 (`supportsInterface)
  - Implements extension contracts for:
    - metadata - `tokenURI`
    - payments - royalties & withdrawals
    - minting 
    - registry management
  
- `SoundXyzRegistryV1.sol`
  - Upgradeable via [UUPSUpgradeable](https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable)
  - Uses OpenZeppelin's draft-EIP712 for replay attack protection
  - Stores registry of NFTs by sound.xyz artists
  - `registerSoundEdition()` Requires 2-party signature to register an NFT: 
    - If NFT `owner` is registering, signature must come from `signingAuthority`
    - If `signingAuthority` is registering, signature must come from `owner`
  - `unregisterSoundNFt()` can be called by NFT `owner` or `signingAuthority`
  - `registerSoundEditions()` & `unregisterSoundEditions()` functions for batch registering & unregistering
  - emits events for registering & unregistering NFTs (both single case & batch case)