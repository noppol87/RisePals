import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  test: {
    environment: "jsdom",
    fileParallelism: false,
    include: ["tests/**/*.test.{ts,tsx}"],
    pool: "vmThreads",
    setupFiles: ["./tests/setup.ts"],
    vmMemoryLimit: "1GB",
  },
});
