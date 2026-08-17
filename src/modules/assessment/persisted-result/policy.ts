import { createHash } from "node:crypto";

export const RESULT_PRIORITY_POLICY_KEY = "persisted-synthetic-priority-v1" as const; // gitleaks:allow -- public policy identity, not a credential
export const RESULT_PRIORITY_POLICY_VERSION = "1.0.0" as const;
export const RESULT_PRIORITY_POLICY_ID =
  `${RESULT_PRIORITY_POLICY_KEY}@${RESULT_PRIORITY_POLICY_VERSION}` as const;

export const RESULT_PRIORITY_POLICY_CANONICAL_JSON =
  '{"schemaVersion":"persisted-result-priority-policy-v1","policyKey":"persisted-synthetic-priority-v1","version":"1.0.0","normalization":{"scale":10000,"method":"floor-earned-times-scale-divided-by-available"},"priority":{"candidateKind":"assessed-core-complete-evidence","comparison":"integer-cross-multiplication","selection":"unique-lowest-only","maximumRecommendations":1,"tie":"no-recommendation"},"usesFrameworkWeights":false,"usesMultipliers":false}' as const; // gitleaks:allow -- canonical public policy document

export const RESULT_PRIORITY_POLICY_DIGEST =
  "10f2ab076828d50b228ff53d57332527dfe9d1b2769c4b57bd0476dd3c263157" as const;

export function sha256Hex(value: string): string {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

export function assertResultPriorityPolicyIntegrity(): void {
  if (sha256Hex(RESULT_PRIORITY_POLICY_CANONICAL_JSON) !== RESULT_PRIORITY_POLICY_DIGEST) {
    throw new Error("Persisted result policy integrity check failed.");
  }
}
