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

const tsc = execaCommand("tsc -p tsconfig.build.json", {
    stdio: "inherit",
});

await ensureDir("dist");

await Promise.all([
    copy("LICENSE", "dist/LICENSE"),
    writeFile(
        "dist/package.json",
        JSON.stringify(
            await makePublishManifest(".", {
                name: pkg.name,
                version: pkg.version,
                author: pkg.author,
                homepage: pkg.homepage,
                main: "index.js",
                types: "index.d.ts",
                dependencies: pkg.dependencies,
                license: pkg.license,
                repository: pkg.repository,
                exports: {
                    ".": {
                        types: "./index.d.ts",
                        require: "./index.js",
                        import: "./index.mjs",
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
    entryPoints: ["typechain/**/*.ts"],
    format: "interop",
    outDir: "dist/typechain",
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

function getDefault<T>(v: T | { default?: T }) {
    return (("default" in v ? v.default : v) || v) as T;
}
