import { createHash } from "node:crypto";

export const alphaExportContractVersion = "rise-pals-alpha-export-v1@1.0.0";
export const alphaExportMaximumRowsPerSection = 500;

const ownerIdPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const queryPlan = [
  {
    key: "account",
    one: true,
    sql: `SELECT status, created_at, updated_at, last_seen_at,
                 deletion_requested_at, deleted_at
          FROM user_accounts
          WHERE id = $1
          LIMIT 2`,
  },
  {
    key: "profile",
    one: true,
    sql: `SELECT preferred_locale, timezone, role_family, function,
                 experience_band, goals, onboarding_completed_at,
                 profile_schema_version, updated_at
          FROM user_profiles
          WHERE user_id = $1
          LIMIT 2`,
  },
  {
    key: "consents",
    sql: `SELECT purpose_code, notice_version, decision, occurred_at,
                 locale, source_surface
          FROM consent_records
          WHERE user_id = $1
          ORDER BY occurred_at, purpose_code, notice_version, id
          LIMIT 501`,
  },
  {
    key: "assessmentSessions",
    sql: `SELECT s.id AS internal_id, s.status, s.started_at, s.updated_at,
                 s.submitted_at, a.assessment_key, a.version AS assessment_version,
                 a.content_digest AS assessment_digest,
                 f.framework_key, f.version AS framework_version,
                 f.content_digest AS framework_digest,
                 m.model_key AS scoring_model_key,
                 m.version AS scoring_model_version,
                 m.content_digest AS scoring_model_digest
          FROM assessment_sessions s
          JOIN assessment_versions a ON a.id = s.assessment_version_id
          JOIN framework_versions f ON f.id = a.framework_version_id
          JOIN scoring_model_versions m ON m.id = a.scoring_model_version_id
          WHERE s.user_id = $1
          ORDER BY s.started_at, s.id
          LIMIT 501`,
  },
  {
    key: "assessmentResponses",
    sql: `SELECT r.session_id AS internal_session_id, i.item_key,
                 r.revision, r.response_payload, r.is_active, r.created_at
          FROM assessment_responses r
          JOIN assessment_sessions s ON s.id = r.session_id
          JOIN assessment_item_versions i ON i.id = r.assessment_item_version_id
          WHERE s.user_id = $1
          ORDER BY r.session_id, i.display_order, r.revision, r.id
          LIMIT 501`,
  },
  {
    key: "scoringRuns",
    sql: `SELECT r.id AS internal_id, r.assessment_session_id AS internal_session_id,
                 r.run_number, r.run_kind, r.result_policy_key,
                 r.result_policy_version, r.result_policy_digest, r.computed_at
          FROM scoring_runs r
          WHERE r.user_id = $1
          ORDER BY r.computed_at, r.run_number, r.id
          LIMIT 501`,
  },
  {
    key: "coreScores",
    sql: `SELECT s.scoring_run_id AS internal_run_id, c.competency_key,
                 s.earned_points, s.available_points, s.evidence_count,
                 s.normalized_basis_points, s.created_at
          FROM competency_scores s
          JOIN competency_versions c ON c.id = s.competency_version_id
          WHERE s.user_id = $1
          ORDER BY s.scoring_run_id, c.display_order, s.id
          LIMIT 501`,
  },
  {
    key: "multiplierObservations",
    sql: `SELECT o.scoring_run_id AS internal_run_id, c.competency_key,
                 o.earned_rubric_points, o.available_rubric_points,
                 o.evidence_count, o.limitation_code, o.created_at
          FROM multiplier_observations o
          JOIN competency_versions c ON c.id = o.competency_version_id
          WHERE o.user_id = $1
          ORDER BY o.scoring_run_id, c.display_order, o.id
          LIMIT 501`,
  },
  {
    key: "scoreExplanations",
    sql: `SELECT e.scoring_run_id AS internal_run_id, e.target_kind,
                 c.competency_key, e.explanation_code, e.message_params,
                 e.supporting_item_keys, e.limitation_codes, e.created_at
          FROM score_explanations e
          LEFT JOIN competency_versions c ON c.id = e.competency_version_id
          WHERE e.user_id = $1
          ORDER BY e.scoring_run_id, e.target_kind, c.display_order NULLS FIRST, e.id
          LIMIT 501`,
  },
  {
    key: "priorities",
    sql: `SELECT p.scoring_run_id AS internal_run_id, c.competency_key,
                 p.rank, p.reason_code, p.supporting_item_keys,
                 p.next_action, p.created_at
          FROM priority_recommendations p
          JOIN competency_versions c ON c.id = p.competency_version_id
          WHERE p.user_id = $1
          ORDER BY p.scoring_run_id, p.rank, p.id
          LIMIT 501`,
  },
  {
    key: "lessonAttempts",
    sql: `SELECT id AS internal_id, lesson_key, lesson_version_id, lesson_version,
                 lesson_digest, practice_id, practice_version, rubric_version_id,
                 rubric_version, evaluation_contract_version_id, status,
                 started_at, last_meaningful_activity_at, demonstrated_at
          FROM lesson_attempts
          WHERE user_id = $1
          ORDER BY started_at, id
          LIMIT 501`,
  },
  {
    key: "practiceAttempts",
    sql: `SELECT lesson_attempt_id AS internal_lesson_id, revision, mutation_intent,
                 status, response_payload, criterion_results, demonstrated, created_at
          FROM practice_attempts
          WHERE user_id = $1
          ORDER BY lesson_attempt_id, revision, id
          LIMIT 501`,
  },
  {
    key: "progressEvents",
    sql: `SELECT lesson_attempt_id AS internal_lesson_id, event_kind,
                 event_schema_version, occurred_at
          FROM learning_progress_events
          WHERE user_id = $1
          ORDER BY lesson_attempt_id, occurred_at, event_kind, id
          LIMIT 501`,
  },
  {
    key: "evidenceArtifacts",
    sql: `SELECT id AS internal_id, artifact_contract_id, artifact_contract_version,
                 artifact_type, source_proof_id, source_proof_version,
                 source_lesson_key, source_lesson_version, source_lesson_digest,
                 source_pack_id, classification, validation_status, status,
                 created_at, updated_at, ready_at, withdrawn_at
          FROM evidence_artifacts
          WHERE user_id = $1
          ORDER BY created_at, id
          LIMIT 501`,
  },
  {
    key: "evidenceRevisions",
    sql: `SELECT artifact_id AS internal_artifact_id, revision, payload,
                 mutation_intent, mutation_locale, mutation_expected_revision, created_at
          FROM evidence_artifact_revisions
          WHERE user_id = $1
          ORDER BY artifact_id, revision, id
          LIMIT 501`,
  },
  {
    key: "evidenceLinks",
    sql: `SELECT l.artifact_id AS internal_artifact_id, c.competency_key,
                 l.relationship_code, l.created_at
          FROM evidence_competency_links l
          JOIN competency_versions c ON c.id = l.competency_version_id
          WHERE l.user_id = $1
          ORDER BY l.artifact_id, c.display_order, l.id
          LIMIT 501`,
  },
  {
    key: "productEvents",
    sql: `SELECT e.schema_version, e.event_class, e.surface_code,
                 e.operation_code, e.occurred_at
          FROM product_events e
          JOIN measurement_subjects s ON s.id = e.measurement_subject_id
          WHERE s.user_id = $1
          ORDER BY e.occurred_at, e.event_class, e.surface_code, e.operation_code, e.id
          LIMIT 501`,
  },
];

function normalize(value) {
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) return value.map(normalize);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value)
        .filter(([, entry]) => entry !== undefined)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, entry]) => [key, normalize(entry)]),
    );
  }
  return value;
}

function withoutInternalKeys(row) {
  return Object.fromEntries(
    Object.entries(row)
      .filter(([key]) => !key.startsWith("internal_"))
      .map(([key, value]) => [key, normalize(value)]),
  );
}

function localReferenceMap(rows, prefix) {
  return new Map(rows.map((row, index) => [row.internal_id, `${prefix}-${index + 1}`]));
}

function requireBoundedRows(key, rows, one) {
  const maximum = one ? 1 : alphaExportMaximumRowsPerSection;
  if (rows.length > maximum) {
    throw new Error(`Alpha export section ${key} exceeded its bounded row limit.`);
  }
  return rows;
}

export async function loadAlphaOwnerExportSource(client, ownerId) {
  if (!ownerIdPattern.test(ownerId)) {
    throw new Error("Alpha export requires a canonical internal owner UUID.");
  }

  const source = {};
  for (const entry of queryPlan) {
    const result = await client.query(entry.sql, [ownerId]);
    source[entry.key] = requireBoundedRows(entry.key, result.rows, entry.one);
  }
  if (source.account.length !== 1) {
    throw new Error("Alpha export owner account is unavailable or ambiguous.");
  }
  return source;
}

export function createCanonicalAlphaExport(source) {
  const sessions = localReferenceMap(source.assessmentSessions, "assessment-session");
  const runs = localReferenceMap(source.scoringRuns, "scoring-run");
  const lessons = localReferenceMap(source.lessonAttempts, "lesson-attempt");
  const artifacts = localReferenceMap(source.evidenceArtifacts, "evidence-artifact");

  const withRef = (row, internalKey, map, referenceKey) => ({
    [referenceKey]: map.get(row[internalKey]),
    ...withoutInternalKeys(row),
  });

  const exportDocument = {
    contractVersion: alphaExportContractVersion,
    manifest: {
      en: {
        title: "Rise Pals synthetic-alpha owner export",
        limitation:
          "This export contains synthetic-alpha prototype records. It is not a validated proficiency, employment-suitability, legal-completeness, or production-readiness statement.",
      },
      th: {
        title: "ข้อมูลส่งออกสำหรับเจ้าของข้อมูลใน Rise Pals รุ่นอัลฟาสังเคราะห์",
        limitation:
          "ข้อมูลนี้เป็นบันทึกจากต้นแบบอัลฟาสังเคราะห์ ไม่ใช่ผลยืนยันทักษะ ความเหมาะสมต่อการจ้างงาน ความครบถ้วนทางกฎหมาย หรือความพร้อมใช้งานจริง",
      },
    },
    owner: {
      account: withoutInternalKeys(source.account[0]),
      profile: source.profile[0] ? withoutInternalKeys(source.profile[0]) : null,
      consents: source.consents.map(withoutInternalKeys),
    },
    assessment: {
      sessions: source.assessmentSessions.map((row, index) => ({
        ref: `assessment-session-${index + 1}`,
        ...withoutInternalKeys(row),
      })),
      responses: source.assessmentResponses.map((row) =>
        withRef(row, "internal_session_id", sessions, "sessionRef"),
      ),
    },
    scoring: {
      runs: source.scoringRuns.map((row, index) => ({
        ref: `scoring-run-${index + 1}`,
        sessionRef: sessions.get(row.internal_session_id),
        ...withoutInternalKeys(row),
      })),
      coreSignals: source.coreScores.map((row) => withRef(row, "internal_run_id", runs, "runRef")),
      multiplierObservations: source.multiplierObservations.map((row) =>
        withRef(row, "internal_run_id", runs, "runRef"),
      ),
      explanations: source.scoreExplanations.map((row) =>
        withRef(row, "internal_run_id", runs, "runRef"),
      ),
      priorities: source.priorities.map((row) => withRef(row, "internal_run_id", runs, "runRef")),
    },
    learning: {
      lessons: source.lessonAttempts.map((row, index) => ({
        ref: `lesson-attempt-${index + 1}`,
        ...withoutInternalKeys(row),
      })),
      practices: source.practiceAttempts.map((row) =>
        withRef(row, "internal_lesson_id", lessons, "lessonRef"),
      ),
      progress: source.progressEvents.map((row) =>
        withRef(row, "internal_lesson_id", lessons, "lessonRef"),
      ),
    },
    evidence: {
      artifacts: source.evidenceArtifacts.map((row, index) => ({
        ref: `evidence-artifact-${index + 1}`,
        ...withoutInternalKeys(row),
      })),
      revisions: source.evidenceRevisions.map((row) =>
        withRef(row, "internal_artifact_id", artifacts, "artifactRef"),
      ),
      competencyLinks: source.evidenceLinks.map((row) =>
        withRef(row, "internal_artifact_id", artifacts, "artifactRef"),
      ),
    },
    measurement: {
      allowedProductEvents: source.productEvents.map(withoutInternalKeys),
    },
  };

  return normalize(exportDocument);
}

export function serializeCanonicalAlphaExport(exportDocument) {
  return `${JSON.stringify(normalize(exportDocument))}\n`;
}

export async function createAlphaOwnerExport(client, ownerId) {
  const source = await loadAlphaOwnerExportSource(client, ownerId);
  const document = createCanonicalAlphaExport(source);
  const bytes = serializeCanonicalAlphaExport(document);
  return {
    contractVersion: alphaExportContractVersion,
    document,
    bytes,
    sha256: createHash("sha256").update(bytes, "utf8").digest("hex"),
  };
}

export const alphaExportQueryPlan = Object.freeze(
  queryPlan.map(({ key, one, sql }) => Object.freeze({ key, one: Boolean(one), sql })),
);
