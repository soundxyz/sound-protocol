import interfaceIds from "./interfaceIds.json";
import stagingDeployment from "./staging.json";
import previewDeployment from "./preview.json";

const contractAddresses = {
    staging: {
        SoundCreatorV1: stagingDeployment.transactions.find((tx) => tx.contractName === "SoundCreatorV1")
            ?.contractAddress,
        FixedPriceSignatureMinter: stagingDeployment.transactions.find(
            (tx) => tx.contractName === "FixedPriceSignatureMinter"
        )?.contractAddress,
        RangeEditionMinter: stagingDeployment.transactions.find((tx) => tx.contractName === "RangeEditionMinter")
            ?.contractAddress,
        MerkleDropMinter: stagingDeployment.transactions.find((tx) => tx.contractName === "MerkleDropMinter")
            ?.contractAddress,
        GoldenEggMetadata: stagingDeployment.transactions.find((tx) => tx.contractName === "GoldenEggMetadata")
            ?.contractAddress,
        SoundFeeRegistry: stagingDeployment.transactions.find((tx) => tx.contractName === "SoundFeeRegistry")
            ?.contractAddress,
    },
    preview: {
        SoundCreatorV1: previewDeployment.transactions.find((tx) => tx.contractName === "SoundCreatorV1")
            ?.contractAddress,
        FixedPriceSignatureMinter: previewDeployment.transactions.find(
            (tx) => tx.contractName === "FixedPriceSignatureMinter"
        )?.contractAddress,
        RangeEditionMinter: previewDeployment.transactions.find((tx) => tx.contractName === "RangeEditionMinter")
            ?.contractAddress,
        MerkleDropMinter: previewDeployment.transactions.find((tx) => tx.contractName === "MerkleDropMinter")
            ?.contractAddress,
        GoldenEggMetadata: previewDeployment.transactions.find((tx) => tx.contractName === "GoldenEggMetadata")
            ?.contractAddress,
        SoundFeeRegistry: previewDeployment.transactions.find((tx) => tx.contractName === "SoundFeeRegistry")
            ?.contractAddress,
    },
};

export { interfaceIds, contractAddresses };
