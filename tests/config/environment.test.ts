import { describe, expect, it } from "vitest";
import { parseServerEnvironment } from "@/lib/env/schema";

describe("server environment", () => {
  it("accepts an absent optional application URL", () => {
    expect(parseServerEnvironment({})).toEqual({ appBaseUrl: null });
  });

  it("rejects a malformed application URL without exposing its value", () => {
    expect(() => parseServerEnvironment({ APP_BASE_URL: "not-an-absolute-url" })).toThrow(
      "APP_BASE_URL must be an absolute URL when provided.",
    );
  });
});
