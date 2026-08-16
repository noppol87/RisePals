import { spawn } from "node:child_process";
import { resolve } from "node:path";

const commands = Object.freeze({
  build: resolve("node_modules/next/dist/bin/next"),
  e2e: resolve("node_modules/@playwright/test/cli.js"),
  start: resolve("node_modules/next/dist/bin/next"),
});

const [mode, ...forwardedArguments] = process.argv.slice(2);
const executable = commands[mode];

if (!executable) {
  throw new Error("Secret-free runner mode must be build, e2e or start.");
}

const defaultArguments = mode === "build" ? ["build"] : mode === "e2e" ? ["test"] : ["start"];
const environment = {
  ...process.env,
  CLERK_SECRET_KEY: "",
  CLERK_TELEMETRY_DISABLED: "true",
  NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY: "",
  NEXT_PUBLIC_CLERK_TELEMETRY_DISABLED: "true",
  RISE_PALS_SECRET_FREE_STANDARD_GATE: "true",
};

const child = spawn(process.execPath, [executable, ...defaultArguments, ...forwardedArguments], {
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
