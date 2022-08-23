/**
 * This script builds a folder of only the contract artifacts
 * built by forge that we want to include in the typechain dir
 */

import { copy, ensureDir } from "fs-extra";
import { rm } from "fs/promises";

const sourceDir = "out/";
const destDir = "out-sound/";

const soundContracts = [
    "BaseMinter.sol",
    "GoldenEggMetadata.sol",
    "MerkleDropMinter.sol",
    "FixedPriceSignatureMinter.sol",
    "RangeEditionMinter.sol",
    "SoundCreatorV1.sol",
    "SoundEditionV1.sol",
    "IMinterModule.sol",
    "IMetadataModule.sol",
    "IMerkleDropMinter.sol",
    "IFixedPriceSignatureMinter.sol",
    "IRangeEditionMinter.sol",
    "ISoundEditionV1.sol",
];

await rm(destDir, {
    force: true,
    recursive: true,
});

await ensureDir(destDir);

await Promise.all(
    soundContracts.map((contractName) => {
        return copy(sourceDir + contractName, destDir + contractName);
    })
);
