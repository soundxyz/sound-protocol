import ifaceIds from "./interfaceIds.json";
import goerli from "../broadcast/Seed.s.sol/5/run-latest.json";

export const interfaceIds = ifaceIds;

export const addresses = {
    SoundCreatorV1: {
        // Key is chainId
        1: "",
        5: goerli.transactions.find((tx) => tx.contractName == "SoundCreatorV1")?.contractAddress,
    },
};
