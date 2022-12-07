import { rm, opendir, readdir, lstat, rmdir } from "fs/promises";
import path from "path";

const TYPECHAIN_DIR = "dist/typechain";

export async function pruneTypechain() {
    async function* walk(dir) {
        for await (const d of await opendir(dir)) {
            const entry = path.join(dir, d.name);
            if (d.isDirectory()) yield* walk(entry);
            else if (d.isFile()) yield entry;
        }
    }

    const inclusionStrings = ["sound", "minter", "goldenegg"];
    const exclusionStrings = ["RangeEditionMinterUpdater", "RangeEditionMinterInvariants"];
    for await (const currentPath of walk(TYPECHAIN_DIR)) {
        const fileName = path.basename(currentPath).toLowerCase();

        let foundMatch = false;
        for (const str of inclusionStrings) {
            if (fileName.includes(str.toLowerCase())) {
                foundMatch = true;
                break;
            }
        }

        for (const str of exclusionStrings) {
            if (fileName.includes(str.toLowerCase())) {
                foundMatch = false;
                break;
            }
        }

        if (!foundMatch) {
            await rm(currentPath, {
                force: true,
            });
        }
    }

    await removeEmptyDirectories(TYPECHAIN_DIR);
}

async function removeEmptyDirectories(dir) {
    const fileStats = await lstat(dir);

    if (!fileStats.isDirectory()) {
        return;
    }
    let fileNames = await readdir(dir);
    if (fileNames.length > 0) {
        const recursiveRemovalPromises = fileNames.map((fileName) => removeEmptyDirectories(path.join(dir, fileName)));
        await Promise.all(recursiveRemovalPromises);

        // re-evaluate fileNames; after deleting subdirectory
        // we may have parent directory empty now
        fileNames = await readdir(dir);
    }

    if (fileNames.length === 0) {
        await rmdir(dir);
    }
}
