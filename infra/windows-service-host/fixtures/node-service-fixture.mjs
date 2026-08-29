import net from "node:net";
import process from "node:process";

const pipeArgumentIndex = process.argv.indexOf("--rise-pals-drain-pipe");
const pipeName =
  process.env.RISEPALS_DRAIN_PIPE ??
  (pipeArgumentIndex >= 0 ? process.argv[pipeArgumentIndex + 1] : undefined);
if (!pipeName) {
  process.stderr.write("fixture configuration missing\n");
  process.exit(64);
}

const mode = process.argv[2] ?? "normal";
if (mode === "startup-failure") {
  process.stderr.write("controlled startup failure\n");
  process.exit(70);
}

let state = "Ready";
let activeCount = 0;
let drainNonce = "";
const socket = net.createConnection(`\\\\.\\pipe\\${pipeName}`);

function send(message) {
  socket.write(`${JSON.stringify(message)}\n`);
}

function acknowledgement(nonce, nextState) {
  return { version: 1, type: "ack", nonce, state: nextState, activeCount };
}

socket.once("connect", () => {
  if (mode === "malformed-ready") {
    socket.write("not-json\n");
    return;
  }

  send(acknowledgement("", "Ready"));
  if (mode === "output-fixture") {
    process.stdout.write("synthetic-standard-output\n");
    process.stderr.write("synthetic-standard-error\n");
  }
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
      if (activeCount === 0) {
        state = "Drained";
        send(acknowledgement(nonce, "Drained"));
      }
    } else if (message.state === "Stopped" && message.nonce === drainNonce && state === "Drained") {
      state = "Stopped";
      send(acknowledgement(drainNonce, "Stopped"));
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
              activeCount -= 1;
              if (state === "Draining" && activeCount === 0) {
                state = "Drained";
                send(acknowledgement(drainNonce, "Drained"));
              }
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

socket.on("error", () => process.exit(72));
