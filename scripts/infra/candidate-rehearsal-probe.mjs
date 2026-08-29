import { createWriteStream, writeFileSync } from "node:fs";
import http from "node:http";
import { resolve } from "node:path";

const args = Object.fromEntries(
  process.argv.slice(2).reduce((pairs, value, index, values) => {
    if (value.startsWith("--") && index + 1 < values.length) {
      pairs.push([value.slice(2), values[index + 1]]);
    }
    return pairs;
  }, []),
);

const mode = args.mode;
const resultPath = args.result ? resolve(args.result) : "";
const firstBytePath = args["first-byte"] ? resolve(args["first-byte"]) : "";
const url = new URL(args.url ?? "");
if (
  !["ready", "stream", "new-work", "crash"].includes(mode) ||
  !resultPath ||
  url.protocol !== "http:" ||
  url.hostname !== "127.0.0.1" ||
  url.port !== "3100" ||
  url.username ||
  url.password ||
  url.search ||
  url.hash
) {
  process.exit(64);
}

function writeResult(result) {
  writeFileSync(resultPath, `${JSON.stringify(result)}\n`, {
    encoding: "utf8",
    flag: "wx",
  });
}

const request = http.request(
  url,
  {
    method: mode === "crash" ? "POST" : "GET",
    headers: { Connection: "close" },
    timeout: 5_000,
  },
  (response) => {
    let firstByte = false;
    let body = "";
    response.setEncoding("utf8");
    response.on("data", (chunk) => {
      if (!firstByte) {
        firstByte = true;
        if (firstBytePath) {
          const marker = createWriteStream(firstBytePath, { flags: "wx", encoding: "utf8" });
          marker.end("first-byte\n");
        }
      }
      body += chunk;
      if (body.length > 256) request.destroy(new Error("response-bound-exceeded"));
    });
    response.on("end", () => {
      const chunks = body.trim().split(/\r?\n/u).filter(Boolean);
      const result = {
        schemaVersion: "rise-pals-candidate-probe-v1",
        mode,
        statusCode: response.statusCode ?? 0,
        retryAfter: response.headers["retry-after"] ?? null,
        chunkCount: mode === "stream" ? chunks.length : 0,
        exactChunks:
          mode !== "stream" ||
          JSON.stringify(chunks) === JSON.stringify(["chunk-1", "chunk-2", "chunk-3"]),
      };
      writeResult(result);
      process.exit(0);
    });
  },
);
request.on("timeout", () => request.destroy(new Error("timeout")));
request.on("error", () => process.exit(70));
request.end();
