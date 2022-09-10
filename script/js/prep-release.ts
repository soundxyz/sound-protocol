import "dotenv/config";
import { ensureFile } from "fs-extra";
import { readFile, writeFile } from "fs/promises";
import { requireEnv } from "require-env-variable";

type ObjectOfStrings = Record<string, string>;

const { SOUND_ENV, CREATOR_TYPE } = requireEnv("SOUND_ENV", "CREATOR_TYPE");

const allowedEnv = ["preview", "staging", "mainnet"];
const allowedSoundTypes = ["single", "album"];

if (!allowedEnv.includes(SOUND_ENV)) {
    throw new Error(`Invalid SOUND_ENV: ${SOUND_ENV}`);
}
if (!allowedSoundTypes.includes(CREATOR_TYPE)) {
    throw new Error(`Invalid CREATOR_TYPE: ${CREATOR_TYPE}`);
}

const chainId = SOUND_ENV == "staging" || SOUND_ENV == "preview" ? 5 : 1;

/**
 * Extracts addresses from the run-latest.json file and puts them in files that
 * get published to npm.
 */
async function buildAddressJsonFile() {
    const parsedData = await readFile(`broadcast/Deploy.s.sol/${chainId}/run-latest.json`, "utf8").then<{
        transactions: Array<{ contractName: string; function?: unknown; contractAddress: string }>;
    }>(JSON.parse);

    const addresses = parsedData.transactions.reduce<ObjectOfStrings>((acc, tx) => {
        // If contract name exists but this wasn't a function call, then it's a contract deployment.
        if (tx.contractName && !tx.function) {
            acc[camelize(tx.contractName)] = tx.contractAddress;
        }

        return acc;
    }, {});

    const filePath = `src/json/${SOUND_ENV}.json`;
    const formattedAddresses = await readFile(filePath, "utf8").then<ObjectOfStrings>(JSON.parse);

    for (const [key, value] of Object.entries(addresses)) {
        if (key === "soundCreatorV1") {
            formattedAddresses[key][CREATOR_TYPE as string] = value;
        } else {
            formattedAddresses[key] = value;
        }
    }

    console.log(formattedAddresses);

    await ensureFile(filePath);
    await writeFile(filePath, JSON.stringify(formattedAddresses, null, 2), {});

    function camelize(str: string) {
        return str
            .replace(/(?:^\w|[A-Z]|\b\w)/g, function (word, index) {
                return index === 0 ? word.toLowerCase() : word.toUpperCase();
            })
            .replace(/\s+/g, "");
    }
}

/**
 * Builds an interfaceIds.js file so we can publish the ids as string constants.
 */
async function buildInterfaceIdsFile() {
    const json = await readFile(`src/json/interfaceIds.json`, "utf8");

    const filePath = `src/interfaceIds.ts`;
    await ensureFile(filePath);
    await writeFile(filePath, `export const interfaceIds = ${JSON.stringify(JSON.parse(json))} as const`, "utf-8");
}

await buildAddressJsonFile();
await buildInterfaceIdsFile();
