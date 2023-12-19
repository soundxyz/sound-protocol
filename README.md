# Sound Protocol

Sound Protocol is a generalized platform for flexible and efficient creation of NFT drops.

## Table of Contents

- [Sound Protocol](#sound-protocol)
  - [Table of Contents](#table-of-contents)
  - [Deployments](#deployments)
  - [Contracts](#contracts)
  - [Documentation](#documentation)
  - [Development](#development)
  - [Deploying](#deploying)
  - [Bug Bounty](#bug-bounty)
  - [License](#license)

## Deployments

The following contracts have been deployed on Mainnet, Optimism, Goerli, Optimism-Goerli, and Sepolia.

| Contract  |  Address |
|---|---|
| `SoundEditionV2_1` | `0x000000000000Be2397A709213a10cf71b07f42eE`
| `SoundCreatorV2` | `0x0000000000aec84F5BFc2af15EAfb943bf4e3522`
| `SuperMinterV2` | `0x000000000001A36777f9930aAEFf623771b13e70`
| `SoundOnChainMetadata` | `0x0000000000724868d80283B098Ffa809B2181692`
| `SoundMetadata` | `0x0000000000f5A96Dc85959cAeb0Cfe680f108FB5`

## Architecture

The latest Sound Protocol comprises of several components: 

- **`SoundEditionV2_1`**  

  The NFT contract.

  An [ERC721A](https://github.com/chiru-labs/ERC721A) contract deployed via the [minimal proxy clone](https://eips.ethereum.org/EIPS/eip-1167) pattern.

  The `mint` function allows authorized minter contracts or administrators to batch mint NFTs  
  (authorization is granted via the `MINTER_ROLE` or `ADMIN_ROLE`).

- **`SoundCreatorV2`** 

  A factory that allows for a single transaction setup that:
  1. Clones and initializes a `SoundEdition`.
  2. Forwards calldata to an array of target contracts. These calldata can be used to set up the required authorizations and mint schedules.

- **`SuperMinterV2`**

  A generalized singleton minter contract that can mint on `SoundEdition`s.

  Technically, any contract can be authorized to mint on a `SoundEdition` as long as they are granted the `MINTER_ROLE`.

- **`SoundMetadata`**

  A contract which is called by the `SoundEdition` in the `tokenURI` function for customizable metadata logic. The on-chain JSON variant is called `SoundOnChainMetadata`.


## Contracts

The smart contracts are stored under the `contracts` directory.

These are the contracts currently used.

The actual directories may contain some older contracts not on the list ─ they are left there for backwards compatibility.

```ml
contracts
├── core
│   ├── SoundCreatorV2.sol ─ "Factory"
│   ├── SoundEditionV2_1.sol ─ "NFT implementation"
│   ├── interfaces
│   │   ├── ISoundCreatorV2.sol
│   │   └── ISoundEditionV2_1.sol
│   └── utils
│       ├── MintRandomnessLib.sol ─ "Library for on-chain 1-of-1 raffle"
│       ├── LibOps.sol ─ "Library for common operations"
│       └── ArweaveURILib.sol ─ "For efficient storage of Arweave URIs"
└── modules
    ├── SuperMinterV2.sol ─ "Generalized minter"
    ├── SoundMetadata.sol ─ "Metadata module for SoundEdition"
    ├── SoundOnChainMetadata.sol ─ "On-chain variant of SoundMetadata"
    ├── interfaces
    │   ├── ISuperMinterV2.sol
    │   ├── ISoundMetadata.sol
    │   └── ISoundOnChainMetadata.sol
    └── utils
        ├── DelegateCashLib.sol ─ "Library for querying DelegateCash"
        └── SoundOnChainMetadataLib.sol ─ "Library for SoundOnChainMetadata"
```

## Documentation

The documentation for the latest contracts is under construction.

For now, you can refer to the Natspec.

## Development

This is a [foundry](https://getfoundry.sh) based project. 

However, some of the directories differ from the defaults. 

- The contracts are under `contracts`.
- The tests are under `tests`.

## Deploying

The contracts have already been deployed to their canonical addresses.

If you need them on any other EVM based chain, please look into `build_create2_deployments.sh`.

## Bug Bounty

Up to 10 ETH for any critical bugs that could result in loss of funds. Rewards will be given for smaller bugs or ideas.

## License

[MIT](LICENSE) Copyright 2023 Sound.xyz
