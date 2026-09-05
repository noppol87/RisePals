import { spawn } from "node:child_process";
import { resolve } from "node:path";

const commands = Object.freeze({
  build: resolve("node_modules/next/dist/bin/next"),
  e2e: resolve("node_modules/@playwright/test/cli.js"),
  start: resolve(".next/standalone/server.js"),
});

const [mode, ...forwardedArguments] = process.argv.slice(2);
const executable = commands[mode];

if (!executable) {
  throw new Error("Secret-free runner mode must be build, e2e or start.");
}

const defaultArguments = mode === "build" ? ["build"] : mode === "e2e" ? ["test"] : [];
const environment = {
  ...process.env,
  CLERK_SECRET_KEY: "",
  CLERK_TELEMETRY_DISABLED: "true",
  NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY: "",
  NEXT_PUBLIC_CLERK_TELEMETRY_DISABLED: "true",
  RISE_PALS_SECRET_FREE_STANDARD_GATE: "true",
};

if (mode === "start") {
  const supported = new Map([
    ["--hostname", "HOSTNAME"],
    ["--port", "PORT"],
  ]);

  for (let index = 0; index < forwardedArguments.length; index += 2) {
    const option = forwardedArguments[index];
    const value = forwardedArguments[index + 1];
    const environmentName = supported.get(option);

    if (!environmentName || value === undefined) {
      throw new Error("Standalone start accepts only --hostname and --port value pairs.");
    }
    if (option === "--hostname" && value !== "127.0.0.1") {
      throw new Error("Secret-free standalone start must bind to 127.0.0.1.");
    }
    if (option === "--port" && (!/^[1-9][0-9]{0,4}$/.test(value) || Number(value) > 65_535)) {
      throw new Error("Secret-free standalone start requires a valid numeric port.");
    }

    environment[environmentName] = value;
  }
}

const childArguments = mode === "start" ? [] : forwardedArguments;
const child = spawn(process.execPath, [executable, ...defaultArguments, ...childArguments], {
  env: environment,
  stdio: "inherit",
  windowsHide: true,
});

child.once("error", (error) => {
  console.error(`Secret-free ${mode} runner failed to start: ${error.message}`);
  process.exitCode = 1;
});

child.once("exit", (code, signal) => {
  if (signal) {
    console.error(`Secret-free ${mode} runner exited after signal ${signal}.`);
    process.exitCode = 1;
    return;
  }
  process.exitCode = code ?? 1;
});
