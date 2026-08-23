import type { PoolClient } from "pg";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { IdentityProvider } from "@/modules/identity/contract";
import type { PersistedLessonMutationInput } from "@/modules/lesson/persistence/contract";

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

import { mutatePersistedLesson } from "@/modules/lesson/persistence/dal";

const userId = "10000000-0000-4000-8000-000000000001";
const lessonId = "20000000-0000-4000-8000-000000000001";
const consentId = "30000000-0000-4000-8000-000000000001";
const provider = {} as IdentityProvider;
const canonicalSelections = [
  { criterionId: "evidence-traceability", optionId: "trace-claim-to-source-map" },
  { criterionId: "claim-source-fit", optionId: "fit-narrow-to-supported-teams" },
  { criterionId: "safe-next-action", optionId: "safe-hold-and-resolve-gaps" },
] as const;
const failedSelections = [
  canonicalSelections[0],
  { criterionId: "claim-source-fit", optionId: "fit-keep-all-team-claim" },
  canonicalSelections[2],
] as const;

type StoredPractice = Readonly<{
  id: string;
  revision: number;
  status: "draft" | "evaluated";
  response_payload: Readonly<Record<string, unknown>>;
  criterion_results: Readonly<Record<string, unknown>> | null;
  demonstrated: boolean | null;
  client_mutation_id: string;
  mutation_intent: "save" | "evaluate" | "retry";
  mutation_locale: "th" | "en";
  mutation_expected_revision: number;
}>;

function storedPractice(overrides: Partial<StoredPractice> = {}): StoredPractice {
  return {
    id: "40000000-0000-4000-8000-000000000001",
    revision: 1,
    status: "draft",
    response_payload: {
      schemaVersion: "source-verification-practice-response-v1",
      selections: canonicalSelections,
    },
    criterion_results: null,
    demonstrated: null,
    client_mutation_id: "50000000-0000-4000-8000-000000000001",
    mutation_intent: "save",
    mutation_locale: "en",
    mutation_expected_revision: 0,
    ...overrides,
  };
}

function failedEvaluation(overrides: Partial<StoredPractice> = {}): StoredPractice {
  return storedPractice({
    status: "evaluated",
    response_payload: {
      schemaVersion: "source-verification-practice-response-v1",
      selections: failedSelections,
    },
    criterion_results: {
      schemaVersion: "source-verification-evaluation-v1",
      criteria: failedSelections.map((selection, index) => ({
        criterionId: selection.criterionId,
        selectedOptionId: selection.optionId,
        status: index === 1 ? "not-met" : "met",
      })),
    },
    demonstrated: false,
    mutation_intent: "evaluate",
    ...overrides,
  });
}

type MutationInputOverrides = Omit<Partial<PersistedLessonMutationInput>, "selections"> &
  Readonly<{
    selections?: PersistedLessonMutationInput["selections"] | undefined;
  }>;

function input(overrides: MutationInputOverrides = {}) {
  const candidate: Record<string, unknown> = {
    locale: "en",
    intent: "save",
    selections: canonicalSelections,
    expectedRevision: 0,
    clientMutationId: "50000000-0000-4000-8000-000000000001",
    ...overrides,
  };
  if (candidate.intent === "retry" && candidate.selections === undefined) {
    delete candidate.selections;
  }
  return candidate as PersistedLessonMutationInput;
}

function useReplayTransaction(row: StoredPractice, lessonStatus: "in_progress" | "demonstrated") {
  const mutationQueries: string[] = [];
  const client = {
    query: vi.fn(async (sql: string) => {
      if (sql.includes("FROM consent_records")) {
        return { rows: [{ id: consentId, decision: "granted" }] };
      }
      if (sql.includes("FROM lesson_attempts")) {
        return { rows: [{ id: lessonId, status: lessonStatus }] };
      }
      if (sql.includes("client_mutation_id = $2")) return { rows: [row] };
      mutationQueries.push(sql);
      throw new Error(`Unexpected mutation query: ${sql}`);
    }),
  } as unknown as PoolClient;
  authorization.run.mockImplementation(
    async (
      _identityProvider: IdentityProvider,
      operation: (client: PoolClient, userId: string) => Promise<unknown>,
    ) => ({ state: "authorized", value: await operation(client, userId) }),
  );
  return mutationQueries;
}

class SerializedMutationHarness {
  readonly rows: StoredPractice[] = [];
  readonly events: string[] = [];
  lessonStatus: "in_progress" | "demonstrated" = "in_progress";
  lessonUpdates = 0;
  replayCount = 0;
  private tail: Promise<void> = Promise.resolve();

  async run(
    _identityProvider: IdentityProvider,
    operation: (client: PoolClient, userId: string) => Promise<unknown>,
  ) {
    const previous = this.tail;
    let release: () => void = () => {};
    this.tail = new Promise<void>((resolve) => {
      release = resolve;
    });
    await previous;
    try {
      return { state: "authorized", value: await operation(this.client(), userId) };
    } finally {
      release();
    }
  }

  private client(): PoolClient {
    return {
      query: async (sql: string, values?: readonly unknown[]) => {
        if (sql.includes("FROM consent_records")) {
          return { rows: [{ id: consentId, decision: "granted" }] };
        }
        if (sql.includes("FROM lesson_attempts")) {
          return { rows: [{ id: lessonId, status: this.lessonStatus }] };
        }
        if (sql.includes("client_mutation_id = $2")) {
          const replay = this.rows.find((row) => row.client_mutation_id === values?.[1]);
          if (replay) this.replayCount += 1;
          return { rows: replay ? [replay] : [] };
        }
        if (sql.includes("ORDER BY revision DESC LIMIT 1")) {
          return { rows: this.rows.length ? [this.rows.at(-1)!] : [] };
        }
        if (sql.includes("INSERT INTO practice_attempts")) {
          const row = storedPractice({
            id: `40000000-0000-4000-8000-${String(this.rows.length + 1).padStart(12, "0")}`,
            revision: values?.[2] as number,
            status: values?.[4] as "draft" | "evaluated",
            response_payload: JSON.parse(values?.[5] as string) as Readonly<
              Record<string, unknown>
            >,
            criterion_results: values?.[11]
              ? (JSON.parse(values[11] as string) as Readonly<Record<string, unknown>>)
              : null,
            demonstrated: (values?.[12] as boolean | null) ?? null,
            client_mutation_id: values?.[13] as string,
            mutation_intent: values?.[14] as "save" | "evaluate" | "retry",
            mutation_locale: values?.[15] as "th" | "en",
            mutation_expected_revision: values?.[16] as number,
          });
          this.rows.push(row);
          return { rows: [{ id: row.id }] };
        }
        if (sql.includes("UPDATE lesson_attempts")) {
          this.lessonUpdates += 1;
          if (values?.[1] === true) this.lessonStatus = "demonstrated";
          return { rows: [] };
        }
        if (sql.includes("INSERT INTO learning_progress_events")) {
          this.events.push(
            sql.includes("practice_demonstrated") ? "practice_demonstrated" : "practice_evaluated",
          );
          return { rows: [] };
        }
        throw new Error(`Unexpected query: ${sql}`);
      },
    } as unknown as PoolClient;
  }
}

describe("persisted lesson mutation replay", () => {
  beforeEach(() => {
    authorization.run.mockReset();
  });

  it("returns the original save, evaluation and retry for exact replays", async () => {
    const saveQueries = useReplayTransaction(storedPractice(), "in_progress");
    await expect(mutatePersistedLesson(input(), provider)).resolves.toMatchObject({
      state: "saved",
      revision: 1,
    });
    expect(saveQueries).toEqual([]);

    const evaluationRow = storedPractice({
      status: "evaluated",
      criterion_results: {
        schemaVersion: "source-verification-evaluation-v1",
        criteria: canonicalSelections.map((selection) => ({
          criterionId: selection.criterionId,
          selectedOptionId: selection.optionId,
          status: "met",
        })),
      },
      demonstrated: true,
      mutation_intent: "evaluate",
    });
    const evaluationQueries = useReplayTransaction(evaluationRow, "demonstrated");
    await expect(
      mutatePersistedLesson(input({ intent: "evaluate" }), provider),
    ).resolves.toMatchObject({ state: "demonstrated", revision: 1 });
    expect(evaluationQueries).toEqual([]);

    const retryRow = storedPractice({
      revision: 3,
      client_mutation_id: "50000000-0000-4000-8000-000000000003",
      mutation_intent: "retry",
      mutation_locale: "th",
      mutation_expected_revision: 2,
    });
    const retryQueries = useReplayTransaction(retryRow, "in_progress");
    await expect(
      mutatePersistedLesson(
        input({
          locale: "th",
          intent: "retry",
          selections: undefined,
          expectedRevision: 2,
          clientMutationId: retryRow.client_mutation_id,
        }),
        provider,
      ),
    ).resolves.toMatchObject({ state: "saved", revision: 3 });
    expect(retryQueries).toEqual([]);
  });

  it.each([
    ["intent", input({ intent: "evaluate" })],
    ["locale", input({ locale: "th" })],
    ["expected revision", input({ expectedRevision: 1 })],
    [
      "criterion selection",
      input({ selections: [canonicalSelections[1], canonicalSelections[2]] }),
    ],
    [
      "option selection",
      input({
        selections: [
          { criterionId: "evidence-traceability", optionId: "trace-remove-source-notes" },
          canonicalSelections[1],
          canonicalSelections[2],
        ],
      }),
    ],
    ["selection presence", input({ intent: "retry", selections: undefined })],
  ] as const)("returns conflict for reused UUID with different %s", async (_label, request) => {
    const harness = new SerializedMutationHarness();
    harness.rows.push(storedPractice());
    authorization.run.mockImplementation(harness.run.bind(harness));
    await expect(mutatePersistedLesson(request, provider)).resolves.toEqual({ state: "conflict" });
    expect(harness.rows).toHaveLength(1);
    expect(harness.events).toHaveLength(0);
    expect(harness.lessonUpdates).toBe(0);
  });

  it("commits one revision and replays once for concurrent identical delivery", async () => {
    const harness = new SerializedMutationHarness();
    authorization.run.mockImplementation(harness.run.bind(harness));
    const request = input();
    const results = await Promise.all([
      mutatePersistedLesson(request, provider),
      mutatePersistedLesson(request, provider),
    ]);
    expect(results).toEqual([
      { state: "saved", revision: 1, selections: canonicalSelections, results: null },
      { state: "saved", revision: 1, selections: canonicalSelections, results: null },
    ]);
    expect(harness.rows).toHaveLength(1);
    expect(harness.events).toHaveLength(0);
    expect(harness.lessonUpdates).toBe(1);
    expect(harness.replayCount).toBe(1);
  });

  it("commits one successor and conflicts one concurrent distinct mutation", async () => {
    const harness = new SerializedMutationHarness();
    authorization.run.mockImplementation(harness.run.bind(harness));
    const results = await Promise.all([
      mutatePersistedLesson(input(), provider),
      mutatePersistedLesson(
        input({ clientMutationId: "50000000-0000-4000-8000-000000000002" }),
        provider,
      ),
    ]);
    expect(results.map((result) => result.state).sort()).toEqual(["conflict", "saved"]);
    expect(harness.rows).toHaveLength(1);
    expect(harness.events).toHaveLength(0);
    expect(harness.lessonUpdates).toBe(1);
  });

  it.each(["save", "evaluate"] as const)(
    "denies direct %s after a failed evaluation without changing state",
    async (intent) => {
      const harness = new SerializedMutationHarness();
      harness.rows.push(failedEvaluation());
      authorization.run.mockImplementation(harness.run.bind(harness));
      await expect(
        mutatePersistedLesson(
          input({
            intent,
            expectedRevision: 1,
            clientMutationId: `50000000-0000-4000-8000-00000000001${intent === "save" ? "0" : "1"}`,
          }),
          provider,
        ),
      ).resolves.toEqual({ state: "not-ready" });
      expect(harness.rows).toHaveLength(1);
      expect(harness.events).toHaveLength(0);
      expect(harness.lessonUpdates).toBe(0);
      expect(harness.lessonStatus).toBe("in_progress");
    },
  );

  it("creates one exact retry revision and replays it without another mutation", async () => {
    const harness = new SerializedMutationHarness();
    harness.rows.push(failedEvaluation());
    authorization.run.mockImplementation(harness.run.bind(harness));
    const retryRequest = input({
      intent: "retry",
      selections: undefined,
      expectedRevision: 1,
      clientMutationId: "50000000-0000-4000-8000-000000000012",
    });
    await expect(mutatePersistedLesson(retryRequest, provider)).resolves.toMatchObject({
      state: "saved",
      revision: 2,
      selections: failedSelections,
      results: null,
    });
    expect(harness.rows).toHaveLength(2);
    expect(harness.rows[1]).toMatchObject({
      revision: 2,
      status: "draft",
      response_payload: harness.rows[0]!.response_payload,
      mutation_intent: "retry",
      mutation_expected_revision: 1,
    });
    expect(harness.events).toHaveLength(0);
    expect(harness.lessonUpdates).toBe(1);
    expect(harness.lessonStatus).toBe("in_progress");

    await expect(mutatePersistedLesson(retryRequest, provider)).resolves.toMatchObject({
      state: "saved",
      revision: 2,
    });
    expect(harness.rows).toHaveLength(2);
    expect(harness.events).toHaveLength(0);
    expect(harness.lessonUpdates).toBe(1);
    expect(harness.replayCount).toBe(1);
  });

  it.each(["save", "evaluate"] as const)(
    "allows %s after the explicit retry draft",
    async (intent) => {
      const harness = new SerializedMutationHarness();
      harness.rows.push(failedEvaluation());
      authorization.run.mockImplementation(harness.run.bind(harness));
      await mutatePersistedLesson(
        input({
          intent: "retry",
          selections: undefined,
          expectedRevision: 1,
          clientMutationId: "50000000-0000-4000-8000-000000000013",
        }),
        provider,
      );
      const result = await mutatePersistedLesson(
        input({
          intent,
          expectedRevision: 2,
          clientMutationId: `50000000-0000-4000-8000-00000000001${intent === "save" ? "4" : "5"}`,
        }),
        provider,
      );
      expect(result).toMatchObject({
        state: intent === "save" ? "saved" : "demonstrated",
        revision: 3,
      });
      expect(harness.rows).toHaveLength(3);
      expect(harness.lessonUpdates).toBe(2);
      expect(harness.events).toHaveLength(intent === "save" ? 0 : 2);
    },
  );

  it("denies retry from an ordinary draft and with no prior revision", async () => {
    const draftHarness = new SerializedMutationHarness();
    draftHarness.rows.push(storedPractice());
    authorization.run.mockImplementation(draftHarness.run.bind(draftHarness));
    await expect(
      mutatePersistedLesson(
        input({
          intent: "retry",
          selections: undefined,
          expectedRevision: 1,
          clientMutationId: "50000000-0000-4000-8000-000000000016",
        }),
        provider,
      ),
    ).resolves.toEqual({ state: "not-ready" });
    expect(draftHarness.rows).toHaveLength(1);
    expect(draftHarness.events).toHaveLength(0);
    expect(draftHarness.lessonUpdates).toBe(0);

    const emptyHarness = new SerializedMutationHarness();
    authorization.run.mockImplementation(emptyHarness.run.bind(emptyHarness));
    await expect(
      mutatePersistedLesson(
        input({
          intent: "retry",
          selections: undefined,
          clientMutationId: "50000000-0000-4000-8000-000000000017",
        }),
        provider,
      ),
    ).resolves.toEqual({ state: "not-ready" });
    expect(emptyHarness.rows).toHaveLength(0);
    expect(emptyHarness.events).toHaveLength(0);
    expect(emptyHarness.lessonUpdates).toBe(0);
  });

  it("denies every new mutation after demonstration but preserves exact replay", async () => {
    const demonstrated = failedEvaluation({
      demonstrated: true,
      criterion_results: {
        schemaVersion: "source-verification-evaluation-v1",
        criteria: canonicalSelections.map((selection) => ({
          criterionId: selection.criterionId,
          selectedOptionId: selection.optionId,
          status: "met",
        })),
      },
      response_payload: {
        schemaVersion: "source-verification-practice-response-v1",
        selections: canonicalSelections,
      },
    });
    const harness = new SerializedMutationHarness();
    harness.rows.push(demonstrated);
    harness.lessonStatus = "demonstrated";
    authorization.run.mockImplementation(harness.run.bind(harness));
    for (const [intent, clientMutationId] of [
      ["save", "50000000-0000-4000-8000-000000000018"],
      ["evaluate", "50000000-0000-4000-8000-000000000019"],
      ["retry", "50000000-0000-4000-8000-000000000020"],
    ] as const) {
      await expect(
        mutatePersistedLesson(
          input({
            intent,
            selections: intent === "retry" ? undefined : canonicalSelections,
            expectedRevision: 1,
            clientMutationId,
          }),
          provider,
        ),
      ).resolves.toEqual({ state: "not-ready" });
    }
    expect(harness.rows).toHaveLength(1);
    expect(harness.events).toHaveLength(0);
    expect(harness.lessonUpdates).toBe(0);

    await expect(
      mutatePersistedLesson(input({ intent: "evaluate" }), provider),
    ).resolves.toMatchObject({ state: "demonstrated", revision: 1 });
    expect(harness.rows).toHaveLength(1);
    expect(harness.lessonUpdates).toBe(0);
    expect(harness.replayCount).toBe(1);
  });
});
