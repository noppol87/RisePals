# Initial Data Model

**Turn:** RP-TURN-001  
**Status:** Logical MVP model plus accepted RP-TURN-010/011 baseline and RP-TURN-012 synthetic-alpha raw assessment persistence boundary  
**Reviewed:** 2026-08-01

## Purpose

โมเดลนี้รองรับวงจร MVP:

> Assessment → Priority Gap → First Lesson → Practice → Visible Progress

และรักษาทางไปสู่ Prove → Opportunity โดยไม่ทำให้คะแนน diagnostic ที่ยังไม่ validate กลายเป็น automated hiring gate

เอกสารนี้กำหนด logical entities, ownership, versioning, privacy และ lifecycle โดย RP-TURN-010 นำเก้าตารางฐานที่ได้รับอนุญาตไปสร้างเป็น Drizzle schema/migration, RP-TURN-011 เพิ่ม `user_profiles` พร้อม Clerk Development mapping boundary และ RP-TURN-012 เพิ่มเฉพาะ `assessment_sessions`/`assessment_responses` สำหรับ synthetic alpha; entity อื่นในเอกสารยังเป็นแบบจำลองอนาคต และ managed PostgreSQL/production identity vendor ยังไม่ได้รับอนุมัติ

## Modeling principles

1. ใช้ internal UUID เป็น identifier; vendor identity ID เป็นเพียง mapping
2. Framework, assessment, question, scoring model, lesson, practice และ rubric ที่ publish แล้วเป็น immutable versions
3. แยก raw answers ออกจาก derived scores และแยก score explanation ออกจากทั้งสองส่วน
4. ทุก derived record ระบุ input version และ algorithm/model version เพื่อคำนวณซ้ำและอธิบายได้
5. Progress และ XP เป็น append-only ledger แล้วค่อยสร้าง snapshot; completion แยก viewing ออกจาก demonstrated practice
6. Proof เป็นของผู้ใช้และ private by default; การแชร์เป็น revocable grant
7. Stable relationships ใช้ typed columns/foreign keys; `jsonb` ใช้เฉพาะ payload ที่ validate ด้วย versioned schema
8. Analytics ไม่เก็บ raw answer, proof content, free-text reflection หรือ direct identity
9. ไม่มี field เช่น `employable`, `hire_recommendation` หรือ `job_eligibility` ใน MVP
10. Store timestamps as UTC `timestamptz`; locale ใช้ BCP 47; display timezone อยู่ใน profile

## Relationship map

```text
user_account 1---1 user_profile
     | 1
     +---* consent_record
     +---* assessment_session *---1 assessment_version *---1 framework_version
     |          | 1                         | 1
     |          +---* assessment_response   +---* assessment_item_version
     |          +---* scoring_run
     |                    +---* competency_score *---1 competency_version
     |                    +---* score_explanation
     |                    +---* priority_recommendation
     |
     +---* lesson_attempt *---1 lesson_version *---* competency_version
     |          +---* practice_attempt *---1 practice_version *---1 rubric_version
     |                         +---* rubric_result
     |
     +---* progress_event ---> progress_snapshot
     +---* xp_ledger_entry
     +---* evidence_artifact *---* evidence_competency
                                +---* evidence_share_grant
```

## Classification scheme

| Class | Meaning | Examples | Baseline control |
|---|---|---|---|
| P0 | Public | Published lesson title, public evidence claim | Integrity and publication review |
| P1 | Internal operational | Content draft status, aggregate system metrics | Staff role and audit trail |
| P2 | Personal | Email mapping, locale, broad job function | Owner/staff need-to-know access |
| P3 | Sensitive career/assessment | Raw answers, scores, reflections, proof, goals | Owner-scoped access, no analytics/logs, explicit retention/export/deletion |
| P4 | Secret/security | Session secret, database URL, provider keys | Secret store only; never database content or repository |

P3 is a Rise Pals product classification, not a claim about a specific legal category. Thailand and any other operating jurisdiction still require legal review before pilot collection.

## Identity, profile and consent

### `user_account`

Application identity and lifecycle; does not store passwords.

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | Internal owner key used throughout the product |
| `status` | enum | `active`, `suspended`, `deletion_pending`, `deleted` |
| `created_at`, `updated_at` | timestamptz | Audit timestamps |
| `last_seen_at` | timestamptz nullable | Coarse account activity; not a behavior stream |
| `deleted_at` | timestamptz nullable | Lifecycle marker |

Classification: P2. Owner: Identity and access.

### `external_identity`

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | Mapping record |
| `user_id` | FK → `user_account` | Cascades according to deletion workflow |
| `provider` | text | Adapter name, not domain logic |
| `provider_subject` | text | Unique with provider; encrypt/tokenize if vendor risk review requires |
| `email_normalized` | text nullable | Keep only if required for account UX; never public |
| `email_verified_at` | timestamptz nullable | Provider assertion timestamp |
| `created_at`, `last_authenticated_at` | timestamptz | Security/account operations |

Unique: (`provider`, `provider_subject`). Classification: P2. Credentials and password hashes remain with the chosen identity provider.

### `user_profile`

| Field | Type/constraint | Notes |
|---|---|---|
| `user_id` | UUID PK/FK | One profile per account |
| `preferred_locale` | controlled code | `th` or `en` |
| `timezone` | controlled code | Provisional `Asia/Bangkok`, `Europe/Berlin` or `UTC` |
| `role_family` | controlled code | Broad versioned role taxonomy, including `other` without free text |
| `function` | controlled code | Broad versioned function taxonomy, including `other` without free text |
| `experience_band` | controlled code | Broad versioned band; avoids exact employment history |
| `goals` | controlled code array | One to three unique `profile-v1` goal codes |
| `onboarding_completed_at` | timestamptz | Present because a row is created only after successful consented onboarding save |
| `profile_schema_version` | text | Exact `profile-v1` interpretation contract |
| `updated_at` | timestamptz | Audit timestamp |

Classification: P2; `goals` may be treated as P3 when it reveals career concerns. Do not collect employer name, exact title, salary or national identifier in the MVP.

### `consent_record`

Append-only consent receipt.

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | Receipt identifier |
| `user_id` | FK → `user_account` | Subject |
| `purpose_code` | controlled code | E.g. required service, product analytics, research contact |
| `notice_version` | text | Exact privacy/consent copy version |
| `decision` | enum | `granted`, `declined`, `withdrawn` |
| `occurred_at` | timestamptz | User action time |
| `locale` | text | Copy language |
| `source_surface` | text | Onboarding/settings/etc. |
| `proof_digest` | text | Integrity digest of rendered notice, not a copy of user data |

Classification: P2 with compliance sensitivity. A new record supersedes the prior decision; do not overwrite history.

## Framework and competency versions

### `framework_version`

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | Internal immutable ID |
| `framework_key` | text | Stable key for 8+2 framework |
| `version` | text | Semantic/business version such as `2.0` |
| `status` | enum | `draft`, `published`, `retired` |
| `scoring_disclaimer_key` | text | Localized diagnostic limitation copy |
| `published_at` | timestamptz nullable | Immutable after publication |
| `content_digest` | text | Detects unintended changes |

Unique: (`framework_key`, `version`). Classification: P0 when published, P1 when draft.

### `competency_version`

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | Versioned competency |
| `framework_version_id` | FK → `framework_version` | Parent framework |
| `competency_key` | text | Stable key, e.g. `critical_thinking` |
| `kind` | enum | `core` or `multiplier` |
| `weight_basis_points` | integer nullable | Core weight; null for behavioral multipliers |
| `display_order` | integer | Presentation only |
| `definition_i18n` | validated jsonb | Localized name/description; schema version required |
| `behavior_anchors` | validated jsonb | Aware → Leading anchors |

Unique: (`framework_version_id`, `competency_key`). Check: core weights total 10,000 basis points; multiplier weights remain null.

## Assessment definition and raw answers

### `assessment_version`

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | Immutable published version |
| `assessment_key`, `version` | text | Stable key plus version |
| `framework_version_id` | FK | Exact 8+2 interpretation |
| `status` | enum | `draft`, `published`, `retired` |
| `scoring_model_version_id` | FK | Model used by default |
| `estimated_minutes` | integer | Transparent UX |
| `published_at`, `content_digest` | timestamp/text | Provenance |

### `assessment_item_version`

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | Immutable item version |
| `assessment_version_id` | FK | Owning assessment version |
| `item_key` | text | Stable logical question key |
| `item_type` | enum | `scenario_choice`, `self_reflection`, later approved types |
| `prompt_i18n` | validated jsonb | Localized prompt and option labels |
| `response_schema` | validated jsonb | Allowed shape/limits |
| `display_order` | integer | Sequence |
| `required` | boolean | Validation |

### `assessment_item_competency`

Many-to-many mapping from item version to competency version with direction/rationale and optional scoring coefficient. This mapping is content/scoring metadata, not user data.

### `assessment_session`

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | Attempt identifier |
| `user_id` | FK → `user_account` | Owner |
| `assessment_version_id` | FK | Exact published definition |
| `status` | enum | `in_progress`, `submitted`, `scored`, `abandoned`, `voided` |
| `started_at`, `submitted_at` | timestamptz | Flow state |
| `last_item_key` | text nullable | Resume state without duplicating responses |
| `context_snapshot` | validated jsonb | Only broad approved role/function/band needed for interpretation |
| `consent_record_id` | FK nullable | Link when a specific purpose requires consent |

Classification: P3. Do not allow another user to enumerate IDs or infer completion state.

### `assessment_response`

This is the raw-answer source of truth.

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | Response identifier |
| `session_id` | FK → `assessment_session` | Owner inherited through session |
| `item_version_id` | FK | Exact question answered |
| `response_payload` | validated jsonb | Raw selected option/value; strict item schema |
| `response_schema_version` | integer | Decoder version |
| `answered_at` | timestamptz | User action time |
| `revision` | integer | Supports explicit correction without losing provenance |
| `supersedes_response_id` | FK nullable | Previous answer when corrected |

Unique active response per (`session_id`, `item_version_id`). Classification: P3. Never copy this payload into analytics, logs or score rows.

## Derived scoring and recommendations

### `scoring_model_version`

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | Algorithm/configuration version |
| `model_key`, `version` | text | Stable identity |
| `framework_version_id` | FK | Valid framework |
| `method` | enum | Deterministic rubric initially; future methods need approval |
| `configuration` | validated jsonb | Thresholds, coefficients and confidence rules |
| `limitations_i18n` | validated jsonb | What the score does and does not prove |
| `status`, `published_at`, `digest` | fields | Immutable publication contract |

### `scoring_run`

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | One reproducible derivation |
| `assessment_session_id` | FK | Input session |
| `scoring_model_version_id` | FK | Algorithm/configuration used |
| `input_digest` | text | Digest of active raw response IDs/revisions |
| `status` | enum | `pending`, `completed`, `failed`, `superseded` |
| `computed_at` | timestamptz | Provenance |
| `failure_code` | text nullable | No raw payload or stack trace |

### `competency_score`

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | Derived value |
| `scoring_run_id` | FK | Provenance |
| `competency_version_id` | FK | Exact competency |
| `score_basis_points` | integer nullable | Normalized display input, not scientific precision |
| `proficiency_stage` | enum nullable | Aware → Leading working model |
| `confidence_band` | enum | `low`, `medium`, `higher`; labels require validation |
| `evidence_count` | integer | Inputs contributing to this result |

Classification: P3. Avoid a single overall score in the MVP unless later research approves it with an explanation.

### `score_explanation`

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | Explanation record |
| `scoring_run_id` | FK | Result explained |
| `competency_version_id` | FK nullable | Null only for run-level limitations |
| `explanation_code` | controlled code | Stable reason category |
| `message_params` | validated jsonb | Non-sensitive values for localized copy |
| `supporting_item_keys` | text array | Trace to question keys, not copied answers |
| `limitations_key` | text | Localized limitation copy |

This entity makes explanation independently testable and translatable. It must never contain a fabricated causal claim.

### `priority_recommendation`

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | Recommendation snapshot |
| `scoring_run_id` | FK | Derived result source |
| `competency_version_id` | FK | Recommended gap |
| `rank` | integer | MVP allows 1–3 |
| `reason_code`, `reason_params` | controlled/jsonb | Explainable decision |
| `recommended_lesson_version_id` | FK nullable | Exact next action when published |
| `created_at` | timestamptz | Snapshot time |

This is guidance, not eligibility. A newer scoring run supersedes recommendations without mutating history.

## RP-TURN-006 provisional local assessment contract

RP-TURN-006 implements a repository-only precursor to the logical entities above. It creates no database row, session, user, migration or persistence adapter. All definitions and fixtures are synthetic, immutable-by-convention TypeScript values under `src/modules/assessment/`.

### Version identities and separation

| Contract | Stable ID | Purpose |
|---|---|---|
| Framework version | `framework-rise-pals-8-plus-2-v2` | Exact eight canonical core weights plus two unweighted multipliers |
| Assessment version | `assessment-workplace-scenarios-fixture-v1` | Six reviewed bilingual scenario-choice items |
| Scoring version | `scoring-integer-rubric-fixture-v1` | Pure deterministic integer-rubric derivation |

The implementation keeps five source boundaries separate:

1. framework, assessment, item and option definitions
2. synthetic raw-response fixtures containing only item/option IDs
3. expected and calculated scoring outputs
4. expected and calculated explanation/limitation records
5. localized Thai/English explanation and limitation copy

The two valid raw-response fixtures use synthetic IDs only. They contain no name, email, employer, profile, free text, career history or other personal field.

### Authorized partial slice

| Framework target | Kind | Item count | Available fixture points |
|---|---|---:|---:|
| Critical Thinking & Fact-Checking | Core | 2 | 4 |
| Systematic Thinking | Core | 2 | 4 |
| Ownership Thinking | Multiplier observation | 1 | 2 |
| Sense of Urgency | Multiplier observation | 1 | 2 |

The other six core competencies are emitted explicitly as unassessed. Their canonical weights remain present in framework metadata, but weights are not applied to create a partial aggregate.

### Deterministic formula and output boundary

Each option carries an integer rubric contribution on the reviewed `0..2` scale. For each assessed target independently:

```text
earned points = sum(selected option rubric points for that target)
available points = sum(item available points for that target)
evidence count = number of answered items supporting that target
```

The executable scorer returns earned/available points, evidence count and stable supporting item keys. It does not mutate inputs and output order follows canonical framework order rather than response order.

Core signals and multiplier observations are different output arrays. Ownership and urgency points are retained only for deterministic fixture testing; they never multiply, alter or aggregate into core signals and expose no multiplicative factor.

The scorer emits no overall score, confidence claim, proficiency stage, priority gap, lesson recommendation or employment/hiring field. Output is marked `provisional: true` and `fixtureOnly: true`.

### Explanation and validation boundary

Calculated score records contain no explanation copy. Separate explanation records contain stable codes, target identity, supporting item keys and limitation codes; Thai/English copy resolves separately.

Run-level limitations state that the slice is not a validated or calibrated assessment and cannot predict job loss, job performance, employability or hiring eligibility. Each multiplier record also states that one scenario cannot establish a behavioral pattern.

Before scoring, validation rejects incompatible assessment/framework/scoring versions, missing required responses, duplicate responses, unknown item/option IDs, non-canonical framework weights, multiplier weights, malformed rubric scales, non-integer/out-of-range contributions and the wrong item distribution. This local contract is review material for later assessment methodology work, not evidence of scientific validity.

## RP-TURN-007 session-only player boundary

RP-TURN-007 adds a browser interaction prototype, not an implementation of the durable `assessment_session` or `assessment_response` entities above. It creates no database row, API request, server action, cookie, account, consent receipt, analytics event or production persistence.

The presentation adapter validates the accepted domain definition on the server and passes the Client Component only the assessment identity/version plus each item's key, display order, localized prompt and option ID/label. Rubric points, target IDs/kinds, framework weights, scoring configuration, explanations and raw/expected fixture outputs do not cross this client-safe view boundary.

For same-tab refresh recovery, the client may write one JSON record under `rise-pals:assessment-player:v1` in `sessionStorage` with exactly:

| Field | Allowed value |
|---|---|
| `schemaVersion` | Integer `1` |
| `assessmentVersionId` | Exact accepted assessment version ID |
| `phase` | `intro`, `question` or `complete` |
| `currentItemKey` | Current item key or `null` |
| `selections` | Array of exact `{ itemKey, optionId }` pairs |

Selected item/option IDs are classified P3 sensitive assessment data even though storage is local and temporary. The payload therefore excludes localized copy, rubric points, targets, weights, scores, results, timestamps, profile/identity data and free text, and it must never appear in URLs, cookies, logs, console output, analytics or network requests.

Pure TypeScript validation requires exact object keys, compatible schema/assessment versions, unique known item keys, option IDs valid for their item, consistent prior-answer/current-step state and all six answers before `complete`. Malformed, unknown, incomplete or incompatible records are rejected and removed. Unavailable or throwing storage degrades to non-resumable play without crashing. The explicit clear/restart action removes the record.

This storage choice is prototype-only and non-production: it is scoped to the current browser tab/session, is not guaranteed durable and does not provide cross-device resume. Any durable assessment response design requires a separately reviewed privacy, consent, authentication, retention, export/deletion and server-persistence turn.

## RP-TURN-012 persisted synthetic-attempt boundary

The separately protected `/[locale]/assessment/attempt` path implements the authorized durable slice without importing the RP-TURN-007 browser record. PostgreSQL is authoritative only inside this explicit signed-in flow. Selected item/option IDs remain P3 sensitive assessment data even though every scenario is synthetic.

### `assessment_sessions` implemented columns and lifecycle

| Field | Implemented constraint |
|---|---|
| `id` | Internal UUID primary key; never placed in a browser DTO or URL |
| `user_id` | Internal `user_accounts.id`; forced-RLS owner and immutable |
| `assessment_version_id` | Exact published immutable version; immutable composite anchor for items/responses |
| `consent_record_id` | Exact granted `service-profile-learning-state` / `alpha-privacy-v1` receipt used at start; immutable and server-selected |
| `status` | Only `in_progress` or `submitted`; only forward transition is accepted |
| `last_item_version_id` | Nullable resume marker with composite FK to the same assessment version |
| `started_at`, `updated_at`, `submitted_at` | Database-owned `timestamptz`; submitted timestamp exists only after complete atomic submission |

A partial unique index permits at most one active owner/version session, while the alpha insert guard also refuses a replacement after submission because re-assessment is out of scope. Concurrent starts converge through the DAL advisory lock and database uniqueness. Submitted rows cannot reopen, update or delete. No role/function/experience snapshot is stored because it is unnecessary for this slice.

### `assessment_responses` implemented payload and provenance

| Field | Implemented constraint |
|---|---|
| `id` | Internal UUID primary key; server/database only |
| `session_id`, `assessment_version_id`, `assessment_item_version_id` | Composite FKs require one exact session/assessment/item lineage |
| `response_payload` | Exact JSON object `{ "schemaVersion": "assessment-response-v1", "selectedOptionId": <accepted ID> }` only |
| `revision` | Positive, monotonic per session/item and unique |
| `supersedes_response_id` | Explicit same-session prior revision; unique when present |
| `client_mutation_id` | UUID unique per session; identical retry resolves to the stored revision |
| `is_active` | Exactly one active row for every answered session/item, enforced by partial uniqueness plus a deferred constraint trigger |
| `created_at` | Database-owned `timestamptz` |

The item response schema contains only the canonical option-ID allowlist for its published version. Database triggers reject unknown/mismatched items or options, extra/malformed payload fields, skipped/branched revisions, incomplete submission and all post-submit response insertion/update/deletion. The application may insert and deactivate the prior active row within one transaction but cannot update payload columns or delete history. Stale expected revisions return a client-safe conflict rather than overwrite.

The client may receive localized item presentation, item/option IDs, its current selections, revision numbers and non-sensitive status only. It never receives owner/session/row UUIDs, provider subject, consent history, localized-copy persistence, rubric points, target mappings, framework weights, score/result/recommendation fields or database errors. No answer is stored in local/session storage, cookies, query strings, fragments, analytics, console output or logs by this route.

## RP-TURN-013 persisted synthetic-result boundary

One fourth migration adds exactly five derived-data tables and leaves accepted session/response/version rows unchanged.

| Table | Persisted contract |
|---|---|
| `scoring_runs` | Owner/session and exact assessment/framework/scoring references; monotonic run number; normal/rescore kind; prior-run provenance link; mutation UUID; canonical input/output SHA-256 digests; exact result-policy key/version/digest; database timestamp |
| `competency_scores` | Exactly the assessed core competency, earned/available integer points, evidence count and deterministic floor-normalized basis points; never multiplier rows |
| `multiplier_observations` | Separate Ownership Thinking/Sense of Urgency integer rubric evidence, one-scenario count and controlled limitation; never core scores or priority modifiers |
| `score_explanations` | Controlled target/code, exact target-validated supporting item keys, fixed schema-version parameters and limitation codes; no localized copy, answer payload, selected option or free text |
| `priority_recommendations` | Zero or one rank-1 assessed-core recommendation with controlled unique-lowest reason, exact supporting items and only the prototype-lesson/practice-unavailable bounded action |

The result policy is immutable `persisted-synthetic-priority-v1@1.0.0`, with pinned canonical JSON digest `10f2ab076828d50b228ff53d57332527dfe9d1b2769c4b57bd0476dd3c263157`. Canonical input includes exact assessment/framework/scoring content identities and digests, policy identity/version/digest, and active response item/revision/option evidence in canonical item order. Owner/session UUID, time and locale are excluded. Canonical output excludes row UUIDs, time and localized copy. Identical semantic input/model/policy reproduces identical child semantics and output digest.

The accepted partial slice creates exactly two core score rows and two separate multiplier rows. The other six framework core competencies are derived as unassessed and have no score row. Priority candidates are only the two complete core rows. Exact integer cross multiplication selects one unique lowest ratio or no recommendation on a tie; weights, profile fields, multipliers and framework order cannot break the tie. A Critical Thinking priority may reference only the existing prototype lesson; Systematic Thinking is persisted as `practice-unavailable`.

All five tables use ENABLE/FORCE RLS and owner/session composite foreign keys. The application role receives SELECT/INSERT only. Deferred constraints require an atomically complete two-core/two-multiplier/six-explanation/zero-or-one-priority run and reproduce submitted rubric evidence before commit. UPDATE/DELETE triggers keep every run and child immutable. A new rescore row carries `supersedes_scoring_run_id`; the prior row is never rewritten.

## Learning content and practice

RP-TURN-014 selects the tracked deterministic build-time registry as the pilot publication mechanism. `source-verification-practice@1.0.0` is identified by its Git source paths and aggregate SHA-256 and is available only for synthetic alpha. No `lesson_version`, `practice_version`, rubric, source-claim or publication table is added to the accepted four-migration/17-table database. The relational structures below remain the future persisted-learning model for a separately authorized turn; a database mirror/import job, CMS and production content operations are still undecided.

Operational content status and validation status remain separate: the pilot version is `published` through the repository registry while remaining `prototype-unvalidated`. This does not create a learner attempt, progress, XP, proof or efficacy record.

### `lesson_version`

Published mirror of validated Git content.

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | Immutable lesson version |
| `lesson_key`, `version`, `locale` | text | Logical identity and translation |
| `framework_version_id` | FK | Framework contract |
| `status` | enum | `draft`, `published`, `retired` |
| `source_path`, `content_digest` | text | Git provenance |
| `target_stage`, `roi_pillars` | controlled values | Lesson contract |
| `published_at` | timestamptz nullable | Release time |

`lesson_competency` maps lesson versions to competency versions and identifies primary/secondary targets.

### `practice_version`

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | Immutable practice contract |
| `lesson_version_id` | FK | Owning lesson |
| `practice_key`, `version` | text | Stable identity |
| `activity_type` | enum | Scenario, decision exercise, reflection or approved artifact task |
| `activity_schema` | validated jsonb | Render/input rules and limits |
| `rubric_version_id` | FK | Exact feedback rubric |
| `proof_requirement` | validated jsonb | Optional artifact/evidence contract |

### `rubric_version`

Stores immutable criteria, levels, feedback keys, reviewer method and digest. Automated rubric evaluation in the MVP must be deterministic or explicitly labeled; any future AI evaluation needs a separate approved data-processing design and human challenge path.

### `source_claim_version`

Public urgency/evidence claims follow `docs/05_BRAND_VISUAL_CONTENT.md`:

- claim text and locale
- original source direct URL and publisher
- publication date, geography, sample/context
- what the evidence does and does not prove
- last verified and review/expiry date
- content owner, reviewer and publication status

Published pages reference a claim version rather than copying an untraceable statistic.

## Attempts, feedback and meaningful progress

### `lesson_attempt`

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | User attempt |
| `user_id` | FK | Owner |
| `lesson_version_id` | FK | Exact lesson seen |
| `status` | enum | `started`, `content_viewed`, `practice_submitted`, `demonstrated`, `abandoned` |
| `started_at`, `last_active_at`, `completed_at` | timestamptz | Resume/history |
| `resume_block_key` | text nullable | Continue-learning state |

`content_viewed` never implies demonstrated skill.

### `practice_attempt`

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | Submission attempt |
| `user_id`, `lesson_attempt_id` | FK | Explicit owner plus parent |
| `practice_version_id` | FK | Activity and rubric contract |
| `submission_payload` | validated jsonb | P3; size-limited; artifact files remain in object storage |
| `status` | enum | `draft`, `submitted`, `evaluated`, `withdrawn` |
| `submitted_at` | timestamptz nullable | Immutable submission point |
| `supersedes_attempt_id` | FK nullable | Revision trail |

### `rubric_result`

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | Feedback result |
| `practice_attempt_id` | FK | Submission evaluated |
| `rubric_version_id` | FK | Exact rubric |
| `evaluation_method` | enum | `deterministic`, `self`, `human`; AI is deferred |
| `criterion_results` | validated jsonb | Criterion code, level and feedback keys |
| `demonstrated` | boolean | Whether proof threshold was met |
| `evaluated_at`, `reviewer_user_id` | fields | Human reviewer only when applicable |

### `progress_event` and `progress_snapshot`

`progress_event` is an append-only domain ledger with `event_type`, `user_id`, source entity ID, competency version, occurred time and idempotency key. Allowed types are meaningful actions such as `assessment_submitted`, `practice_evaluated`, `evidence_created`; page views are analytics, not progress.

`progress_snapshot` is a rebuildable per-user/per-competency read model containing stage, meaningful activity counts and last demonstrated time. It never becomes the source of truth.

### `xp_ledger_entry`

Append-only entries include `user_id`, positive or reversing points, reason code, source entity type/ID, ruleset version and idempotency key. Unique (`ruleset_version`, `reason_code`, `source_entity_id`) prevents duplicate awards. XP cannot be awarded for elapsed screen time alone.

### Implemented RP-TURN-015 bounded learning model

The implemented synthetic-alpha subset intentionally uses exactly three pluralized tables rather than the broader future model above:

- `lesson_attempts` anchors one owner/current-consent attempt to exact `source-verification-practice@1.0.0`, its lesson digest, practice, rubric and evaluation contract. Status is only `in_progress` or `demonstrated`; database-owned timestamps and triggers permit only the forward transition and prohibit reopen/delete.
- `practice_attempts` stores immutable monotonic `draft` or `evaluated` response snapshots. Payloads contain only a schema version and ordered allowlisted criterion/option pairs. Each row also records normalized mutation intent, locale and expected revision so UUID replay is accepted only when the full request provenance and canonical selections match. Evaluated rows carry deterministic criterion results and the demonstrated flag; PostgreSQL independently re-evaluates their exact shape and canonical mapping. A non-demonstrated evaluated revision permits only a retry successor. The retry must be a draft, copy the exact eligible predecessor payload, supersede that predecessor and use its revision as the expected revision; only after this retry draft exists may save or evaluate create another revision. Both DAL and PostgreSQL enforce the transition, while exact replay remains available after demonstration.
- `learning_progress_events` is an append-only meaningful-event ledger restricted to `lesson_started`, `practice_evaluated` and `practice_demonstrated`. It records no page view, refresh, arbitrary click, email, provider identity, free text or analytics payload.

The fifth migration brings the fresh schema to exactly twenty tables. All three new tables enable and force RLS, use composite owner foreign keys, require the current exact service-data grant and deny application DELETE. Practice/event UPDATE is absent; lesson UPDATE is limited to exact lifecycle timestamp/status columns and protected by triggers. There is no `progress_snapshot`, `rubric_result`, `xp_ledger_entry` or proof table in this turn.

### Implemented RP-TURN-016 bounded private evidence model

The sixth migration adds exactly three pluralized tables for one controlled synthetic artifact:

- `evidence_artifacts` anchors one owner and exact current consent receipt to the exact demonstrated owner lesson/practice, artifact contract/proof/lesson/digest/source-pack identity and `prototype-unvalidated` classification. Status is only `draft`, `ready` or `withdrawn`; database timestamps and mutation provenance enforce only `draft → ready`, `draft → withdrawn` and `ready → withdrawn`.
- `evidence_artifact_revisions` stores immutable monotonic snapshots of the exact six-key payload. Values are limited to the fixed synthetic claim, ordered unique `pilot-table`/`scope-note`/`risk-log` references and accepted fit/correction/safe-action option IDs. Mutation UUID, intent, locale and expected revision make exact replay distinguishable from conflicting reuse; skipped, branched, cross-owner, malformed and post-ready revisions fail.
- `evidence_competency_links` provides one immutable link to the exact published `rise-pals-8-plus-2@2.0` Critical Thinking & Fact-Checking core. Relationship `synthetic-practice-evidence` is traceability only and has no score, level, rank, proficiency, employment or eligibility field.

The sixth migration brings the fresh schema to exactly twenty-three tables. All three new tables enable and force RLS, require current consent and deny application DELETE. Revision/link UPDATE is absent; artifact UPDATE is limited to guarded lifecycle provenance columns. The application role owns no table and has no `BYPASSRLS`. No free text, file/object, URL, upload, share grant, export, XP, score or recommendation is stored.

### Implemented RP-TURN-017 consent-aware measurement model

The seventh migration adds exactly three pluralized tables for the optional first-party synthetic-alpha foundation:

- `measurement_subjects` maps one owner and exact current granted `measurement-monitoring` receipt to one pseudonymous `measurement-subject-v1` identity. Withdrawal makes that subject ineligible for capture; a later exact grant produces another subject.
- `product_events` stores only `product-measurement-v1`, one of `activation_completed` or `meaningful_return_completed`, an allowlisted surface/operation pair, context-bound action SHA-256 and UTC time. The first successful explicit persisted action is activation; meaningful return requires a distinct successful action on a later UTC date. The subject/action digest pair prevents exact replay duplication.
- `error_occurrences` stores only `redacted-error-occurrence-v1`, opaque correlation UUID, controlled surface/operation/locale/category/severity/retryability, UTC time and optional context-bound mutation digest. It has no message, stack, URL, identity, content, arbitrary JSON or secret field.

The seventh migration brings the fresh schema to exactly twenty-six tables. All three new tables enable and force RLS, require the exact current measurement grant and grant the application only SELECT/INSERT. Direct SQL checks enforce every allowlist; application UPDATE/DELETE is absent. Capture is a non-authoritative side effect and never changes the underlying domain transaction. Retention/export/erasure operations, external telemetry and production observability remain open.

## Future evidence and user-controlled sharing (not implemented)

### `evidence_artifact`

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | Artifact record |
| `user_id` | FK | Owner |
| `source_practice_attempt_id` | FK nullable | Provenance |
| `title`, `description` | text | P3; user-provided and size-limited |
| `artifact_type` | enum | Approved MVP proof type |
| `storage_key` | text nullable | Opaque private-object key; never public URL |
| `content_type`, `size_bytes`, `checksum` | fields | File controls |
| `status` | enum | `draft`, `ready`, `quarantined`, `withdrawn`, `deleted` |
| `created_at`, `updated_at` | timestamptz | Lifecycle |

`evidence_competency` maps an artifact to competency versions, with claim level and provenance. A user may correct or withdraw the claim.

### `evidence_share_grant`

| Field | Type/constraint | Notes |
|---|---|---|
| `id` | UUID PK | Revocable grant |
| `artifact_id`, `owner_user_id` | FK | Ownership |
| `grantee_type` | enum | MVP may support `link`; employer accounts are deferred |
| `token_digest` | text nullable | Store digest, never raw bearer token |
| `scope` | controlled code array | Metadata only, preview or download |
| `expires_at`, `revoked_at` | timestamptz nullable | Time and owner control |
| `created_at` | timestamptz | Audit |

Default is no grant. Shared views do not reveal assessment scores unless a future, explicit user choice and fairness design authorizes it.

## Analytics and audit separation

### Implemented `product_events` boundary

The local synthetic-alpha implementation uses the exact allowlisted fields documented above. A later external adapter or provider is not selected and would require a separate decision. The broader candidate contract remains limited to:

- allowlisted event name and schema version
- pseudonymous application user/event subject ID when consent permits
- session/correlation ID not usable as an auth credential
- coarse route/flow step, locale, device class and occurred time
- non-sensitive outcome code

Prohibited fields include raw answers, item text, scores, free-text goals/reflections, proof names/content, email, provider subject, employer name and signed URLs.

### `audit_event`

Staff/security audit records contain actor ID, action, target type/opaque ID, occurred time, result, reason code and correlation ID. They must not duplicate target content. Access is restricted and independently retained according to an approved policy.

## Authorization and database policy

### Implemented RP-TURN-010 baseline and RP-TURN-011/012/013 extensions

The accepted RP-TURN-010 baseline contains nine tables. RP-TURN-011 adds `user_profiles`; RP-TURN-012 adds only `assessment_sessions` and `assessment_responses`; RP-TURN-013 adds five derived tables; RP-TURN-015 adds exactly the three learning tables above; RP-TURN-016 adds the three controlled evidence tables; RP-TURN-017 adds the three consent-aware measurement/error tables. The fresh seven-migration schema therefore contains exactly twenty-six tables.

One forward migration enforces UUID identities; unique provider/subject mappings; unique framework, scoring-model and assessment business versions; restrictive foreign keys; versioned JSON object checks; UTC-capable `timestamptz`; null multiplier weights; and the exact sealed 8-core/+2-multiplier registry totaling 10,000 core basis points. Version rows are inserted as drafts, publish only after validation, retire only through a status-only transition and are immutable while published or retired. Owned definition children cannot move out of or into a sealed framework/assessment; trigger locks cover OLD and NEW parents in deterministic UUID order. Consent rows are append-only.

`user_accounts`, `external_identities`, `consent_records` and `user_profiles` have forced RLS. Both the table-owning migration role and normal application role resolve owned rows through a transaction-local `app.current_user_id`; without valid context both see zero provider-identity rows. The normal role owns no table and is `NOSUPERUSER`, `NOCREATEDB`, `NOCREATEROLE`, `NOINHERIT` and `NOBYPASSRLS`. A hardened `SECURITY DEFINER` function exposes only Clerk resolve-or-provision to the application role: it fixes `search_path`, rejects other provider/subject shapes, serializes on the mapping key, relies on provider/subject uniqueness, provisions account and mapping atomically, revokes `PUBLIC` and grants only runtime execution. The function owner is a credentialless `NOLOGIN`/`NOBYPASSRLS` resolver role with only required table operations and narrow forced-RLS policies; neither application nor migration owner can assume it after the privileged bootstrap revokes temporary migration membership. The server may call the function only after a validated Clerk session and then establishes the internal UUID context. Browser input never controls the provider subject or context.

The RP-TURN-011 extension persists a controlled profile and append-only service-data consent receipts. RP-TURN-012 adds owner-scoped synthetic assessment sessions and raw selected-option revision history. RP-TURN-013 adds only reproducible synthetic derived runs/signals/explanations/bounded priority. RP-TURN-015 adds owner-scoped synthetic lesson/practice/progress history without XP. RP-TURN-016 adds only one private controlled synthetic note and its traceability link; it is not a general proof/file/share model. RP-TURN-017 adds only optional pseudonymous first-party product events and redacted error occurrences under a separate consent receipt; it is not marketing analytics or external monitoring. Clerk retains authentication/session state; the database stores a provider mapping without copied email, token or credential. Real identities, production accounts, XP, uploads, object storage, sharing and externally verifiable proof remain excluded. The disposable PostgreSQL harness uses only synthetic users, repository-local synthetic published definitions and temporary credentials outside the repository.

- Browser code never receives a privileged database credential.
- Server Data Access Layer checks active account, required role, owner/relationship and requested fields.
- DTOs expose the minimum fields required by a page.
- PostgreSQL RLS is enabled on user-owned P2/P3 tables when provider context supports it; owner policies compare the trusted application user context to `user_id`.
- Service/maintenance roles are separate, short-lived where possible and audited. The normal application path does not use a table-owner or `BYPASSRLS` role.
- Staff support access is not implied by `admin`; define explicit purposes and audited break-glass behavior before pilot.
- Integration tests create synthetic users and prove own behavior plus cross-user, missing-context and malformed-context isolation across all seventeen forced-RLS tables. They also prove the application role owns no table or UPDATE/DELETE privilege for immutable history, provider mappings cannot be enumerated without context, the credentialless resolver cannot be assumed, concurrent starts/generation converge, response and artifact mutation replay is idempotent, concurrent saves conflict safely, rescores preserve prior runs and malformed provider/assessment/result/evidence inputs fail closed.

## Key invariants and indexes

- Unique provider identity mapping and unique published business version keys
- One bounded alpha assessment session per owner/version, one active response revision per answered item and unique client mutation/revision/supersession provenance; persisted lesson mutations additionally require exact intent/locale/expected-revision and selection replay provenance
- Foreign keys prevent answers/scores/attempts from referencing mismatched framework/content versions
- Published versions reject content/provenance mutation, allow only status-only retirement and become fully immutable when retired; corrections create a new version
- Only submitted sessions can produce completed scoring runs
- `scoring_run.input_digest` plus model version makes a derivation reproducible
- RP-TURN-013 permits at most one rank-1 provisional priority recommendation per scoring run; an exact tie persists none
- Proof storage key is unique and owner-scoped
- Share token digest is unique; expired/revoked grants fail closed
- XP source/ruleset idempotency prevents refresh or retry from duplicating points
- Index owner/time access patterns: (`user_id`, `created_at desc`) on sessions, attempts, events and evidence
- Index publication lookup: (`status`, `locale`, `published_at`) on content versions
- Avoid indexing free text or response payload until a measured query requires it

## Export, correction and deletion

### User export

Provide a machine-readable archive containing:

- account/profile and consent receipts
- assessment sessions and raw responses
- scoring runs, competency results, explanations and recommendations
- lesson/practice attempts, rubric feedback, progress and XP ledger
- evidence metadata, original user-owned files and active share grants
- framework/content/rubric version identifiers needed to interpret records

Do not export internal security logs, other users' data, secret token digests or licensed content beyond the user's applicable rights. Include a human-readable manifest that explains diagnostic limitations.

### Correction

- Profile values may update with audit timestamps.
- Submitted raw answers are corrected by a superseding response or new assessment session, not silent mutation.
- Re-scoring creates a new scoring run whose `supersedes_scoring_run_id` points to the prior run; it never marks or rewrites the prior run.
- Users can challenge/correct evidence claims and withdraw artifacts or sharing.

### Deletion workflow

1. Re-authenticate and record the request without copying sensitive payloads.
2. Move account to `deletion_pending`, revoke sessions and active share grants.
3. Delete private objects, raw responses, scores, attempts, proof and profile/identity mappings in an idempotent job.
4. Remove or irreversibly de-identify analytics records where the selected system supports it.
5. Retain only records required by an approved legal/security policy, minimized and access-restricted; consent withdrawal must not be confused with full account deletion.
6. Record completion using an opaque deletion request ID, not the deleted payload.
7. Explain backup expiry separately. Vendor selection must document when deleted data ages out of backups and restoration procedures must reapply deletion tombstones.

Exact retention windows are intentionally open pending legal/privacy review, pilot research needs and vendor capabilities. No indefinite retention is the default.

## Content and framework retirement

Retiring a framework, question, lesson or rubric prevents new attempts but preserves immutable versions referenced by user history. Deletion of published definition rows is forbidden while references exist. Display code must show the historical definition and current limitation notice without silently translating an old score through a new model.

## Avoiding hiring lock-in

The future Opportunity module must not query `competency_score` as a pass/fail gate. Its input contract, when approved, should accept:

- user-selected, revocable evidence claims
- demonstrated practice with versioned rubric provenance
- preferences and availability explicitly provided for matching
- explainable rule output and human review state

Self-report and diagnostic scores may help a user choose learning, but are excluded from employer eligibility and automated rejection. Any future use requires validation, fairness analysis, appeal/correction, purpose-specific consent and a separate approved turn.

## Open data decisions

- Managed PostgreSQL, auth and object-storage vendors
- Exact retention periods and backup deletion behavior
- Whether a P3 field requires application-layer encryption in addition to managed encryption at rest
- Pilot role/function taxonomy and whether any free-text goal is necessary
- Content publication implementation: build-time registry versus database import job
- Approved proof file types, size limits, scanning and reviewer workflow
- Research/assessment calibration dataset and irreversible de-identification threshold

These are explicit decisions, not implementation placeholders; the MVP must not collect the affected data until the relevant decision is approved.
