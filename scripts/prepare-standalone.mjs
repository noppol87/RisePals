import { cp, mkdir, readdir, stat } from "node:fs/promises";
import { resolve } from "node:path";

const outputRoot = resolve(".next/standalone");
const server = resolve(outputRoot, "server.js");
const staticSource = resolve(".next/static");
const staticDestination = resolve(outputRoot, ".next/static");
const publicSource = resolve("public");
const publicDestination = resolve(outputRoot, "public");

async function requireFile(path, description) {
  const details = await stat(path).catch(() => undefined);
  if (!details?.isFile()) {
    throw new Error(`${description} is unavailable.`);
  }
}

async function requireDirectory(path, description) {
  const details = await stat(path).catch(() => undefined);
  if (!details?.isDirectory()) {
    throw new Error(`${description} is unavailable.`);
  }
}

await requireFile(server, "Next.js standalone server");
await requireDirectory(staticSource, "Next.js static output");
await mkdir(resolve(outputRoot, ".next"), { recursive: true });
await cp(staticSource, staticDestination, { force: true, recursive: true });

const publicDetails = await stat(publicSource).catch(() => undefined);
if (publicDetails?.isDirectory()) {
  await cp(publicSource, publicDestination, { force: true, recursive: true });
}

const pending = [outputRoot];
let fileCount = 0;

while (pending.length > 0) {
  const directory = pending.pop();
  const entries = await readdir(directory, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.name === ".env" || entry.name.startsWith(".env.")) {
      throw new Error("Standalone output contains a forbidden environment file.");
    }
    if (entry.isDirectory()) {
      pending.push(resolve(directory, entry.name));
    } else if (entry.isFile()) {
      fileCount += 1;
    }
  }
}

console.log(
  `Standalone runtime preparation PASS: ${fileCount} files inventoried; no environment files.`,
);
