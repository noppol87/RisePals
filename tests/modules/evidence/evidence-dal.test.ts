import type { PoolClient } from "pg";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { IdentityProvider } from "@/modules/identity/contract";
import type { EvidenceArtifactPayload } from "@/modules/evidence/types";

const authorization = vi.hoisted(() => ({ run: vi.fn() }));

vi.mock("server-only", () => ({}));
vi.mock("@/modules/account/authorization", () => ({
  withAuthorizedUserTransaction: (
    provider: IdentityProvider,
    operation: (client: PoolClient, userId: string) => Promise<unknown>,
  ) => authorization.run(provider, operation),
}));
vi.mock("@/modules/identity/providers/clerk/server", () => ({
  createClerkDevelopmentIdentityProvider: vi.fn(),
}));

import { loadEvidencePageState, saveEvidenceArtifact } from "@/modules/evidence/dal";

const provider = {} as IdentityProvider;
const userId = "10000000-0000-4000-8000-000000000001";
const artifactId = "20000000-0000-4000-8000-000000000001";
const revisionId = "30000000-0000-4000-8000-000000000001";
const mutationId = "40000000-0000-4000-8000-000000000001";
const payload: EvidenceArtifactPayload = {
  schemaVersion: "source-verification-note-artifact-payload-v1",
  claimId: "bright-river-ai-summary-claim-v1",
  sourceReferenceIds: ["pilot-table"],
  fitCheckId: null,
  correctedWordingOptionId: null,
  safeNextActionOptionId: null,
};

const artifactRow = {
  id: artifactId,
  status: "draft",
  start_mutation_id: "50000000-0000-4000-8000-000000000001",
  start_mutation_locale: "en",
  ready_mutation_id: null,
  ready_mutation_locale: null,
  ready_expected_revision: null,
  withdraw_mutation_id: null,
  withdraw_mutation_locale: null,
  withdraw_expected_revision: null,
};
const revisionRow = {
  id: revisionId,
  revision: 1,
  payload,
  client_mutation_id: mutationId,
  mutation_intent: "save",
  mutation_locale: "en",
  mutation_expected_revision: 0,
};

function authorize(client: PoolClient) {
  authorization.run.mockImplementation(async (...args: unknown[]) => {
    const operation = args.find(
      (candidate): candidate is (client: PoolClient, userId: string) => Promise<unknown> =>
        typeof candidate === "function",
    );
    if (!operation) throw new Error("Authorization test operation is missing.");
    return { state: "authorized", value: await operation(client, userId) };
  });
}

function consentRow() {
  return { rows: [{ id: "60000000-0000-4000-8000-000000000001", decision: "granted" }] };
}

function sourceRow() {
  return {
    rows: [
      {
        lesson_id: "70000000-0000-4000-8000-000000000001",
        practice_id: "70000000-0000-4000-8000-000000000002",
        framework_id: "70000000-0000-4000-8000-000000000003",
        competency_id: "70000000-0000-4000-8000-000000000004",
      },
    ],
  };
}

describe("private evidence DAL", () => {
  beforeEach(() => {
    authorization.run.mockReset();
  });

  it("returns only client-safe controlled state and no internal UUID", async () => {
    const client = {
      query: vi.fn(async (sql: string) => {
        if (sql.includes("FROM consent_records")) return consentRow();
        if (sql.includes("FROM lesson_attempts AS la")) return sourceRow();
        if (sql.includes("FROM evidence_artifacts")) return { rows: [artifactRow] };
        if (sql.includes("FROM evidence_artifact_revisions")) return { rows: [revisionRow] };
        throw new Error(`Unexpected query: ${sql}`);
      }),
    } as unknown as PoolClient;
    authorize(client);
    const result = await loadEvidencePageState("en", provider);
    expect(result).toMatchObject({
      state: "artifact",
      artifact: { status: "draft", revision: 1, payload },
    });
    const exposed = JSON.stringify(result);
    for (const prohibited of [artifactId, revisionId, userId, "consent", "providerSubject"]) {
      expect(exposed).not.toContain(prohibited);
    }
  });

  it("replays an exact save and rejects conflicting UUID reuse without an insert", async () => {
    const mutations: string[] = [];
    const client = {
      query: vi.fn(async (sql: string) => {
        if (sql.includes("FROM consent_records")) return consentRow();
        if (sql.includes("FROM evidence_artifacts")) return { rows: [artifactRow] };
        if (sql.includes("client_mutation_id = $2")) return { rows: [revisionRow] };
        mutations.push(sql);
        throw new Error(`Unexpected mutation query: ${sql}`);
      }),
    } as unknown as PoolClient;
    authorize(client);
    const input = {
      locale: "en" as const,
      intent: "save" as const,
      payload,
      expectedRevision: 0,
      clientMutationId: mutationId,
    };
    await expect(saveEvidenceArtifact(input, provider)).resolves.toMatchObject({
      state: "saved",
      artifact: { revision: 1, payload },
    });
    await expect(
      saveEvidenceArtifact(
        { ...input, payload: { ...payload, sourceReferenceIds: ["scope-note"] } },
        provider,
      ),
    ).resolves.toEqual({ state: "conflict" });
    expect(mutations).toEqual([]);
  });

  it("rejects a stale distinct successor without appending history", async () => {
    const inserts: string[] = [];
    const client = {
      query: vi.fn(async (sql: string) => {
        if (sql.includes("FROM consent_records")) return consentRow();
        if (sql.includes("FROM evidence_artifacts")) return { rows: [artifactRow] };
        if (sql.includes("client_mutation_id = $2")) return { rows: [] };
        if (sql.includes("ORDER BY revision DESC LIMIT 1")) return { rows: [revisionRow] };
        if (sql.includes("INSERT")) inserts.push(sql);
        throw new Error(`Unexpected query: ${sql}`);
      }),
    } as unknown as PoolClient;
    authorize(client);
    await expect(
      saveEvidenceArtifact(
        {
          locale: "en",
          intent: "save",
          payload,
          expectedRevision: 0,
          clientMutationId: "40000000-0000-4000-8000-000000000002",
        },
        provider,
      ),
    ).resolves.toEqual({ state: "conflict" });
    expect(inserts).toEqual([]);
  });
});
