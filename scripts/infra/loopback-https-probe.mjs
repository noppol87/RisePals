import { writeFileSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { request } from "node:https";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const approvedFirstByteMarker = resolve(
  "C:\\RisePals\\rehearsal\\graceful-stream.started",
).toLowerCase();
const approvedResultPaths = new Set(
  [
    "C:\\RisePals\\rehearsal\\graceful-stream.result.json",
    "C:\\RisePals\\rehearsal\\drain-rejection.result.json",
  ].map((path) => resolve(path).toLowerCase()),
);

function parseArguments(values) {
  const parsed = { headers: [], responseHeaders: [] };
  for (let index = 0; index < values.length; index += 2) {
    const name = values[index];
    const value = values[index + 1];
    if (!name?.startsWith("--") || value === undefined) {
      throw new Error("Probe arguments must be --name value pairs.");
    }
    const key = name.slice(2);
    if (key === "header") parsed.headers.push(value);
    else if (key === "response-header") parsed.responseHeaders.push(value);
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

function parseExpectedResponseHeaders(values) {
  return Object.entries(parseHeaders(values)).map(([name, value]) => [name.toLowerCase(), value]);
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
  const expectedResponseHeaders = parseExpectedResponseHeaders(input.responseHeaders);
  if (bodyBytes > 0) headers["Content-Length"] = String(bodyBytes);
  const firstByteMarker = input["first-byte-marker"];
  if (
    firstByteMarker !== undefined &&
    resolve(firstByteMarker).toLowerCase() !== approvedFirstByteMarker
  ) {
    throw new Error("The first-byte marker path is outside the approved rehearsal boundary.");
  }
  const resultPath = input["result-path"];
  if (resultPath !== undefined && !approvedResultPaths.has(resolve(resultPath).toLowerCase())) {
    throw new Error("The result path is outside the approved rehearsal boundary.");
  }

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
        response.on("error", reject);
        response.on("data", (chunk) => {
          if (firstByteMs === undefined) {
            firstByteMs = performance.now() - started;
            if (firstByteMarker !== undefined) {
              try {
                writeFileSync(firstByteMarker, "started\n", { encoding: "utf8", flag: "wx" });
              } catch (error) {
                response.destroy(error);
                return;
              }
            }
          }
          chunks.push(chunk);
        });
        response.on("end", () => {
          resolve({
            status: response.statusCode,
            body: Buffer.concat(chunks).toString("utf8"),
            headers: Object.fromEntries(
              Object.entries(response.headers).map(([name, value]) => [
                name.toLowerCase(),
                Array.isArray(value) ? value.join(", ") : (value ?? ""),
              ]),
            ),
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

  if (result.status !== expectedStatus) {
    throw new Error(`Unexpected loopback HTTPS status: ${result.status}.`);
  }
  for (const [name, value] of expectedResponseHeaders) {
    if (result.headers[name] !== value) {
      throw new Error(`Unexpected loopback HTTPS response header: ${name}.`);
    }
  }
  const expectedBody =
    input["body-base64"] === undefined
      ? undefined
      : Buffer.from(input["body-base64"], "base64").toString("utf8");
  if (expectedBody !== undefined && result.body !== expectedBody) {
    throw new Error("Unexpected loopback HTTPS body.");
  }
  if (result.firstByteMs >= maximumFirstByteMs || result.totalMs < minimumTotalMs) {
    throw new Error("Loopback HTTPS streaming timing is outside the approved bounds.");
  }
  if (resultPath !== undefined) {
    writeFileSync(
      resultPath,
      `${JSON.stringify({
        schemaVersion: "rise-pals-loopback-probe-result-v1",
        status: result.status,
        bodyBytes: Buffer.byteLength(result.body),
        firstByteMs: Math.round(result.firstByteMs),
        totalMs: Math.round(result.totalMs),
      })}\n`,
      { encoding: "utf8", flag: "wx" },
    );
  }
  return result;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await runLoopbackHttpsProbe(parseArguments(process.argv.slice(2)));
  process.stdout.write("Explicit-local-CA loopback HTTPS probe PASS\n");
}
