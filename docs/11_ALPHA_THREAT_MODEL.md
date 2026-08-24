# Rise Pals Synthetic-Alpha Threat Model

Status: RP-TURN-018 implementation evidence pending Project Codex review.

This model applies only to repository-controlled synthetic identities, explicitly Clerk-disabled browser automation and disposable PostgreSQL. It is not a legal review, a production security approval or authorization to collect real user or career data.

## Assets and trust boundaries

| Boundary | Trusted input and authority | Sensitive assets | Explicitly excluded authority |
|---|---|---|---|
| Browser | Fixed locale/routes, controlled option identifiers and server-rendered client DTOs | Temporary P3 choices and rendered owner state | Database access, provider secrets, scoring/content internals, export or erasure execution |
| Next.js server | Validated Server Actions, authenticated internal owner ID and current consent | Owner-scoped P2/P3 records and controlled error envelopes | Migration ownership, privacy-role assumption, production administration |
| Identity provider | Provider session and subject mapping behind the server adapter | Provider subject and session state | Rise Pals profile/assessment/export content; production suitability is undecided |
| Application role | Exact `app.current_user_id`, bounded queries and forced RLS | Current owner's authorized rows | Cross-owner reads, privacy maintenance, schema mutation and public definition mutation |
| Identity resolver | One credentialless security-definer function | Provider-subject-to-internal-owner mapping | Browser access, table ownership, erasure, profile/content/scoring access |
| Migration role | Forward schema migration in an authorized turn | Schema, policies, functions and triggers | Runtime erasure after bootstrap membership is revoked; production operations |
| Privacy operator | Separate controlled maintenance context with exact owner/request UUIDs | Deletion-pending state and deterministic owner erasure | Login, table ownership, public definitions, application/browser execution and real provider access |
| PostgreSQL | Constraints, forced RLS, triggers and transactions | P2/P3 owner data, immutable history and public definitions | External identity-provider deletion and off-host backup policy |
| Public Git history | Reviewed synthetic source, migrations, docs and tests | No secrets, real personal data, exports or dumps | Database backup, credential store, telemetry or production state |
| Temporary recovery directory | One verified GUID child of `%TEMP%\risepals-alpha-recovery` | Short-lived synthetic backup and export bytes | Durable/off-host storage, broad paths and unverified cleanup targets |

## Threats, controls and residual risks

| Threat | Mitigation and verified evidence | Residual risk / stop condition | Owner and status |
|---|---|---|---|
| IDOR or cross-owner access | Every private table keeps enabled and forced RLS. Export queries include an exact owner predicate and fixed row limit. Database tests exercise wrong/missing/malformed context and another-owner preservation. | Stop if any private query can return a row under another owner context or if a new table lacks forced RLS. | Engineering; implemented pending review |
| Migration-role or RLS bypass | Application, resolver and privacy roles are non-superuser and `NOBYPASSRLS`; privacy and resolver roles are `NOLOGIN NOINHERIT`; bootstrap memberships are revoked after migration. | Production role provisioning and staff access remain undecided. Stop if any runtime credential can assume migration/privacy roles. | Security/operations; production decision open |
| CSRF and unsafe mutation | Existing owner mutations remain explicit Server Actions with origin/session controls; export/erasure have no route, Client Component or browser action. | A user-facing export/deletion request flow needs a separate CSRF, re-authentication and confirmation decision. | Product/security; out of scope |
| XSS or malicious locale/redirect/input | Locales and return targets use fixed allowlists; content publication rejects executable/HTML constructs; client DTOs are controlled. | Stop on raw HTML, executable MDX or externally supplied redirect destinations. | Engineering; accepted controls preserved |
| Replay, concurrency or idempotency abuse | Existing mutation UUID constraints remain. Erasure uses a unique opaque request UUID, exact-request replay without writes and conflicting-request rejection under a locked account row. | Distributed provider/DB reconciliation and retry scheduling are not approved. | Engineering; synthetic adapter only |
| Scoring/content/version tampering | Publication seal, registry and aggregate digest remain byte-identical; scoring policy/digests and core/multiplier separation are checked independently. | Assessment, proficiency and learning-efficacy validation remain open. Stop on digest drift outside an authorized content/scoring turn. | Product/evidence; prototype-unvalidated |
| Sensitive logs or error leakage | Browser/network tests reject non-loopback origins and prohibited identifiers. Recovery output reports only aggregate counts/status, never export/P2/P3 bytes. | External error monitoring and production log retention are undecided. | Engineering/operations; external telemetry blocked |
| Export scope confusion | Versioned canonical contract, bilingual limitations, fixed allowlist, local references and per-section `LIMIT 501`/500-row rejection. Provider/subject/digest/error/credential/arbitrary metadata fields are excluded. | Legal completeness, delivery UX, encryption and large-owner pagination are undecided. Stop rather than truncate at the row bound. | Privacy/product; dry run only |
| Path traversal or leftover artifacts | Recovery script accepts only a canonical GUID child under the verified temporary base and cleans exports, dumps and child databases in `finally`. | Host crash can interrupt cleanup. Operators must run the residue checks in the runbook before another rehearsal. | Operations; synthetic local evidence only |
| Over-broad erasure | Privacy role owns no tables, has no login and receives only selected private-table privileges. Forced RLS requires exact current owner. Public definition rows are not granted. | Real identity deletion, user confirmation, legal hold, retention and staff dual control are undecided. | Privacy/security; no production credential |
| Incomplete erasure | Fixed dependency order removes owner assessment, scoring, lesson, evidence, measurement, profile, consent and external-identity rows; only a minimized account tombstone remains. Exact replay is read-only. | Backups can resurrect data; production deletion is blocked until deletion-ledger and backup-expiry rules exist. | Privacy/legal; blocking production risk |
| Backup theft or invalid restore | Dumps exist only in the bounded temporary directory; the rehearsal restores to a separate disposable DB, verifies inventory/digests/RLS and proves invalid restore rejection plus cleanup. | Encryption, off-host storage, RTO/RPO, access audit and production restore approval remain undecided. | Operations/security; production blocked |
| Secret/public-history exposure | `.env.local` remains ignored/untracked/unread. Four-scope Gitleaks and prohibited-output scans gate the turn. No export/dump is committed. | Credential rotation procedures and incident ownership need production approval. | Jeff/operations; no values in docs or chat |
| Supply-chain compromise | No dependency is added; lockfile and reviewed overrides remain fixed; both npm audits are required. | Audit results are not a complete supply-chain guarantee. CI provenance/signing remain open. | Engineering; CI not authorized |
| Clerk session-refresh warning | The retained Development-only warning is recorded and not hidden. Ordinary tests disable Clerk and use loopback only. | Production Clerk behavior, privacy/data residency and session reliability remain unresolved. Recurrence in a future provider smoke must be reported, not suppressed. | Identity/product; production blocker |

## Stop conditions

Stop synthetic-alpha operation and escalate without collecting payloads through chat if any of these occurs:

- cross-owner data exposure, missing forced RLS or unexpected privacy-role membership;
- credential, provider subject, selected answer or export bytes in logs, URLs, Git or third-party traffic;
- publication/scoring digest drift without an authorized decision;
- failed identity deletion, incomplete database erasure or unexplained replay mutation;
- incomplete restore, unexpected database/process/service/listener or temporary recovery residue;
- any request to use this evidence as legal approval, validated proficiency, employment inference or production readiness.

## Decision boundary

RTO, RPO, retention periods, legal basis, privacy notice, provider suitability, staff/operator access, deletion ledger, backup expiry, production secrets, external monitoring, infrastructure and deployment remain undecided. Project Codex review of RP-TURN-018 is required before this threat model can be recorded as accepted, and acceptance would still be synthetic-alpha only.
