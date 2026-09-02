import net from "node:net";
import http from "node:http";
import process from "node:process";
import { renameSync, writeFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";

const diagnosticSchemaVersion = 1;
const diagnosticDirectory = process.env.RISEPALS_FIXTURE_DIAGNOSTIC_DIRECTORY;
const diagnosticNonce = process.env.RISEPALS_FIXTURE_DIAGNOSTIC_NONCE;
const diagnosticRoot = process.env.RISEPALS_FIXTURE_DIAGNOSTIC_ROOT;
const diagnosticStartedAt = process.hrtime.bigint();
let diagnosticSequence = 0;
let diagnosticTerminalRecorded = false;

if (
  (diagnosticDirectory && (!diagnosticNonce || !diagnosticRoot)) ||
  (!diagnosticDirectory && (diagnosticNonce || diagnosticRoot))
) {
  process.stderr.write("fixture diagnostic configuration incomplete\n");
  process.exit(64);
}

if (diagnosticDirectory) {
  const expectedDirectoryName = `risepals-servicehost-diagnostic-${diagnosticNonce}`;
  const expectedRoot = resolve(diagnosticRoot);
  const expectedDirectory = resolve(join(expectedRoot, expectedDirectoryName));
  if (
    !/^[0-9a-f]{32}$/u.test(diagnosticNonce) ||
    resolve(diagnosticDirectory) !== expectedDirectory ||
    basename(expectedDirectory) !== expectedDirectoryName ||
    resolve(dirname(expectedDirectory)) !== expectedRoot
  ) {
    process.stderr.write("fixture diagnostic configuration invalid\n");
    process.exit(64);
  }
}

function recordDiagnostic(stage, failureCategory = "none", exitCode = null) {
  if (!diagnosticDirectory) return;

  diagnosticSequence += 1;
  const elapsedMilliseconds = Number((process.hrtime.bigint() - diagnosticStartedAt) / 1_000_000n);
  const fileName = `${String(diagnosticSequence).padStart(6, "0")}.json`;
  const finalPath = join(diagnosticDirectory, fileName);
  const temporaryPath = `${finalPath}.${diagnosticNonce}.tmp`;
  const record = {
    schemaVersion: diagnosticSchemaVersion,
    nonce: diagnosticNonce,
    sequence: diagnosticSequence,
    stage,
    failureCategory,
    exitCode,
    elapsedMilliseconds,
  };
  writeFileSync(temporaryPath, `${JSON.stringify(record)}\n`, { encoding: "utf8", flag: "wx" });
  renameSync(temporaryPath, finalPath);
}

function recordTerminalDiagnostic(stage, failureCategory, exitCode) {
  if (diagnosticTerminalRecorded) return;
  diagnosticTerminalRecorded = true;
  recordDiagnostic(stage, failureCategory, exitCode);
}

const pipeArgumentIndex = process.argv.indexOf("--rise-pals-drain-pipe");
const pipeName =
  process.env.RISEPALS_DRAIN_PIPE ??
  (pipeArgumentIndex >= 0 ? process.argv[pipeArgumentIndex + 1] : undefined);
if (!pipeName) {
  process.stderr.write("fixture configuration missing\n");
  process.exit(64);
}

const mode = process.argv[2] ?? "normal";
const portArgumentIndex = process.argv.indexOf("--fixture-http-port");
const fixtureHttpPort =
  portArgumentIndex >= 0 ? Number.parseInt(process.argv[portArgumentIndex + 1] ?? "", 10) : 0;
if (
  portArgumentIndex >= 0 &&
  (!Number.isSafeInteger(fixtureHttpPort) || fixtureHttpPort < 1024 || fixtureHttpPort > 65_535)
) {
  process.stderr.write("fixture HTTP port invalid\n");
  process.exit(64);
}
if (mode === "startup-failure") {
  process.stderr.write("controlled startup failure\n");
  process.exit(70);
}

recordDiagnostic("fixture-started");

if (mode === "diagnostic-exit-before-connect") {
  recordTerminalDiagnostic("fixture-exit-recorded", "controlled-fixture-exit", 74);
  process.exit(74);
}

if (mode === "diagnostic-alive-before-connect") {
  setInterval(() => {}, 1_000);
} else {
  recordDiagnostic("pipe-connection-attempted");
}

let state = "Ready";
let activeCount = 0;
let drainNonce = "";
const socket =
  mode === "diagnostic-alive-before-connect"
    ? new net.Socket()
    : net.createConnection(`\\\\.\\pipe\\${pipeName}`);
let server;

function finishAcceptedWork() {
  activeCount -= 1;
  if (state === "Draining" && activeCount === 0) {
    state = "Drained";
    send(acknowledgement(drainNonce, "Drained"));
  }
}

function writeThreeChunks(response) {
  activeCount += 1;
  response.writeHead(200, {
    "Content-Type": "text/plain; charset=utf-8",
    "Cache-Control": "no-store",
  });
  ["chunk-1", "chunk-2", "chunk-3"].forEach((chunk, index) => {
    setTimeout(
      () => {
        response.write(`${chunk}\n`);
        if (index === 2) {
          response.end();
          finishAcceptedWork();
        }
      },
      100 * (index + 1),
    );
  });
}

function startLoopbackServer(onListening) {
  if (fixtureHttpPort === 0) {
    onListening();
    return;
  }
  server = http.createServer((request, response) => {
    if (request.url === "/health/ready" && request.method === "GET") {
      response.writeHead(state === "Ready" ? 200 : 503, {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store",
        ...(state === "Ready" ? {} : { "Retry-After": "5" }),
      });
      response.end(JSON.stringify({ status: state === "Ready" ? "ready" : "draining" }));
      return;
    }
    if (request.url === "/health/stream" && request.method === "GET") {
      if (state !== "Ready") {
        response.writeHead(503, {
          "Content-Type": "application/json; charset=utf-8",
          "Cache-Control": "no-store",
          "Retry-After": "5",
        });
        response.end(JSON.stringify({ status: "draining" }));
        return;
      }
      writeThreeChunks(response);
      return;
    }
    if (request.url === "/fixture/crash" && request.method === "POST") {
      response.writeHead(202, { "Cache-Control": "no-store" });
      response.end();
      setImmediate(() => process.exit(71));
      return;
    }
    response.writeHead(404, { "Cache-Control": "no-store" });
    response.end();
  });
  server.on("error", () => process.exit(73));
  server.listen(fixtureHttpPort, "127.0.0.1", onListening);
}

function send(message) {
  socket.write(`${JSON.stringify(message)}\n`);
}

function sendReady(payload) {
  recordDiagnostic("ready-write-attempted");
  if (mode === "diagnostic-ready-write-failure") {
    socket.destroy();
    socket.write(payload, () => {});
    recordTerminalDiagnostic("fixture-exit-recorded", "ready-write-failure", 76);
    setImmediate(() => process.exit(76));
    return;
  }

  socket.write(payload, (error) => {
    if (error) {
      recordTerminalDiagnostic("fixture-exit-recorded", "ready-write-failure", 76);
      process.exit(76);
      return;
    }

    recordDiagnostic("ready-write-completed");
  });
}

function acknowledgement(nonce, nextState) {
  return { version: 1, type: "ack", nonce, state: nextState, activeCount };
}

socket.once("connect", () => {
  recordDiagnostic("pipe-connected");
  if (mode === "diagnostic-exit-after-connect") {
    recordTerminalDiagnostic("fixture-exit-recorded", "controlled-fixture-exit", 75);
    socket.destroy();
    process.exit(75);
  }

  if (mode === "malformed-ready") {
    sendReady("not-json\n");
    return;
  }

  startLoopbackServer(() => {
    sendReady(`${JSON.stringify(acknowledgement("", "Ready"))}\n`);
    if (mode === "output-fixture") {
      process.stdout.write("synthetic-standard-output\n");
      process.stderr.write("synthetic-standard-error\n");
    }
  });
});

let buffered = "";
socket.on("data", (chunk) => {
  buffered += chunk.toString("utf8");
  while (buffered.includes("\n")) {
    const boundary = buffered.indexOf("\n");
    const line = buffered.slice(0, boundary);
    buffered = buffered.slice(boundary + 1);
    let message;
    try {
      message = JSON.parse(line);
    } catch {
      process.exitCode = 65;
      socket.destroy();
      return;
    }

    if (message.version !== 1 || message.type !== "command") {
      process.exitCode = 65;
      socket.destroy();
      return;
    }

    if (message.state === "Draining") {
      if (state === "Ready") {
        state = "Draining";
        drainNonce = message.nonce;
      }

      const nonce = mode === "stale-ack" ? "00000000000000000000000000000000" : drainNonce;
      send(acknowledgement(nonce, "Draining"));
      if (activeCount === 0 && mode !== "never-drain") {
        state = "Drained";
        send(acknowledgement(nonce, "Drained"));
      }
    } else if (message.state === "Stopped" && message.nonce === drainNonce && state === "Drained") {
      if (mode === "never-exit") return;
      state = "Stopped";
      send(acknowledgement(drainNonce, "Stopped"));
      if (server) server.close();
      setTimeout(() => process.exit(0), 20);
    }
  }
});

process.stdin.setEncoding("utf8");
process.stdin.on("data", (text) => {
  for (const command of text.split(/\r?\n/u).filter(Boolean)) {
    if (command === "stream") {
      if (state !== "Ready") {
        process.stdout.write("work-rejected-draining\n");
        continue;
      }

      activeCount += 1;
      ["chunk-1", "chunk-2", "chunk-3"].forEach((chunk, index) => {
        setTimeout(
          () => {
            process.stdout.write(`${chunk}\n`);
            if (index === 2) {
              finishAcceptedWork();
            }
          },
          40 * (index + 1),
        );
      });
    } else if (command === "crash") {
      process.exit(71);
    } else if (command === "spawn-descendant") {
      import("node:child_process").then(({ spawn }) => {
        spawn(process.execPath, ["-e", "setInterval(() => {}, 1000)"], {
          stdio: "ignore",
          windowsHide: true,
        });
        process.stdout.write("descendant-started\n");
      });
    } else if (command === "exit") {
      const delay = mode === "delayed-exit" ? 500 : 0;
      setTimeout(() => process.exit(0), delay);
    }
  }
});

socket.on("error", () => {
  if (mode === "diagnostic-ready-write-failure") {
    recordTerminalDiagnostic("fixture-exit-recorded", "ready-write-failure", 76);
    process.exit(76);
  }

  recordTerminalDiagnostic("fixture-exit-recorded", "connection-failure", 72);
  process.exit(72);
});
