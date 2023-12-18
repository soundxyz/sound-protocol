# @soundxyz/sound-protocol

## 1.8.0

### Minor Changes

-   4ab84ed: SuperMinterV2 et al.

## 1.7.0

### Minor Changes

-   ca0bb9a: Add platformFeeBPS and platformPerTxFlatFee to SAMInfo

## 1.6.0

### Minor Changes

-   b56a0fb: Platform flat transaction fee support

## 1.5.0

### Minor Changes

-   238caaa: MintersV2

## 1.4.0

### Minor Changes

-   ada3ba9: Sound Edition V1.2, w/ SAM

### Patch Changes

-   141415c: - Replaces mainnet.json & goerli.json with CONTRACT_ADDRESSES
    -   Fixes incorrect mainnet addresses for merkleDropMinter & rangeEditionMinter

## 1.3.0

### Minor Changes

-   f0b7c84: Adds pruneArtifacts script

### Patch Changes

-   855d919: Nukes buildAddresses script

## 1.2.0

### Minor Changes

-   e08b00c: Missed version bump

## 1.1.1

### Patch Changes

-   270d7ab: SoundEditionV1_1
    -   Implements the interface for OpenSea's Mandatory Operator Filterer for royalties via ClosedSea
    -   Security enhancements for Golden egg computations
    -   Adds some additional events for ETHWithdrawn, ERC20Withdrawn, Minted, and Airdropped
    -   Cleans up some assembly logic into a library

## 1.1.0

### Minor Changes

-   776aa88: Updates addresses json with free minters

## 1.0.0

### Major Changes

-   4601b9a: Sound Protocol mainnet deployment ✨

### Patch Changes

-   3ec95f8: Readme cleanup

## 0.5.1

### Patch Changes

-   73e2575: Updates interfaceIds
-   8b9fd08: Add two step ownership transfer via OwnableRoles to Registry and Creator

## 0.5.0

### Minor Changes

-   572cf0e: Removes preview & staging address files & updates scripts

### Patch Changes

-   572cf0e: Change to MIT License
-   06dc842: Use \_numberMinted on edition instead of tally on minter

## 0.4.7

### Patch Changes

-   6175acd: update preview and staging

## 0.4.6

### Patch Changes

-   b70af1c: SoundEditionCreated emits full payload

## 0.4.5

### Patch Changes

-   66e0d1e: Deploys latest to preview and staging

## 0.4.4

### Patch Changes

-   a43b305: Update interfaces

## 0.4.3

### Patch Changes

-   86202d8: Add maxMintableInfo to Edition and use in mintInfo of PublicSaleMinter

## 0.4.2

### Patch Changes

-   80b7963: Updating correct interfaceids file

## 0.4.1

### Patch Changes

-   25ac037: Add PublicSaleMinter interface

## 0.4.0

### Minor Changes

-   efafbc7: Bump

## 0.3.1

### Patch Changes

-   c86d481: createSoundAndMints returns the soundEdition address
-   2b0f61f: Add temporal max quantity to Edition, add PublicSaleMinter
-   c86d481: Return if soundEditionAddress exists
-   c86d481: updating interfaces

## 0.3.0

### Minor Changes

-   c7bb268: Fixes prepack script & deploys latest contracts on staging/preview

## 0.2.1

### Patch Changes

-   40a783f: Adds buyer address to IMinterModule.Minted event

## 0.2.0

### Minor Changes

-   38f9ed4: typechain fix
-   5a4e8f9: Add sound fee registry
-   5a4e8f9: Add platform and referral fees
-   5a4e8f9: Add platform and affiliate fees in minters
-   f535fd4: Removing baseMintData function

### Patch Changes

-   7111f1b: Exporting staging & preview goerli addresses
-   a5538d1: Ensures we generate interfaceIds before publishing, and export them as string constants.
-   be74b76: Latest deployment
