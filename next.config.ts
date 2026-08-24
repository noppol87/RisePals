import type { NextConfig } from "next";
import { PHASE_DEVELOPMENT_SERVER } from "next/constants";

export default function createNextConfig(phase: string): NextConfig {
  const clerkDevelopmentSmoke = process.env.RISE_PALS_CLERK_DEVELOPMENT_SMOKE === "true";

  return {
    ...(clerkDevelopmentSmoke ? { distDir: ".next-clerk-development-smoke" } : {}),
    output: "standalone",
    poweredByHeader: false,
    reactStrictMode: true,
    typescript: {
      tsconfigPath:
        phase === PHASE_DEVELOPMENT_SERVER
          ? "tsconfig.json"
          : clerkDevelopmentSmoke
            ? "tsconfig.clerk-smoke.json"
            : "tsconfig.typecheck.json",
    },
  };
}
