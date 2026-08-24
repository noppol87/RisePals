import { describe, expect, it } from "vitest";

import {
  alphaExportContractVersion,
  alphaExportMaximumRowsPerSection,
  alphaExportQueryPlan,
  createAlphaOwnerExport,
  createCanonicalAlphaExport,
  serializeCanonicalAlphaExport,
} from "@/modules/privacy/export-runtime.mjs";

const ownerId = "30000000-0000-4000-8000-000000000001";
const sessionId = "30000000-0000-4000-8000-000000000002";
const runId = "30000000-0000-4000-8000-000000000003";
const lessonId = "30000000-0000-4000-8000-000000000004";
const artifactId = "30000000-0000-4000-8000-000000000005";

function source() {
  return {
    account: [
      {
        status: "active",
        created_at: new Date("2026-08-24T10:00:00.000Z"),
        updated_at: new Date("2026-08-24T10:30:00.000Z"),
        last_seen_at: null,
        deletion_requested_at: null,
        deleted_at: null,
      },
    ],
    profile: [
      {
        preferred_locale: "th",
        timezone: "Asia/Bangkok",
        role_family: "individual-contributor",
        function: "operations",
        experience_band: "mid",
        goals: ["build-evidence"],
        onboarding_completed_at: new Date("2026-08-24T10:01:00.000Z"),
        profile_schema_version: "profile-v1",
        updated_at: new Date("2026-08-24T10:01:00.000Z"),
      },
    ],
    consents: [
      {
        purpose_code: "required-service",
        notice_version: "1.0",
        decision: "granted",
        occurred_at: new Date("2026-08-24T10:01:00.000Z"),
        locale: "th",
        source_surface: "synthetic-test",
      },
    ],
    assessmentSessions: [
      {
        internal_id: sessionId,
        status: "submitted",
        started_at: new Date("2026-08-24T10:02:00.000Z"),
        updated_at: new Date("2026-08-24T10:05:00.000Z"),
        submitted_at: new Date("2026-08-24T10:05:00.000Z"),
        assessment_key: "synthetic-scenario-assessment",
        assessment_version: "1.0.0",
        assessment_digest: "a".repeat(64),
        framework_key: "rise-pals-8-plus-2",
        framework_version: "1.0.0",
        framework_digest: "b".repeat(64),
        scoring_model_key: "synthetic-deterministic-rubric",
        scoring_model_version: "1.0.0",
        scoring_model_digest: "c".repeat(64),
      },
    ],
    assessmentResponses: [
      {
        internal_session_id: sessionId,
        item_key: "scenario-1",
        revision: 1,
        response_payload: {
          schemaVersion: "assessment-response-v1",
          selectedOptionId: "scenario-1-option-b",
        },
        is_active: true,
        created_at: new Date("2026-08-24T10:03:00.000Z"),
      },
    ],
    scoringRuns: [
      {
        internal_id: runId,
        internal_session_id: sessionId,
        run_number: 1,
        run_kind: "normal",
        result_policy_key: "persisted-synthetic-priority-v1", // gitleaks:allow -- public policy identifier
        result_policy_version: "1.0.0",
        result_policy_digest: "d".repeat(64),
        computed_at: new Date("2026-08-24T10:06:00.000Z"),
      },
    ],
    coreScores: [
      {
        internal_run_id: runId,
        competency_key: "critical-thinking-fact-checking",
        earned_points: 2,
        available_points: 4,
        evidence_count: 2,
        normalized_basis_points: 5000,
        created_at: new Date("2026-08-24T10:06:00.000Z"),
      },
    ],
    multiplierObservations: [],
    scoreExplanations: [],
    priorities: [],
    lessonAttempts: [
      {
        internal_id: lessonId,
        lesson_key: "source-verification-practice",
        status: "demonstrated",
      },
    ],
    practiceAttempts: [
      {
        internal_lesson_id: lessonId,
        revision: 2,
        mutation_intent: "evaluate",
        status: "evaluated",
        response_payload: { schemaVersion: "source-verification-practice-response-v1" },
        criterion_results: { schemaVersion: "source-verification-criteria-v1" },
        demonstrated: true,
      },
    ],
    progressEvents: [
      {
        internal_lesson_id: lessonId,
        event_kind: "practice_demonstrated",
        event_schema_version: "learning-progress-event-v1",
      },
    ],
    evidenceArtifacts: [
      {
        internal_id: artifactId,
        artifact_contract_id: "source-verification-note-artifact-v1",
        artifact_contract_version: "1.0.0",
        status: "withdrawn",
      },
    ],
    evidenceRevisions: [
      {
        internal_artifact_id: artifactId,
        revision: 1,
        payload: { schemaVersion: "source-verification-note-artifact-payload-v1" },
        mutation_intent: "save",
        mutation_locale: "th",
        mutation_expected_revision: 0,
      },
    ],
    evidenceLinks: [
      {
        internal_artifact_id: artifactId,
        competency_key: "critical-thinking-fact-checking",
        relationship_code: "synthetic-practice-evidence",
      },
    ],
    productEvents: [
      {
        schema_version: "product-measurement-v1",
        event_class: "activation_completed",
        surface_code: "assessment",
        operation_code: "assessment_response_saved",
        occurred_at: new Date("2026-08-24T10:03:00.000Z"),
      },
    ],
  };
}

describe("canonical synthetic-alpha owner export", () => {
  it("is byte-identical, versioned, interpretable and uses export-local references", () => {
    const first = serializeCanonicalAlphaExport(createCanonicalAlphaExport(source()));
    const second = serializeCanonicalAlphaExport(createCanonicalAlphaExport(source()));

    expect(first).toBe(second);
    expect(JSON.parse(first).contractVersion).toBe(alphaExportContractVersion);
    expect(first).toContain('"sessionRef":"assessment-session-1"');
    expect(first).toContain('"runRef":"scoring-run-1"');
    expect(first).toContain('"lessonRef":"lesson-attempt-1"');
    expect(first).toContain('"artifactRef":"evidence-artifact-1"');
    expect(first).not.toContain(ownerId);
    expect(first).not.toContain(sessionId);
    expect(first).not.toContain(runId);
    expect(first).not.toContain(lessonId);
    expect(first).not.toContain(artifactId);
  });

  it("contains no prohibited identity, secret, subject or operational fields", () => {
    const bytes = serializeCanonicalAlphaExport(createCanonicalAlphaExport(source()));
    for (const forbidden of [
      "provider_subject",
      "providerSubject",
      "measurement_subject",
      "action_digest",
      "mutation_digest",
      "correlation_id",
      "client_mutation_id",
      "DATABASE_URL",
      "cookie",
      "token",
      "employmentSuitability",
      "validatedProficiency",
    ]) {
      expect(bytes).not.toContain(forbidden);
    }
  });

  it("uses owner-scoped bounded reads and rejects an over-limit section", async () => {
    expect(alphaExportQueryPlan).toHaveLength(17);
    expect(alphaExportQueryPlan.every(({ sql }) => /WHERE[\s\S]*\$1/i.test(sql))).toBe(true);
    expect(alphaExportQueryPlan.every(({ sql }) => /LIMIT (?:2|501)/.test(sql))).toBe(true);

    const rowsByKey = source();
    const calls: { sql: string; values: readonly unknown[] }[] = [];
    const client = {
      async query(sql: string, values: readonly unknown[]) {
        const index = calls.length;
        calls.push({ sql, values });
        const key = alphaExportQueryPlan[index]!.key as keyof typeof rowsByKey;
        return { rows: rowsByKey[key] };
      },
    };
    const exported = await createAlphaOwnerExport(client, ownerId);
    expect(exported.sha256).toMatch(/^[0-9a-f]{64}$/);
    expect(calls).toHaveLength(alphaExportQueryPlan.length);
    expect(calls.every(({ values }) => values[0] === ownerId)).toBe(true);

    const overflowClient = {
      async query() {
        return { rows: Array.from({ length: alphaExportMaximumRowsPerSection + 1 }, () => ({})) };
      },
    };
    await expect(createAlphaOwnerExport(overflowClient, ownerId)).rejects.toThrow(
      "bounded row limit",
    );
  });
});
