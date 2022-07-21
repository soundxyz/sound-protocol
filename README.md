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

## Code conventions

To run prettier on all solidity files, uncomment the last line in `.prettierrc.js`, then run `npx prettier --write ./contracts/**/*.sol`
pnpm test
```
