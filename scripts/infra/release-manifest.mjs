import { createHash } from "node:crypto";
import { lstat, readdir, readFile, rename, rm, writeFile } from "node:fs/promises";
import { basename, join, relative, resolve, sep } from "node:path";
import { pathToFileURL } from "node:url";

export const releaseManifestSchema = "rise-pals-release-manifest-v1";

const prohibitedSegments = new Set([
  ".env",
  ".env.local",
  ".git",
  ".next-clerk-development-smoke",
  "coverage",
  "playwright-report",
  "test-results",
]);

const prohibitedExtensions = new Set([".key", ".p12", ".pem", ".pfx"]);

function normalizeRelativePath(path) {
  return path.split(sep).join("/");
}

function assertSafeRelativePath(path) {
  const segments = path.split("/");
  const extension = path.slice(path.lastIndexOf(".")).toLowerCase();

  if (
    segments.some((segment) => prohibitedSegments.has(segment.toLowerCase())) ||
    prohibitedExtensions.has(extension)
  ) {
    throw new Error(`Prohibited release entry: ${path}`);
  }
}

async function collectFiles(root, directory = root) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];

  for (const entry of entries.sort((left, right) => left.name.localeCompare(right.name, "en"))) {
    const absolutePath = join(directory, entry.name);
    const relativePath = normalizeRelativePath(relative(root, absolutePath));

    if (relativePath === "release-manifest.json" || relativePath === ".next/cache") {
      continue;
    }

    assertSafeRelativePath(relativePath);

    if (entry.isSymbolicLink()) {
      throw new Error(`Unexpected link in release inventory: ${relativePath}`);
    }
    if (entry.isDirectory()) {
      files.push(...(await collectFiles(root, absolutePath)));
      continue;
    }
    if (!entry.isFile()) {
      throw new Error(`Unexpected release entry type: ${relativePath}`);
    }

    const content = await readFile(absolutePath);
    files.push(
      Object.freeze({
        path: relativePath,
        length: content.byteLength,
        sha256: createHash("sha256").update(content).digest("hex"),
      }),
    );
  }

  return files;
}

export async function createReleaseManifest(input) {
  const root = resolve(input.root);
  const rootStat = await lstat(root);
  if (!rootStat.isDirectory() || rootStat.isSymbolicLink()) {
    throw new Error("Release root must be a real directory.");
  }

  for (const [name, value] of Object.entries({
    sourceCommit: input.sourceCommit,
    releaseId: input.releaseId,
    nodeVersion: input.nodeVersion,
    npmVersion: input.npmVersion,
    nextVersion: input.nextVersion,
    configurationTemplateVersion: input.configurationTemplateVersion,
  })) {
    if (typeof value !== "string" || value.trim() === "") {
      throw new Error(`${name} is required.`);
    }
  }

  const files = await collectFiles(root);
  const inventoryDigest = createHash("sha256").update(JSON.stringify(files)).digest("hex");

  return Object.freeze({
    schemaVersion: releaseManifestSchema,
    sourceCommit: input.sourceCommit,
    releaseId: input.releaseId,
    runtime: Object.freeze({
      node: input.nodeVersion,
      npm: input.npmVersion,
      next: input.nextVersion,
    }),
    configurationTemplateVersion: input.configurationTemplateVersion,
    inventoryDigest,
    files,
  });
}

export async function writeReleaseManifest(input) {
  const root = resolve(input.root);
  const manifest = await createReleaseManifest(input);
  const destination = join(root, "release-manifest.json");
  const temporary = join(root, `.release-manifest-${process.pid}.tmp`);
  const serialized = `${JSON.stringify(manifest, null, 2)}\n`;

  try {
    const existing = await readFile(destination, "utf8");
    if (existing === serialized) {
      return manifest;
    }
    throw new Error("An existing release manifest does not match the deterministic inventory.");
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
  }
  await writeFile(temporary, serialized, { encoding: "utf8", flag: "wx" });
  try {
    await rename(temporary, destination);
  } catch (error) {
    await rm(temporary, { force: true });
    throw error;
  }
  return manifest;
}

function parseArguments(arguments_) {
  const values = new Map();
  for (let index = 0; index < arguments_.length; index += 2) {
    const key = arguments_[index];
    const value = arguments_[index + 1];
    if (!key?.startsWith("--") || value === undefined) {
      throw new Error("Release manifest arguments must be --name value pairs.");
    }
    values.set(key.slice(2), value);
  }
  return Object.fromEntries(values);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const arguments_ = parseArguments(process.argv.slice(2));
  const manifest = await writeReleaseManifest({
    root: arguments_.root,
    sourceCommit: arguments_["source-commit"],
    releaseId: arguments_["release-id"],
    nodeVersion: arguments_["node-version"],
    npmVersion: arguments_["npm-version"],
    nextVersion: arguments_["next-version"],
    configurationTemplateVersion: arguments_["configuration-template-version"],
  });
  process.stdout.write(
    `Release manifest PASS: ${basename(resolve(arguments_.root))}, ${manifest.files.length} files, ${manifest.inventoryDigest}\n`,
  );
}
