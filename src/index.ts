import ifaceIds from "./interfaceIds.json";
import anvil from "../broadcast/Seed.s.sol/1337/run-latest.json";
import goerli from "../broadcast/Seed.s.sol/5/run-latest.json";

export const interfaceIds = ifaceIds;

// {[ConctractName]: {[chainId]: contractAddress}}
export const contractAddress = {
    SoundCreatorV1: {
        1: "",
        5: goerli.transactions.find((tx) => tx.contractName == "SoundCreatorV1")?.contractAddress,
        1337: anvil.transactions.find((tx) => tx.contractName == "SoundCreatorV1")?.contractAddress,
    },
    FixedPriceSignatureMinter: {
        1: "",
        5: goerli.transactions.find((tx) => tx.contractName == "FixedPriceSignatureMinter")?.contractAddress,
        1337: anvil.transactions.find((tx) => tx.contractName == "FixedPriceSignatureMinter")?.contractAddress,
    },
    RangeEditionMinter: {
        1: "",
        5: goerli.transactions.find((tx) => tx.contractName == "RangeEditionMinter")?.contractAddress,
        1337: anvil.transactions.find((tx) => tx.contractName == "RangeEditionMinter")?.contractAddress,
    },
    MerkleDropMinter: {
        1: "",
        5: goerli.transactions.find((tx) => tx.contractName == "MerkleDropMinter")?.contractAddress,
        1337: anvil.transactions.find((tx) => tx.contractName == "MerkleDropMinter")?.contractAddress,
    },
};
