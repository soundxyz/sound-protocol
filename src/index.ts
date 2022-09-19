import goerli from "./json/goerli.json";
import mainnet from "./json/mainnet.json";
import { interfaceIds } from "./interfaceIds";

const contractAddresses = {
    goerli,
    mainnet,
} as const;

export { interfaceIds, contractAddresses };
