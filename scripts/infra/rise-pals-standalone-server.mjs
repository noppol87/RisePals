import { createServer } from "node:http";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  approvedDrainStatePath,
  classifyDrainRequest,
  createActiveRequestRegistry,
  markDrainReady,
  markDrainStopped,
  markDrainTimeout,
  prepareDrainStateForStartup,
  readDrainState,
} from "./drain-control.mjs";

const directory = dirname(fileURLToPath(import.meta.url));
const hostname = process.env.HOSTNAME;
const port = Number(process.env.PORT);
const configuredStatePath = resolve(process.env.RISE_PALS_DRAIN_STATE_FILE ?? "");

if (
  hostname !== "127.0.0.1" ||
  !Number.isSafeInteger(port) ||
  port !== 3100 ||
  configuredStatePath.toLowerCase() !== approvedDrainStatePath.toLowerCase()
) {
  throw new Error("Rise Pals standalone runtime configuration is outside the approved boundary.");
}

process.env.NODE_ENV = "production";
process.chdir(directory);
const requiredServerFiles = JSON.parse(
  readFileSync(join(directory, ".next", "required-server-files.json"), "utf8"),
);
process.env.__NEXT_PRIVATE_STANDALONE_CONFIG = JSON.stringify(requiredServerFiles.config);

let previousLifecycle;
try {
  previousLifecycle = await prepareDrainStateForStartup();
} catch {
  process.stderr.write("rise-pals-lifecycle startup-state-invalid fail-closed\n");
  process.exit(1);
}
if (previousLifecycle.previous !== null) {
  process.stdout.write(
    `rise-pals-lifecycle startup-reconciled previous=${previousLifecycle.previous.state}\n`,
  );
}

const require = createRequire(import.meta.url);
require("next");
const { getRequestHandlers } = require("next/dist/server/lib/start-server");

let requestHandler;
let upgradeHandler;
let nextServer;
let closeUpgraded;
const activeRequests = createActiveRequestRegistry();
let drainStartedAt = null;
let shutdownStarted = false;
let pollTimer;

function fixedJson(response, status, body, extraHeaders = {}) {
  response.writeHead(status, {
    "Cache-Control": "no-store",
    "Content-Type": "application/json; charset=utf-8",
    "X-Content-Type-Options": "nosniff",
    ...extraHeaders,
  });
  response.end(`${JSON.stringify(body)}\n`);
}

function rejectDuringDrain(request, response, disposition) {
  if (disposition === "live") {
    fixedJson(response, 200, { status: "ok" });
    return;
  }
  if (disposition === "ready-draining" || disposition === "ready-unavailable") {
    fixedJson(response, 503, {
      status: disposition === "ready-draining" ? "draining" : "unavailable",
    });
    return;
  }
  fixedJson(
    response,
    503,
    { status: disposition === "reject-draining" ? "draining" : "unavailable" },
    { "Retry-After": "5" },
  );
}

function observeDrain(state) {
  if (drainStartedAt === null) {
    drainStartedAt = Date.parse(state.startedAtUtc);
    process.stdout.write("rise-pals-lifecycle draining activeRequests-preserved\n");
  }
}

async function completeGracefulShutdown(server, lifecycle) {
  if (shutdownStarted) return;
  shutdownStarted = true;
  clearInterval(pollTimer);
  closeUpgraded?.();
  const remainingMs = Math.max(1, Date.parse(lifecycle.deadlineAtUtc) - Date.now());
  await new Promise((resolveClose, rejectClose) => {
    const timeout = setTimeout(
      () => rejectClose(new Error("HTTP server close exceeded the drain deadline.")),
      remainingMs,
    );
    server.close((error) => {
      clearTimeout(timeout);
      if (error) rejectClose(error);
      else resolveClose();
    });
    server.closeIdleConnections?.();
  });
  await nextServer?.close();
  await markDrainStopped();
  process.stdout.write(
    `rise-pals-lifecycle stopped graceful=true elapsedMs=${Date.now() - drainStartedAt}\n`,
  );
  process.exit(0);
}

async function failDrainTimeout(server) {
  if (shutdownStarted) return;
  shutdownStarted = true;
  clearInterval(pollTimer);
  await markDrainTimeout();
  server.closeAllConnections?.();
  server.close();
  process.stderr.write("rise-pals-lifecycle drain-timeout graceful=false\n");
  process.exit(1);
}

const server = createServer(async (request, response) => {
  let lifecycle;
  try {
    lifecycle = readDrainState();
  } catch {
    fixedJson(response, 503, { status: "unavailable" });
    return;
  }
  const disposition = classifyDrainRequest(lifecycle, request.url ?? "");
  if (disposition !== "admit") {
    if (lifecycle.state === "draining") observeDrain(lifecycle);
    rejectDuringDrain(request, response, disposition);
    return;
  }

  const finish = activeRequests.admit();
  response.once("finish", finish);
  response.once("close", finish);
  try {
    await requestHandler(request, response);
  } catch (error) {
    if (!response.headersSent) fixedJson(response, 500, { status: "unavailable" });
    else response.destroy(error);
  }
});

server.on("upgrade", async (request, socket, head) => {
  let lifecycle;
  try {
    lifecycle = readDrainState();
  } catch {
    socket.destroy();
    return;
  }
  if (lifecycle.state !== "ready") {
    socket.destroy();
    return;
  }
  await upgradeHandler(request, socket, head);
});

const initialized = await getRequestHandlers({
  dir: directory,
  port,
  isDev: false,
  server,
  hostname,
  minimalMode: false,
  keepAliveTimeout: undefined,
  quiet: false,
});
requestHandler = initialized.requestHandler;
upgradeHandler = initialized.upgradeHandler;
nextServer = initialized.server;
closeUpgraded = initialized.closeUpgraded;

await new Promise((resolveListen, rejectListen) => {
  server.once("error", rejectListen);
  server.listen(port, hostname, resolveListen);
});
await markDrainReady();
process.stdout.write("rise-pals-lifecycle ready\n");

pollTimer = setInterval(() => {
  let lifecycle;
  try {
    lifecycle = readDrainState();
  } catch {
    process.stderr.write("rise-pals-lifecycle invalid-state fail-closed\n");
    server.closeAllConnections?.();
    server.close();
    clearInterval(pollTimer);
    process.exit(1);
    return;
  }
  if (lifecycle.state !== "draining") return;
  observeDrain(lifecycle);
  if (Date.now() >= Date.parse(lifecycle.deadlineAtUtc)) {
    void failDrainTimeout(server);
    return;
  }
  if (activeRequests.count() === 0) {
    void completeGracefulShutdown(server, lifecycle).catch(async (error) => {
      try {
        if (readDrainState().state === "draining") await markDrainTimeout();
      } catch {
        // The fixed marker and non-zero exit are authoritative if state recording also fails.
      }
      process.stderr.write(`rise-pals-lifecycle stop-error type=${error?.name ?? "Error"}\n`);
      server.closeAllConnections?.();
      process.exit(1);
    });
  }
}, 25);
pollTimer.unref();
