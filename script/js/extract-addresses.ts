import "dotenv/config";
import { ensureFile } from "fs-extra";
import { readFile, writeFile } from "fs/promises";

const SOUND_ENV = process.env.SOUND_ENV;

if (!SOUND_ENV) {
    console.log("Must specify SOUND_ENV: preview | staging | mainnet");
    process.exit(1);
}

const chainId = SOUND_ENV == "staging" || SOUND_ENV == "preview" ? 5 : 1;

const buffer = await readFile(`broadcast/Deploy.s.sol/${chainId}/run-latest.json`);
const parsedData = JSON.parse(buffer.toString());

const addresses = {};

parsedData.transactions.forEach((tx) => {
    // If contract name exists but this wasn't a function call, then it's a contract deployment.
    if (tx.contractName && !tx.function) {
        addresses[camelize(tx.contractName)] = tx.contractAddress;
    }
});

const filePath = `src/json/${SOUND_ENV}.json`;
await ensureFile(filePath);
await writeFile(filePath, JSON.stringify(addresses, null, 2), {});

function camelize(str) {
    return str
        .replace(/(?:^\w|[A-Z]|\b\w)/g, function (word, index) {
            return index === 0 ? word.toLowerCase() : word.toUpperCase();
        })
        .replace(/\s+/g, "");
}
