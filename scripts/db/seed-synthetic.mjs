import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

const digest = "a".repeat(64);
const definition = JSON.parse(
  await readFile(
    resolve("src/modules/assessment/persistence/synthetic-published-definition.json"),
    "utf8",
  ),
);
const canonicalCompetencies = [
  ["critical-thinking-fact-checking", "core", 2000, 1],
  ["systematic-thinking", "core", 1500, 2],
  ["growth-mindset", "core", 1500, 3],
  ["emotional-intelligence", "core", 1000, 4],
  ["resilience-adaptability", "core", 1000, 5],
  ["curiosity", "core", 1000, 6],
  ["ethical-judgement-governance", "core", 1000, 7],
  ["strategic-storytelling-framing", "core", 1000, 8],
  ["ownership-thinking", "multiplier", null, 1],
  ["sense-of-urgency", "multiplier", null, 2],
];

export async function seedSyntheticPublishedDefinition(client) {
  const frameworkResult = await client.query(
    `INSERT INTO framework_versions
      (framework_key, version, scoring_disclaimer_key, content_digest)
     VALUES ($1, $2, 'assessment.limitations.v1', $3)
     RETURNING id`,
    [definition.frameworkKey, definition.frameworkVersion, digest],
  );
  const frameworkId = frameworkResult.rows[0].id;
  const competencyIds = new Map();
  for (const [key, kind, weight, order] of canonicalCompetencies) {
    const competency = await client.query(
      `INSERT INTO competency_versions
        (framework_version_id, competency_key, kind, weight_basis_points, display_order,
         definition_i18n, behavior_anchors, content_digest)
       VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb, $8)
       RETURNING id`,
      [
        frameworkId,
        key,
        kind,
        weight,
        order,
        JSON.stringify({ schemaVersion: "1", th: `synthetic-${key}`, en: `synthetic-${key}` }),
        JSON.stringify({ schemaVersion: "1", anchors: [] }),
        digest,
      ],
    );
    competencyIds.set(key, competency.rows[0].id);
  }
  await client.query(
    `UPDATE framework_versions SET status = 'published', published_at = now() WHERE id = $1`,
    [frameworkId],
  );
  const scoringResult = await client.query(
    `INSERT INTO scoring_model_versions
      (framework_version_id, model_key, version, method, configuration, limitations_i18n,
       content_digest)
     VALUES ($1, $2, $3, 'deterministic_rubric', $4::jsonb, $5::jsonb, $6)
     RETURNING id`,
    [
      frameworkId,
      definition.scoringModelKey,
      definition.scoringModelVersion,
      JSON.stringify({ schemaVersion: "1", scale: [0, 1, 2] }),
      JSON.stringify({ schemaVersion: "1", th: "synthetic", en: "synthetic" }),
      digest,
    ],
  );
  const scoringId = scoringResult.rows[0].id;
  await client.query(
    `UPDATE scoring_model_versions SET status = 'published', published_at = now() WHERE id = $1`,
    [scoringId],
  );
  const assessmentResult = await client.query(
    `INSERT INTO assessment_versions
      (assessment_key, version, framework_version_id, scoring_model_version_id,
       estimated_minutes, content_digest)
     VALUES ($1, $2, $3, $4, 8, $5)
     RETURNING id`,
    [definition.assessmentKey, definition.assessmentVersion, frameworkId, scoringId, digest],
  );
  const assessmentId = assessmentResult.rows[0].id;
  for (const item of definition.items) {
    const itemResult = await client.query(
      `INSERT INTO assessment_item_versions
        (assessment_version_id, framework_version_id, item_key, item_type, prompt_i18n,
         response_schema, display_order, required, content_digest)
       VALUES ($1, $2, $3, 'scenario_choice', $4::jsonb, $5::jsonb, $6, true, $7)
       RETURNING id`,
      [
        assessmentId,
        frameworkId,
        item.key,
        JSON.stringify({ schemaVersion: "1", th: "synthetic", en: "synthetic" }),
        JSON.stringify({
          schemaVersion: "assessment-response-options-v1",
          type: "scenario-choice",
          optionIds: item.optionIds,
        }),
        item.displayOrder,
        digest,
      ],
    );
    await client.query(
      `INSERT INTO assessment_item_competencies
        (assessment_item_version_id, competency_version_id, framework_version_id,
         target_kind, rationale_key)
       VALUES ($1, $2, $3, $4, $5)`,
      [
        itemResult.rows[0].id,
        competencyIds.get(item.targetKey),
        frameworkId,
        item.targetKind,
        `synthetic.${item.key}`,
      ],
    );
  }
  await client.query(
    `UPDATE assessment_versions SET status = 'published', published_at = now() WHERE id = $1`,
    [assessmentId],
  );
}
