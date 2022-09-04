import ifaceIds from "./interfaceIds.json";
import goerli from "../broadcast/Seed.s.sol/5/run-latest.json";

export const interfaceIds = ifaceIds;

export const contractAddress = {
    SoundCreatorV1: {
        // [chainId]: contractAddress
        1: "",
        5: goerli.transactions.find((tx) => tx.contractName == "SoundCreatorV1")?.contractAddress,
    },
};
