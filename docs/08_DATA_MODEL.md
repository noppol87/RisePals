# Initial Data Model

**Turn:** RP-TURN-001  
**Status:** Logical MVP model plus bounded RP-TURN-010 physical baseline pending review  
**Reviewed:** 2026-08-01

## Purpose

โมเดลนี้รองรับวงจร MVP:

> Assessment → Priority Gap → First Lesson → Practice → Visible Progress

และรักษาทางไปสู่ Prove → Opportunity โดยไม่ทำให้คะแนน diagnostic ที่ยังไม่ validate กลายเป็น automated hiring gate

เอกสารนี้กำหนด logical entities, ownership, versioning, privacy และ lifecycle ก่อนเลือก managed PostgreSQL หรือ auth vendor โดย RP-TURN-010 นำเฉพาะเก้าตารางฐานที่ได้รับอนุญาตไปสร้างเป็น Drizzle schema และ forward migration; entity อื่นในเอกสารยังเป็นแบบจำลองอนาคตเท่านั้น

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
| `preferred_locale` | text | Initial value `th`; BCP 47 |
| `timezone` | text | IANA timezone ID |
| `role_family` | controlled code nullable | Broad role taxonomy, not free-form employer data |
| `function` | controlled code nullable | Administration, finance, marketing, etc. |
| `experience_band` | controlled code nullable | Broad band; avoid exact employment history |
| `goals` | controlled code array | MVP preference inputs |
| `onboarding_completed_at` | timestamptz nullable | Flow state |
| `profile_schema_version` | integer | Supports future interpretation/migration |
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

## Learning content and practice

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

## Evidence and user-controlled sharing

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

### `product_event`

May be an external analytics contract rather than an application table. Allowed fields:

- allowlisted event name and schema version
- pseudonymous application user/event subject ID when consent permits
- session/correlation ID not usable as an auth credential
- coarse route/flow step, locale, device class and occurred time
- non-sensitive outcome code

Prohibited fields include raw answers, item text, scores, free-text goals/reflections, proof names/content, email, provider subject, employer name and signed URLs.

### `audit_event`

Staff/security audit records contain actor ID, action, target type/opaque ID, occurred time, result, reason code and correlation ID. They must not duplicate target content. Access is restricted and independently retained according to an approved policy.

## Authorization and database policy

### Implemented RP-TURN-010 baseline

The physical baseline contains exactly these nine tables: `user_accounts`, `external_identities`, `consent_records`, `framework_versions`, `competency_versions`, `scoring_model_versions`, `assessment_versions`, `assessment_item_versions` and `assessment_item_competencies`.

One forward migration enforces UUID identities; unique provider/subject mappings; unique framework, scoring-model and assessment business versions; restrictive foreign keys; versioned JSON object checks; UTC-capable `timestamptz`; null multiplier weights; and the exact sealed 8-core/+2-multiplier registry totaling 10,000 core basis points. Version rows are inserted as drafts, publish only after validation, retire only through a status-only transition and are immutable while published or retired. Owned definition children cannot move out of or into a sealed framework/assessment; trigger locks cover OLD and NEW parents in deterministic UUID order. Consent rows are append-only.

`user_accounts`, `external_identities` and `consent_records` have forced RLS. Both the table-owning migration role and normal application role resolve rows through a transaction-local `app.current_user_id`; the normal role owns no table and is `NOSUPERUSER`, `NOCREATEDB`, `NOCREATEROLE`, `NOINHERIT` and `NOBYPASSRLS`. The trusted Next.js server validates the UUID before setting it inside a transaction. Normal runtime reads only the application URL; only migration/test tooling receives both separately decoded role credentials. This context is not an authentication mechanism and must never be set from untrusted browser input.

The baseline intentionally excludes profiles, authentication/session state, assessment sessions, raw responses, scoring runs, persisted results, recommendations, lesson progress, XP, proof/evidence storage and production accounts. The disposable PostgreSQL harness uses only synthetic users and temporary credentials outside the repository.

- Browser code never receives a privileged database credential.
- Server Data Access Layer checks active account, required role, owner/relationship and requested fields.
- DTOs expose the minimum fields required by a page.
- PostgreSQL RLS is enabled on user-owned P2/P3 tables when provider context supports it; owner policies compare the trusted application user context to `user_id`.
- Service/maintenance roles are separate, short-lived where possible and audited. The normal application path does not use a table-owner or `BYPASSRLS` role.
- Staff support access is not implied by `admin`; define explicit purposes and audited break-glass behavior before pilot.
- Integration tests create two users and prove own behavior plus cross-user select/insert/update/delete, missing context and malformed context fail closed as applicable for every user-owned table.

## Key invariants and indexes

- Unique provider identity mapping and unique published business version keys
- Foreign keys prevent answers/scores/attempts from referencing mismatched framework/content versions
- Published versions reject content/provenance mutation, allow only status-only retirement and become fully immutable when retired; corrections create a new version
- Only submitted sessions can produce completed scoring runs
- `scoring_run.input_digest` plus model version makes a derivation reproducible
- At most three active priority recommendations per scoring run, with unique rank
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
- Re-scoring creates a new scoring run and marks the prior run superseded; it does not rewrite history.
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
