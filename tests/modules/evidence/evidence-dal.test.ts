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

import {
  loadEvidencePageState,
  mutateEvidenceLifecycle,
  saveEvidenceArtifact,
  startEvidenceArtifact,
} from "@/modules/evidence/dal";

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
const currentPayload: EvidenceArtifactPayload = {
  ...payload,
  sourceReferenceIds: ["pilot-table", "scope-note"],
  fitCheckId: "partially-supported-overgeneralized",
};
const currentRevisionRow = {
  id: "30000000-0000-4000-8000-000000000002",
  revision: 2,
  payload: currentPayload,
  client_mutation_id: "40000000-0000-4000-8000-000000000002",
  mutation_intent: "save",
  mutation_locale: "th",
  mutation_expected_revision: 1,
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

function authorizeSerially(client: PoolClient) {
  let queue = Promise.resolve();
  authorization.run.mockImplementation((...args: unknown[]) => {
    const operation = args.find(
      (candidate): candidate is (client: PoolClient, userId: string) => Promise<unknown> =>
        typeof candidate === "function",
    );
    if (!operation) throw new Error("Authorization test operation is missing.");
    const result = queue.then(async () => ({
      state: "authorized" as const,
      value: await operation(client, userId),
    }));
    queue = result.then(
      () => undefined,
      () => undefined,
    );
    return result;
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
        if (sql.includes("ORDER BY revision DESC LIMIT 1")) return { rows: [revisionRow] };
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

  it.each([
    {
      status: "draft" as const,
      expectedState: "saved" as const,
      lifecycle: {},
    },
    {
      status: "ready" as const,
      expectedState: "ready" as const,
      lifecycle: {
        ready_mutation_id: "40000000-0000-4000-8000-000000000010",
        ready_mutation_locale: "en",
        ready_expected_revision: 2,
      },
    },
    {
      status: "withdrawn" as const,
      expectedState: "withdrawn" as const,
      lifecycle: {
        ready_mutation_id: "40000000-0000-4000-8000-000000000010",
        ready_mutation_locale: "en",
        ready_expected_revision: 2,
        withdraw_mutation_id: "40000000-0000-4000-8000-000000000011",
        withdraw_mutation_locale: "th",
        withdraw_expected_revision: 2,
      },
    },
  ])(
    "replays historical revision 1 while revision 2 is current after $status",
    async ({ status, expectedState, lifecycle }) => {
      const writes: string[] = [];
      const storedTimestamps = {
        createdAt: "2026-08-23T10:00:00.000Z",
        updatedAt: "2026-08-23T10:02:00.000Z",
        readyAt: status === "draft" ? null : "2026-08-23T10:03:00.000Z",
        withdrawnAt: status === "withdrawn" ? "2026-08-23T10:04:00.000Z" : null,
        revisions: ["2026-08-23T10:01:00.000Z", "2026-08-23T10:02:00.000Z"],
      };
      const before = structuredClone(storedTimestamps);
      const query = vi.fn(async (sql: string) => {
        if (sql.includes("FROM consent_records")) return consentRow();
        if (sql.includes("FROM evidence_artifacts")) {
          return { rows: [{ ...artifactRow, ...lifecycle, status }] };
        }
        if (sql.includes("client_mutation_id = $2")) return { rows: [revisionRow] };
        if (sql.includes("ORDER BY revision DESC LIMIT 1")) {
          return { rows: [currentRevisionRow] };
        }
        if (/\b(?:INSERT|UPDATE|DELETE)\b/iu.test(sql)) writes.push(sql);
        throw new Error(`Unexpected query: ${sql}`);
      });
      const client = {
        query,
      } as unknown as PoolClient;
      authorize(client);
      await expect(
        saveEvidenceArtifact(
          {
            locale: "en",
            intent: "save",
            payload,
            expectedRevision: 0,
            clientMutationId: mutationId,
          },
          provider,
        ),
      ).resolves.toMatchObject({
        state: expectedState,
        artifact: { status, revision: 2, payload: currentPayload },
      });
      expect(writes).toEqual([]);
      expect(storedTimestamps).toEqual(before);
      expect(query).toHaveBeenCalledTimes(4);
      expect(query.mock.calls.every(([sql]) => /^\s*SELECT\b/iu.test(sql))).toBe(true);
    },
  );

  it("keeps conflicting historical save UUID reuse controlled while revision 2 is current", async () => {
    const writes: string[] = [];
    const client = {
      query: vi.fn(async (sql: string) => {
        if (sql.includes("FROM consent_records")) return consentRow();
        if (sql.includes("FROM evidence_artifacts")) return { rows: [artifactRow] };
        if (sql.includes("client_mutation_id = $2")) return { rows: [revisionRow] };
        if (/\b(?:INSERT|UPDATE|DELETE)\b/iu.test(sql)) writes.push(sql);
        throw new Error(`Unexpected query: ${sql}`);
      }),
    } as unknown as PoolClient;
    authorize(client);
    await expect(
      saveEvidenceArtifact(
        {
          locale: "en",
          intent: "save",
          payload: { ...payload, sourceReferenceIds: ["scope-note"] },
          expectedRevision: 0,
          clientMutationId: mutationId,
        },
        provider,
      ),
    ).resolves.toEqual({ state: "conflict" });
    expect(writes).toEqual([]);
    expect(client.query).not.toHaveBeenCalledWith(
      expect.stringContaining("ORDER BY revision DESC LIMIT 1"),
      expect.anything(),
    );
  });

  it("reports withdrawn when replaying the earlier ready mutation after withdrawal", async () => {
    const readyMutationId = "40000000-0000-4000-8000-000000000010";
    const client = {
      query: vi.fn(async (sql: string) => {
        if (sql.includes("FROM consent_records")) return consentRow();
        if (sql.includes("FROM evidence_artifacts")) {
          return {
            rows: [
              {
                ...artifactRow,
                status: "withdrawn",
                ready_mutation_id: readyMutationId,
                ready_mutation_locale: "en",
                ready_expected_revision: 1,
                withdraw_mutation_id: "40000000-0000-4000-8000-000000000011",
                withdraw_mutation_locale: "th",
                withdraw_expected_revision: 1,
              },
            ],
          };
        }
        if (sql.includes("ORDER BY revision DESC LIMIT 1")) return { rows: [revisionRow] };
        throw new Error(`Unexpected query: ${sql}`);
      }),
    } as unknown as PoolClient;
    authorize(client);
    await expect(
      mutateEvidenceLifecycle(
        {
          locale: "en",
          intent: "ready",
          expectedRevision: 1,
          clientMutationId: readyMutationId,
        },
        provider,
      ),
    ).resolves.toMatchObject({
      state: "withdrawn",
      artifact: { status: "withdrawn", revision: 1 },
    });
  });

  it.each([
    {
      status: "ready" as const,
      reusedMutationId: "40000000-0000-4000-8000-000000000010",
      lifecycle: {
        ready_mutation_id: "40000000-0000-4000-8000-000000000010",
        ready_mutation_locale: "en",
        ready_expected_revision: 1,
      },
    },
    {
      status: "withdrawn" as const,
      reusedMutationId: "40000000-0000-4000-8000-000000000011",
      lifecycle: {
        ready_mutation_id: "40000000-0000-4000-8000-000000000010",
        ready_mutation_locale: "en",
        ready_expected_revision: 1,
        withdraw_mutation_id: "40000000-0000-4000-8000-000000000011",
        withdraw_mutation_locale: "th",
        withdraw_expected_revision: 1,
      },
    },
  ])(
    "rejects cross-intent save UUID reuse while $status without mutation",
    async ({ status, reusedMutationId, lifecycle }) => {
      const writes: string[] = [];
      const client = {
        query: vi.fn(async (sql: string) => {
          if (sql.includes("FROM consent_records")) return consentRow();
          if (sql.includes("FROM evidence_artifacts")) {
            return { rows: [{ ...artifactRow, ...lifecycle, status }] };
          }
          if (sql.includes("client_mutation_id = $2")) return { rows: [] };
          if (/INSERT|UPDATE|DELETE/iu.test(sql)) writes.push(sql);
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
            expectedRevision: 1,
            clientMutationId: reusedMutationId,
          },
          provider,
        ),
      ).resolves.toEqual({ state: "conflict" });
      expect(writes).toEqual([]);
    },
  );

  it("rejects a save mutation UUID reused for lifecycle after withdrawal", async () => {
    const client = {
      query: vi.fn(async (sql: string) => {
        if (sql.includes("FROM consent_records")) return consentRow();
        if (sql.includes("FROM evidence_artifacts")) {
          return {
            rows: [
              {
                ...artifactRow,
                status: "withdrawn",
                ready_mutation_id: "40000000-0000-4000-8000-000000000010",
                ready_mutation_locale: "en",
                ready_expected_revision: 1,
                withdraw_mutation_id: "40000000-0000-4000-8000-000000000011",
                withdraw_mutation_locale: "th",
                withdraw_expected_revision: 1,
              },
            ],
          };
        }
        if (sql.includes("ORDER BY revision DESC LIMIT 1")) return { rows: [revisionRow] };
        if (sql.includes("SELECT EXISTS")) return { rows: [{ present: true }] };
        throw new Error(`Unexpected query: ${sql}`);
      }),
    } as unknown as PoolClient;
    authorize(client);
    await expect(
      mutateEvidenceLifecycle(
        {
          locale: "en",
          intent: "ready",
          expectedRevision: 1,
          clientMutationId: mutationId,
        },
        provider,
      ),
    ).resolves.toEqual({ state: "conflict" });
  });

  it.each(["absent", "non-demonstrated"])(
    "denies an explicit start when the source practice is %s",
    async (sourceState) => {
      const writes: string[] = [];
      const client = {
        query: vi.fn(async (sql: string) => {
          if (sql.includes("FROM consent_records")) return consentRow();
          if (sql.includes("FROM lesson_attempts AS la")) {
            if (sourceState === "non-demonstrated") {
              expect(sql).toContain("la.status = 'demonstrated'");
              expect(sql).toContain("pa.status = 'evaluated'");
              expect(sql).toContain("pa.demonstrated = true");
            }
            return { rows: [] };
          }
          if (/INSERT|UPDATE|DELETE/iu.test(sql)) writes.push(sql);
          throw new Error(`Unexpected query: ${sql}`);
        }),
      } as unknown as PoolClient;
      authorize(client);
      await expect(
        startEvidenceArtifact(
          {
            locale: "en",
            clientMutationId: "40000000-0000-4000-8000-000000000020",
          },
          provider,
        ),
      ).resolves.toEqual({ state: "not-ready" });
      expect(writes).toEqual([]);
    },
  );

  it("serializes concurrent starts so both converge on one artifact", async () => {
    let created = false;
    let storedStartMutationId = "";
    let artifactInserts = 0;
    let linkInserts = 0;
    const client = {
      query: vi.fn(async (sql: string, values?: unknown[]) => {
        if (sql.includes("FROM consent_records")) return consentRow();
        if (sql.includes("FROM lesson_attempts AS la")) return sourceRow();
        if (sql.includes("pg_advisory_xact_lock")) return { rows: [] };
        if (sql.includes("FROM evidence_artifacts")) {
          return {
            rows: created ? [{ ...artifactRow, start_mutation_id: storedStartMutationId }] : [],
          };
        }
        if (sql.includes("INSERT INTO evidence_artifacts")) {
          artifactInserts += 1;
          storedStartMutationId = String(values?.[15]);
          created = true;
          return { rows: [{ id: artifactId }] };
        }
        if (sql.includes("INSERT INTO evidence_competency_links")) {
          linkInserts += 1;
          return { rows: [] };
        }
        if (sql.includes("FROM evidence_artifact_revisions")) return { rows: [] };
        throw new Error(`Unexpected query: ${sql}`);
      }),
    } as unknown as PoolClient;
    authorizeSerially(client);
    const results = await Promise.all([
      startEvidenceArtifact(
        { locale: "en", clientMutationId: "40000000-0000-4000-8000-000000000021" },
        provider,
      ),
      startEvidenceArtifact(
        { locale: "th", clientMutationId: "40000000-0000-4000-8000-000000000022" },
        provider,
      ),
    ]);
    expect(results).toHaveLength(2);
    expect(results.every((result) => result.state === "saved")).toBe(true);
    expect(artifactInserts).toBe(1);
    expect(linkInserts).toBe(1);
  });

  it("serializes concurrent distinct saves so one appends and one conflicts", async () => {
    let storedRevision: typeof revisionRow | null = null;
    let revisionInserts = 0;
    const client = {
      query: vi.fn(async (sql: string, values?: unknown[]) => {
        if (sql.includes("FROM consent_records")) return consentRow();
        if (sql.includes("FROM evidence_artifacts")) return { rows: [artifactRow] };
        if (sql.includes("client_mutation_id = $2")) return { rows: [] };
        if (sql.includes("ORDER BY revision DESC LIMIT 1")) {
          return { rows: storedRevision ? [storedRevision] : [] };
        }
        if (sql.includes("INSERT INTO evidence_artifact_revisions")) {
          revisionInserts += 1;
          storedRevision = {
            ...revisionRow,
            client_mutation_id: String(values?.[8]),
            mutation_locale: String(values?.[9]),
          };
          return { rows: [storedRevision] };
        }
        throw new Error(`Unexpected query: ${sql}`);
      }),
    } as unknown as PoolClient;
    authorizeSerially(client);
    const results = await Promise.all([
      saveEvidenceArtifact(
        {
          locale: "en",
          intent: "save",
          payload,
          expectedRevision: 0,
          clientMutationId: "40000000-0000-4000-8000-000000000023",
        },
        provider,
      ),
      saveEvidenceArtifact(
        {
          locale: "th",
          intent: "save",
          payload: { ...payload, sourceReferenceIds: ["scope-note"] },
          expectedRevision: 0,
          clientMutationId: "40000000-0000-4000-8000-000000000024",
        },
        provider,
      ),
    ]);
    expect(results.map(({ state }) => state).sort()).toEqual(["conflict", "saved"]);
    expect(revisionInserts).toBe(1);
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
