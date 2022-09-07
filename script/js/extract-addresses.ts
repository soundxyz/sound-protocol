import "dotenv/config";
import { ensureFile } from "fs-extra";
import { readFile, writeFile } from "fs/promises";

const allowedEnv = ["preview", "staging", "mainnet"] as const;

const SOUND_ENV = process.env.SOUND_ENV as typeof allowedEnv[number] | undefined;

if (!SOUND_ENV || !allowedEnv.includes(SOUND_ENV)) {
    console.log("Must specify SOUND_ENV: preview | staging | mainnet");
    process.exit(1);
}

const chainId = SOUND_ENV == "staging" || SOUND_ENV == "preview" ? 5 : 1;

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

const filePath = `src/json/${SOUND_ENV}.json`;
await ensureFile(filePath);
await writeFile(filePath, JSON.stringify(addresses, null, 2), {});

function camelize(str: string) {
    return str
        .replace(/(?:^\w|[A-Z]|\b\w)/g, function (word, index) {
            return index === 0 ? word.toLowerCase() : word.toUpperCase();
        })
        .replace(/\s+/g, "");
}
