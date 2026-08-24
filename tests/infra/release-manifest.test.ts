import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import {
  createReleaseManifest,
  releaseManifestSchema,
  writeReleaseManifest,
} from "../../scripts/infra/release-manifest.mjs";

const temporaryRoots: string[] = [];

async function createRoot(): Promise<string> {
  const root = await mkdtemp(join(tmpdir(), "risepals-release-manifest-test-"));
  temporaryRoots.push(root);
  await mkdir(join(root, "assets"));
  await writeFile(join(root, "server.js"), "server\n", "utf8");
  await writeFile(join(root, "assets", "app.js"), "asset\n", "utf8");
  return root;
}

const metadata = {
  sourceCommit: "a".repeat(40),
  releaseId: "rehearsal-a",
  nodeVersion: "24.18.1",
  npmVersion: "11.16.0",
  nextVersion: "16.2.12",
  configurationTemplateVersion: "windows-infra-v1",
};

afterEach(async () => {
  await Promise.all(
    temporaryRoots.splice(0).map((root) => rm(root, { force: true, recursive: true })),
  );
});

describe("release manifest", () => {
  it("produces stable sorted inventory and digest", async () => {
    const root = await createRoot();
    const first = await createReleaseManifest({ root, ...metadata });
    const second = await createReleaseManifest({ root, ...metadata });

    expect(first).toEqual(second);
    expect(first.schemaVersion).toBe(releaseManifestSchema);
    expect(first.files.map((file) => file.path)).toEqual(["assets/app.js", "server.js"]);
    expect(first.inventoryDigest).toMatch(/^[a-f0-9]{64}$/);
  });

  it("writes byte-identical output on repeated generation", async () => {
    const root = await createRoot();
    await writeReleaseManifest({ root, ...metadata });
    const first = await readFile(join(root, "release-manifest.json"));
    await writeReleaseManifest({ root, ...metadata });
    const second = await readFile(join(root, "release-manifest.json"));
    expect(second).toEqual(first);
  });

  it.each([".env.local", "credential.pem", "private.key"])(
    "rejects prohibited release material: %s",
    async (name) => {
      const root = await createRoot();
      await writeFile(join(root, name), "synthetic-only", "utf8");
      await expect(createReleaseManifest({ root, ...metadata })).rejects.toThrow(
        /Prohibited release entry/,
      );
    },
  );

  it("requires complete version and source metadata", async () => {
    const root = await createRoot();
    await expect(createReleaseManifest({ root, ...metadata, sourceCommit: "" })).rejects.toThrow(
      "sourceCommit is required",
    );
  });
});
