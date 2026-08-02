import { describe, expect, it } from "vitest";
import { parseServerEnvironment } from "@/lib/env/schema";

const APP_BASE_URL_REMEDIATION =
  "APP_BASE_URL must be an http:// or https:// origin with no credentials, path, query, or fragment.";

describe("server environment", () => {
  it("accepts an absent optional application URL", () => {
    expect(parseServerEnvironment({})).toEqual({ appBaseUrl: null });
  });

  it.each([
    ["a production HTTPS origin", "https://risepals.com", "https://risepals.com/"],
    ["a development HTTP localhost origin", "http://localhost:3000", "http://localhost:3000/"],
    ["a normalizable HTTPS origin", "HTTPS://RISEPALS.COM:443", "https://risepals.com/"],
  ])("accepts %s and returns a normalized origin", (_description, input, expected) => {
    expect(parseServerEnvironment({ APP_BASE_URL: input }).appBaseUrl?.href).toBe(expected);
  });

  it.each([
    ["a malformed URL", "not-an-absolute-url"],
    ["a JavaScript URL", "javascript:alert(1)"],
    ["a file URL", "file:///etc/passwd"],
    ["credentials", "https://user:password@risepals.com"],
    ["a non-root path", "https://risepals.com/app"],
    ["a query string", "https://risepals.com?mode=test"],
    ["a fragment", "https://risepals.com#section"],
  ])("rejects %s with stable remediation that does not expose the value", (_description, input) => {
    expect(() => parseServerEnvironment({ APP_BASE_URL: input })).toThrow(APP_BASE_URL_REMEDIATION);
    expect(APP_BASE_URL_REMEDIATION).not.toContain(input);
  });
});
