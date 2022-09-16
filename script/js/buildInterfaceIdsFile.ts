import "dotenv/config";
import { ensureFile } from "fs-extra";
import { readFile, writeFile } from "fs/promises";

/**
 * Builds an interfaceIds.js file so we can publish the ids as string constants.
 */
async function buildInterfaceIdsFile() {
    const json = await readFile(`src/json/interfaceIds.json`, "utf8");

    const filePath = `src/interfaceIds.ts`;
    await ensureFile(filePath);
    await writeFile(filePath, `export const interfaceIds = ${JSON.stringify(JSON.parse(json))} as const`, "utf-8");
}

await buildInterfaceIdsFile();
