import interfaceIds from "./interfaceIds.json";
import stagingDeployment from "./staging.json";
import previewDeployment from "./preview.json";

const contractAddresses = {
    staging: {
        soundCreatorV1: stagingDeployment.transactions.find((tx) => tx.contractName === "SoundCreatorV1")
            ?.contractAddress,
        fixedPriceSignatureMinter: stagingDeployment.transactions.find(
            (tx) => tx.contractName === "FixedPriceSignatureMinter"
        )?.contractAddress,
        rangeEditionMinter: stagingDeployment.transactions.find((tx) => tx.contractName === "RangeEditionMinter")
            ?.contractAddress,
        merkleDropMinter: stagingDeployment.transactions.find((tx) => tx.contractName === "MerkleDropMinter")
            ?.contractAddress,
        goldenEggMetadata: stagingDeployment.transactions.find((tx) => tx.contractName === "GoldenEggMetadata")
            ?.contractAddress,
        soundFeeRegistry: stagingDeployment.transactions.find((tx) => tx.contractName === "SoundFeeRegistry")
            ?.contractAddress,
    },
    preview: {
        soundCreatorV1: previewDeployment.transactions.find((tx) => tx.contractName === "SoundCreatorV1")
            ?.contractAddress,
        fixedPriceSignatureMinter: previewDeployment.transactions.find(
            (tx) => tx.contractName === "FixedPriceSignatureMinter"
        )?.contractAddress,
        rangeEditionMinter: previewDeployment.transactions.find((tx) => tx.contractName === "RangeEditionMinter")
            ?.contractAddress,
        merkleDropMinter: previewDeployment.transactions.find((tx) => tx.contractName === "MerkleDropMinter")
            ?.contractAddress,
        goldenEggMetadata: previewDeployment.transactions.find((tx) => tx.contractName === "GoldenEggMetadata")
            ?.contractAddress,
        soundFeeRegistry: previewDeployment.transactions.find((tx) => tx.contractName === "SoundFeeRegistry")
            ?.contractAddress,
    },
};

export { interfaceIds, contractAddresses };
