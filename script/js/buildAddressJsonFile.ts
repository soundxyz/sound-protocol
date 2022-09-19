import "dotenv/config";
import { ensureFile } from "fs-extra";
import { readFile, writeFile } from "fs/promises";

/**
 * Extracts addresses from the run-latest.json file and puts them in files that
 * get published to npm.
 */

const supportedNetworks = ["goerli", "mainnet"] as const;

const EVM_NETWORK = process.env.EVM_NETWORK as typeof supportedNetworks[number] | undefined;

if (!EVM_NETWORK || !supportedNetworks.includes(EVM_NETWORK)) {
    console.log("Must specify EVM_NETWORK: " + supportedNetworks.join(" | "));
    process.exit(1);
}

const chainId = EVM_NETWORK == "mainnet" ? 1 : 5;

async function buildAddressJsonFile() {
    const parsedData = await readFile(`broadcast/Deploy.s.sol/${chainId}/run-latest.json`, "utf8").then<{
        transactions: Array<{ contractName: string; function?: unknown; contractAddress: string }>;
    }>(JSON.parse);

    const addresses = parsedData.transactions.reduce<Record<string, string>>((acc, tx) => {
        // If contract name exists but this wasn't a function call, then it's a contract deployment.
        if (tx.contractName && !tx.function) {
            acc[camelize(tx.contractName)] = tx.contractAddress;
        }

        return acc;
    }, {});

    const filePath = `src/json/${EVM_NETWORK}.json`;
    await ensureFile(filePath);
    await writeFile(filePath, JSON.stringify(addresses, null, 2), {});

    function camelize(str: string) {
        return str
            .replace(/(?:^\w|[A-Z]|\b\w)/g, function (word, index) {
                return index === 0 ? word.toLowerCase() : word.toUpperCase();
            })
            .replace(/\s+/g, "");
    }
}

await buildAddressJsonFile();
