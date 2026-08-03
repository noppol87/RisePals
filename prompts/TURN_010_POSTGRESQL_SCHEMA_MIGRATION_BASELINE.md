# RP-TURN-010 — PostgreSQL Schema and Migration Baseline

## Authorization

- **Source:** Project Codex turn authorization accepted by Jeff
- **Authorized base:** `fde04eec45a536f30b1bc53daa2b1e19b4373ccc`
- **Authorized branch:** `agent/postgresql-schema-baseline`
- **Draft PR title:** `feat: establish PostgreSQL schema baseline`
- **Repository:** Public [`noppol87/RisePals`](https://github.com/noppol87/RisePals)

## Objective

Establish the first reviewed PostgreSQL/Drizzle persistence contract for identity mapping, append-only consent and immutable versioned framework/assessment definitions. Prove the SQL migration and security invariants against a fresh disposable PostgreSQL database without creating production infrastructure, real accounts or persisted assessment responses.

## Read first

- `AGENTS.md`
- `README.md`
- `PROJECT_STATUS.md`
- `docs/01_PRODUCT_VISION.md`
- `docs/02_SKILL_FRAMEWORK.md`
- `docs/03_MVP_SCOPE.md`
- `docs/07_TECHNICAL_ARCHITECTURE.md`
- `docs/08_DATA_MODEL.md`
- `docs/09_ENGINEERING_PLAN.md`
- `docs/10_LOCAL_DEVELOPMENT.md`
- `docs/DECISION_LOG.md`
- `prompts/VS_CODE_HANDOFF_TEMPLATE.md`
- Existing environment, assessment-domain and test configuration

## Authorized database decision

- Use a disposable test-only PostgreSQL instance for migration and integration verification.
- Bind PostgreSQL only to loopback and use synthetic data plus temporary credentials.
- Keep binaries, data, logs and credentials outside Git and the repository.
- Do not create a Windows service, firewall rule, public listener, production account, persistent production data directory or paid/managed resource.
- Do not modify machine-wide `PATH`.
- If PostgreSQL is unavailable, a verified supported Windows PostgreSQL binary distribution may be downloaded and used without persistent machine-wide installation.
- If the safe non-service setup requires elevation or cannot be completed, stop with `Decision required`.
- Production PostgreSQL provider, placement, backups and credentials remain open.

Record the material persistence/security boundary in a new decision-log entry without selecting a production provider.

## Schema scope

Add the minimum typed Drizzle schema and exactly one reviewed forward SQL migration for:

1. `user_accounts`
2. `external_identities`
3. append-only `consent_records`
4. `framework_versions`
5. `competency_versions`
6. `scoring_model_versions` only as required for assessment referential integrity
7. `assessment_versions`
8. `assessment_item_versions`
9. `assessment_item_competencies`

Do not add profiles, assessment sessions, raw responses, persisted scores, explanations, recommendations, lesson attempts/progress, XP, proof/evidence storage, analytics or authentication-provider integration.

## Required relational invariants

- Use internal UUID primary keys; external provider subjects are mappings only.
- Require unique `(provider, provider_subject)` identities.
- Require unique framework, scoring-model and assessment business-version keys.
- Store all audit times as `timestamptz` and use database-generated UTC instants.
- Published definition versions are immutable; updates/deletes fail in PostgreSQL rather than relying only on application code.
- Foreign keys and deletion behavior preserve historical/versioned references and fail safely.
- Every JSON boundary is a non-null versioned JSON object validated by PostgreSQL.
- A published Rise Pals framework contains exactly eight `core` competencies and two `multiplier` competencies.
- Published core weights total exactly `10,000` basis points.
- Every core weight is non-null and every multiplier weight is `NULL`.
- Assessment-item mappings reference competencies from the assessment's exact framework version and preserve the target kind.
- Append-only consent allows insertion and owner reads but rejects update/delete.

## RLS and trusted user context

- Enable and force PostgreSQL RLS on every user-owned table in scope.
- Use one validated trusted server-side transaction-local user context; absence or malformed context fails closed.
- The normal application/test role must be `NOSUPERUSER`, `NOCREATEDB`, `NOCREATEROLE`, `NOINHERIT` and `NOBYPASSRLS` and must not own tables.
- Keep schema ownership/migration privileges separate from the normal application role.
- Browser/client code must never receive a database connection string or privileged role.
- Integration tests must use two synthetic UUID users and prove cross-user `SELECT`, `INSERT` where applicable, `UPDATE` and `DELETE` fail closed.
- Tests must also prove the application role does not own tables and has neither superuser nor `BYPASSRLS` capability.

## Configuration and dependency constraints

- Add only the minimum justified PostgreSQL/Drizzle runtime and development dependencies.
- Pin exact versions, preserve the strict install-script allowlist and record package rationale, license/network behavior, replacement path, audit and client-bundle impact.
- Add typed server-only database configuration that rejects a missing URL, non-PostgreSQL protocols, embedded credentials where disallowed by the selected contract, unsafe non-loopback test targets and malformed trusted user IDs without exposing values.
- Keep application and migration URLs distinct at the contract boundary.
- Do not commit any live `.env` file or credential. `.env.example` may contain only safe documented placeholders.

## Disposable database workflow

- Provide bounded PowerShell scripts or Node test orchestration for start, migrate/test and stop/cleanup.
- Resolve every temporary directory to an absolute path outside the repository before cleanup.
- Select an available loopback port rather than opening a firewall rule.
- Initialize PostgreSQL with trust limited to loopback/test process needs or temporary generated credentials that never enter Git or logs.
- Configure `listen_addresses` to loopback only and verify the effective listener.
- Start with `pg_ctl`, never a Windows service.
- Always stop the disposable server and remove its temporary data/log/credential state after verification.
- Document the exact binary source, version, signature/checksum evidence and every environment-level action.

## Required PostgreSQL integration evidence

- Apply the forward migration to a newly created empty database.
- Prove the expected tables, enums, constraints, indexes, triggers, RLS policies and grants exist.
- Prove invalid JSON boundaries, duplicate external identity, wrong core/multiplier weights, incomplete published 8+2 definitions, incompatible assessment mappings and unsafe foreign-key deletes are rejected by PostgreSQL.
- Prove valid exact canonical 8+2 synthetic metadata can publish.
- Prove published framework, competency, scoring-model, assessment, item and mapping definitions cannot be altered or deleted.
- Prove consent history is append-only.
- Prove the two-user RLS matrix with the non-owner/non-`BYPASSRLS` application role.
- ORM mocks are not acceptable evidence for database enforcement.

## Required verification

Run and report:

```powershell
npm ci
npm approve-scripts --allow-scripts-pending --json
npm config get strict-allow-scripts
npm run format:check
npm run lint
npm run typecheck
npm run test
npm run build
npm run check
npm run test:e2e
npm run db:test
npm audit --omit=dev --audit-level=low
npm audit --audit-level=low
git diff --check
```

Also verify and report:

- fresh-empty-database migration and integration-test results
- PostgreSQL version, binary source and checksum/signature evidence
- effective loopback-only listener and absence of a PostgreSQL Windows service
- normal-role ownership/attribute checks and the complete two-user RLS operation matrix
- strict UTF-8, balanced Markdown fences and unresolved markers
- exact dependency/configuration and changed-file inventory
- generated migration drift or schema-to-migration parity
- result/lesson production client manifests and chunks contain no database module, SQL, Drizzle, connection URL or database environment marker
- production and full npm audits
- Gitleaks `8.30.1` scans of nonignored worktree, exact staged content, proposed history and pushed history
- temporary database stop and cleanup
- unchanged local/remote/public `main`
- matching local/remote feature head
- exact Public GitHub destination
- one Open, Draft and unmerged PR
- clean final worktree
- retained Jeff-authorized GitHub authentication without displaying credential details

## GitHub workflow

1. Confirm local, origin and public `main` equal the authorized base and the worktree is clean.
2. Create only `agent/postgresql-schema-baseline` from that base.
3. Inventory and intentionally stage only RP-TURN-010 files.
4. Inspect staged names, diff/stat and `git diff --cached --check`.
5. Scan exact staged content with Gitleaks before commit.
6. Create one intentional implementation commit unless a bounded correction is required.
7. Push normally to `origin` without force.
8. Open exactly one Draft PR to `main` titled `feat: establish PostgreSQL schema baseline`.
9. Verify pushed history, local/remote feature-head equality and unchanged main.
10. Do not mark ready, merge or begin RP-TURN-011.

## Out of scope

- Production or managed database creation/selection
- Production credentials, data, backup or restore resources
- Windows service, firewall, DNS, CI, infrastructure or deployment changes
- Authentication-provider integration, real sign-in or session cookies
- Profiles, onboarding or real user collection
- Persisted assessment sessions, responses, scores, recommendations or results
- Lesson progress, XP, proof/evidence or analytics persistence
- Dependency unrelated to PostgreSQL/Drizzle verification
- Force-push, merge or RP-TURN-011 work

## Acceptance criteria

- A typed Drizzle schema and one reviewed forward SQL migration cover only the authorized tables.
- PostgreSQL itself enforces exact published 8+2 weights/kinds, version identities, JSON boundaries, immutable definitions, append-only consent and safe referential behavior.
- A trusted transaction-local owner context plus forced RLS protects all user-owned tables.
- A separate non-owner/non-`BYPASSRLS` application role passes own-user operations and fails closed for cross-user operations with two synthetic users.
- The migration applies to a fresh empty disposable PostgreSQL database and all integration tests use real PostgreSQL.
- Database code/configuration remains server-only and absent from production client bundles.
- Dependencies are minimal, pinned, audited and compatible with the strict install-script policy.
- Disposable binaries/state remain outside Git, bind only to loopback, create no service/firewall rule and are stopped/cleaned after testing.
- All required quality, browser, audit, encoding and secret-scan gates pass.
- Main remains unchanged and one Draft unmerged PR is created; RP-TURN-011 is not started.

## End-of-turn requirement

Update only factual Turn 010 changes in `PROJECT_STATUS.md`, `README.md`, `docs/08_DATA_MODEL.md`, `docs/10_LOCAL_DEVELOPMENT.md` and `docs/DECISION_LOG.md` as appropriate. Return a handoff using `prompts/VS_CODE_HANDOFF_TEMPLATE.md` with schema/migration identities, RLS role evidence, disposable PostgreSQL environment actions, exact changed files, dependency rationale, actual verification results, commit hash, Draft PR URL, unchanged main and confirmation that RP-TURN-011 was not started.
