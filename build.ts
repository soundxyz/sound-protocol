import makePublishManifestPkg from "@pnpm/exportable-manifest";
import type { ProjectManifest } from "@pnpm/types";
import { buildCode } from "bob-ts";
import { execaCommand } from "execa";
import { copy, ensureDir } from "fs-extra";
import { rm, writeFile } from "fs/promises";
import { extname } from "path";
import pkg from "./package.json";

const makePublishManifest = getDefault(makePublishManifestPkg);

async function main() {
    await rm("dist", {
        force: true,
        recursive: true,
    });

    const tsc = execaCommand("tsc -p tsconfig.build.json", {
        stdio: "inherit",
    });

    await ensureDir("dist");

    await Promise.all([
        copy("LICENSE", "dist/LICENSE"),
        copy("typechain", "dist/typechain", {
            filter(file) {
                if (extname(file) === "") return true;

                return file.endsWith(".d.ts");
            },
        }),
        writeFile(
            "dist/package.json",
            JSON.stringify(
                await makePublishManifest(".", {
                    name: pkg.name,
                    version: pkg.version,
                    main: "index.js",
                    types: "typechain/index.d.ts",
                    dependencies: pkg.dependencies,
                    license: pkg.license,
                    repository: pkg.repository,
                } as ProjectManifest),
                null,
                2
            )
        ),
    ]);

    await buildCode({
        clean: false,
        entryPoints: ["typechain/index.ts"],
        format: "cjs",
        outDir: "dist",
        target: "node14",
        sourcemap: false,
        rollup: {
            exports: "auto",
        },
        external(source) {
            return source.endsWith(".json");
        },
    }),
        await tsc;
}

await main();

function getDefault<T>(v: T | { default?: T }) {
    return (("default" in v ? v.default : v) || v) as T;
}
