# Sound Protocol

### Specification

See [spec](./spec.md) for current spec.

# Installation

## Prerequisites

- [git](https://git-scm.com/downloads)
- [nodeJS](https://nodejs.org/en/download/)
- [node version manager](https://github.com/nvm-sh/nvm)
- [pnpm](https://pnpm.io/) - You need to have `pnpm` installed globally, you can run `npm i -g pnpm` to install it.
- [brew](https://brew.sh/)
- [foundry](https://getfoundry.sh) - You can run `sh ./setup.sh` to install Foundry and its dependencies.

## Setup

- Clone the repository

```bash
git clone git@github.com:soundxyz/sound-protocol.git
cd sound-protocol
```

- Setup node version
Either install the version specified in `nvmrc` or use `nvm` to set it up:

```
nvm use
```

- Install packages
```
pnpm install
```

- Build contracts
```
pnpm build
```

- Run tests
```
pnpm run test
```

- Print gas reports from tests
```
pnpm test:gas
```

## Code conventions

We generally follow OpenZeppelin's conventions:

- Underscore `_before` private variables.
- Underscore `after_` function arguments which shadow globals.
- [Natspec](https://docs.soliditylang.org/en/develop/natspec-format.html) format for comments, using `@dev` for function descriptions.

To run prettier on all solidity files, uncomment the last line in `.prettierrc.js`, then run `npx prettier --write ./contracts/**/*.sol`

## Deployment

Create a .env in the root with:
```
PRIVATE_KEY=...
ETHERSCAN_KEY=...
# Make one of these for every network
GOERLI_RPC_URL=...
```

Then run:
```
source .env && forge script scripts/Deploy.s.sol:Deploy --rpc-url $<NETWORK>_RPC_URL  --private-key $PRIVATE_KEY --broadcast
```

According to the foundry docs, we _should_ be able to verify on etherscan by appending this to the above command: ` --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv`, but that doesn't seem to work. Instead, we can verify each contract individually. Ex:

```
forge verify-contract --chain-id 5 --num-of-optimizations 200 --compiler-version v0.8.15 0x4613283c53669847c40eb0cf7946f1fb30b1f030 contracts/modules/Metadata/GoldenEggMetadataModule.sol:GoldenEggMetadataModule
```