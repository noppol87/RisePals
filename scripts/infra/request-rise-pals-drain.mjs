import { approvedDrainStatePath, readDrainState, requestDrain } from "./drain-control.mjs";

async function main() {
  const started = Date.now();
  const requested = await requestDrain();
  process.stdout.write(
    `rise-pals-drain requested state=${requested.state.state} reused=${requested.reused}\n`,
  );

  while (Date.now() <= Date.parse(requested.state.deadlineAtUtc) + 250) {
    const current = readDrainState(approvedDrainStatePath);
    if (current.state === "stopped") {
      process.stdout.write(`rise-pals-drain completed elapsedMs=${Date.now() - started}\n`);
      return;
    }
    if (current.state === "drain_timeout") {
      throw new Error("Rise Pals drain reached its controlled timeout state.");
    }
    await new Promise((resolve) => setTimeout(resolve, 25));
  }

  throw new Error("Rise Pals drain helper timed out before a graceful stop.");
}

main().catch((error) => {
  process.stderr.write(`rise-pals-drain failed type=${error?.name ?? "Error"}\n`);
  process.exitCode = 1;
});
