import { readFile } from "node:fs/promises";
import {
  evaluateInfrastructureReadiness,
  isInfrastructureRehearsalEnabled,
  isLoopbackRequest,
  parseInfrastructureDrainState,
} from "@/lib/infra/health";

export const dynamic = "force-dynamic";

async function releaseMarkerExists(path: string | undefined): Promise<boolean> {
  if (!path || !isInfrastructureRehearsalEnabled(process.env)) {
    return false;
  }

  try {
    const marker = await readFile(path);
    return marker.byteLength > 0;
  } catch {
    return false;
  }
}

async function rehearsalSecretIsReadable(path: string | undefined): Promise<boolean> {
  if (!path || !isInfrastructureRehearsalEnabled(process.env)) {
    return false;
  }

  try {
    const value = await readFile(path);
    return value.byteLength === 64;
  } catch {
    return false;
  }
}

async function readDrainState(
  path: string | undefined,
): Promise<"ready" | "draining" | "unavailable"> {
  if (
    path !== "C:\\RisePals\\shared\\control\\app-drain-state.json" ||
    !isInfrastructureRehearsalEnabled(process.env)
  ) {
    return "unavailable";
  }
  try {
    return parseInfrastructureDrainState(await readFile(path, "utf8"));
  } catch {
    return "unavailable";
  }
}

export async function GET(request: Request): Promise<Response> {
  const readiness = evaluateInfrastructureReadiness({
    loopback: isLoopbackRequest(request),
    rehearsalEnabled: isInfrastructureRehearsalEnabled(process.env),
    releaseMarkerPresent: await releaseMarkerExists(process.env.RISE_PALS_RELEASE_MARKER),
    rehearsalSecretReadable: await rehearsalSecretIsReadable(
      process.env.RISE_PALS_REHEARSAL_SECRET_FILE,
    ),
    drainState: await readDrainState(process.env.RISE_PALS_DRAIN_STATE_FILE),
  });

  return Response.json(
    { status: readiness.status },
    {
      headers: { "Cache-Control": "no-store" },
      status: readiness.ready ? 200 : 503,
    },
  );
}
