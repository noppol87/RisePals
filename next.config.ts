import type { NextConfig } from "next";
import { PHASE_DEVELOPMENT_SERVER } from "next/constants";

export default function createNextConfig(phase: string): NextConfig {
  return {
    poweredByHeader: false,
    reactStrictMode: true,
    typescript: {
      tsconfigPath:
        phase === PHASE_DEVELOPMENT_SERVER ? "tsconfig.json" : "tsconfig.typecheck.json",
    },
  };
}
