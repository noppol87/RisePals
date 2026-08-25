import { readFile } from "node:fs/promises";
import { request } from "node:https";
import { pathToFileURL } from "node:url";

function parseArguments(values) {
  const parsed = { headers: [] };
  for (let index = 0; index < values.length; index += 2) {
    const name = values[index];
    const value = values[index + 1];
    if (!name?.startsWith("--") || value === undefined) {
      throw new Error("Probe arguments must be --name value pairs.");
    }
    const key = name.slice(2);
    if (key === "header") parsed.headers.push(value);
    else if (Object.hasOwn(parsed, key)) throw new Error(`Duplicate probe argument: ${name}`);
    else parsed[key] = value;
  }
  return parsed;
}

function parseBoundedInteger(value, name, minimum, maximum) {
  if (!/^(0|[1-9][0-9]*)$/.test(value ?? "")) {
    throw new Error(`${name} must be a decimal integer.`);
  }
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < minimum || parsed > maximum) {
    throw new Error(`${name} is outside its approved range.`);
  }
  return parsed;
}

function parseHeaders(values) {
  const headers = Object.create(null);
  for (const value of values) {
    const separator = value.indexOf(":");
    if (separator < 1) throw new Error("Probe headers must use Name: Value syntax.");
    const name = value.slice(0, separator).trim();
    const content = value.slice(separator + 1).trim();
    if (!/^[A-Za-z0-9-]+$/.test(name) || /[\r\n]/.test(content)) {
      throw new Error("Probe header syntax is invalid.");
    }
    headers[name] = content;
  }
  return headers;
}

export async function runLoopbackHttpsProbe(input) {
  const url = new URL(input.url);
  if (
    url.protocol !== "https:" ||
    url.hostname !== "127.0.0.1" ||
    url.port !== "8443" ||
    url.username !== "" ||
    url.password !== ""
  ) {
    throw new Error("The probe URL must be the exact approved loopback HTTPS endpoint.");
  }
  const ca = await readFile(input.ca);
  const expectedStatus = parseBoundedInteger(input.status, "status", 100, 599);
  const bodyBytes = parseBoundedInteger(input["body-bytes"] ?? "0", "body-bytes", 0, 1_048_577);
  const maximumFirstByteMs = parseBoundedInteger(
    input["max-first-byte-ms"] ?? "15000",
    "max-first-byte-ms",
    1,
    15000,
  );
  const minimumTotalMs = parseBoundedInteger(
    input["min-total-ms"] ?? "0",
    "min-total-ms",
    0,
    15000,
  );
  const headers = parseHeaders(input.headers);
  if (bodyBytes > 0) headers["Content-Length"] = String(bodyBytes);

  const started = performance.now();
  const result = await new Promise((resolve, reject) => {
    const probe = request(
      url,
      {
        method: input.method ?? "GET",
        ca,
        rejectUnauthorized: true,
        headers,
      },
      (response) => {
        let firstByteMs;
        const chunks = [];
        response.on("data", (chunk) => {
          firstByteMs ??= performance.now() - started;
          chunks.push(chunk);
        });
        response.on("end", () => {
          resolve({
            status: response.statusCode,
            body: Buffer.concat(chunks).toString("utf8"),
            firstByteMs: firstByteMs ?? performance.now() - started,
            totalMs: performance.now() - started,
          });
        });
      },
    );
    probe.setTimeout(15_000, () => probe.destroy(new Error("Loopback HTTPS probe timed out.")));
    probe.on("error", reject);
    if (bodyBytes > 0) probe.end(Buffer.alloc(bodyBytes));
    else probe.end();
  });

  if (result.status !== expectedStatus) throw new Error("Unexpected loopback HTTPS status.");
  if (input.body !== undefined && result.body !== input.body) {
    throw new Error("Unexpected loopback HTTPS body.");
  }
  if (result.firstByteMs >= maximumFirstByteMs || result.totalMs < minimumTotalMs) {
    throw new Error("Loopback HTTPS streaming timing is outside the approved bounds.");
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await runLoopbackHttpsProbe(parseArguments(process.argv.slice(2)));
  process.stdout.write("Explicit-local-CA loopback HTTPS probe PASS\n");
}
