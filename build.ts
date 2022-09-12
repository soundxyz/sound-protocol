import makePublishManifestPkg from "@pnpm/exportable-manifest";
import type { ProjectManifest } from "@pnpm/types";
import { buildCode } from "bob-ts";
import { execaCommand } from "execa";
import { copy, ensureDir } from "fs-extra";
import { rm, writeFile } from "fs/promises";
import pkg from "./package.json";

const makePublishManifest = getDefault(makePublishManifestPkg);

await rm("dist", {
    force: true,
    recursive: true,
});

await copy("typechain", "src/typechain");

const tsc = execaCommand("tsc -p tsconfig.build.json", {
    stdio: "inherit",
});

await ensureDir("dist");

await Promise.all([
    copy("LICENSE", "dist/LICENSE"),
    copy("contracts", "dist/contracts"),
    writeFile(
        "dist/package.json",
        JSON.stringify(
            await makePublishManifest(".", {
                name: pkg.name,
                version: pkg.version,
                author: pkg.author,
                homepage: pkg.homepage,
                main: "index.js",
                module: "index.mjs",
                types: "index.d.ts",
                dependencies: pkg.dependencies,
                license: pkg.license,
                repository: pkg.repository,
                sideEffects: false,
                exports: {
                    ".": {
                        types: "./index.d.ts",
                        require: "./index.js",
                        import: "./index.mjs",
                    },
                    "./typechain": {
                        types: "./typechain/index.d.ts",
                        require: "./typechain/index.js",
                        import: "./typechain/index.mjs",
                    },
                    "./*": {
                        types: "./*.d.ts",
                        require: "./*.js",
                        import: "./*.mjs",
                    },
                },
            } as ProjectManifest),
            null,
            2
        )
    ),
]);

await buildCode({
    clean: false,
    entryPoints: ["src"],
    format: "interop",
    outDir: "dist",
    target: "node14",
    sourcemap: false,
    rollup: {
        exports: "auto",
    },
});

await tsc;

await rm("src/typechain", {
    recursive: true,
    force: true,
});

function getDefault<T>(v: T | { default?: T }) {
    return (("default" in v ? v.default : v) || v) as T;
}
