# Technical Architecture

**Turn:** RP-TURN-001  
**Status:** Recommended technical direction for the confirmed Windows VPS target; operational choices remain open  
**Reviewed:** 2026-08-01

## Executive decision

Rise Pals ควรเริ่มเป็น **modular monolith** แบบ full-stack web application โดยใช้:

- **Next.js App Router + React + TypeScript strict** สำหรับ public experience และ authenticated learning experience ใน codebase เดียว
- **Node.js 24 LTS + npm** เป็น runtime และ package-manager baseline; pin exact versions when the scaffold is created
- **PostgreSQL** เป็น system of record เพราะข้อมูล assessment, versioning, progress, consent และ proof มีความสัมพันธ์และต้องการ transaction ที่ชัดเจน
- **Drizzle ORM + reviewed SQL migrations** เพื่อให้ schema และ query มี TypeScript types แต่ยังเห็นและควบคุม SQL/RLS ได้
- **Tailwind CSS with CSS custom-property design tokens** สำหรับการส่งมอบ responsive UI เร็ว โดย semantic HTML และ accessibility contract อยู่เหนือ utility classes
- **Git-versioned local MDX plus validated metadata** สำหรับ pilot lessons; publish เป็น immutable lesson versions และอนุญาตเฉพาะ component allowlist ที่ทีมควบคุม
- **Vitest + Testing Library + Playwright + automated accessibility checks** เป็น test stack เมื่อเริ่ม scaffold
- **Native Node.js deployment on the confirmed Windows Server 2022 VPS** behind an HTTPS reverse proxy and Windows service supervision; exact proxy/supervisor choices require a separate infrastructure-readiness turn
- **The existing public GitHub repository [`noppol87/RisePals`](https://github.com/noppol87/RisePals)** as the approved future canonical source/history; connecting this local workspace and making the first push require a separate authorized Git/GitHub turn

แนวทางนี้ตรงกับ MVP ที่ต้องมี landing, assessment, result, interactive lesson, practice, progress และ proof แต่ยังไม่ต้องรับต้นทุนของ microservices, native apps หรือ separate content platform

Windows Server 2022 VPS เป็น production application target ที่ Jeff ยืนยันแล้ว และ Jeff เลือก public repository `noppol87/RisePals` บน personal GitHub account เป็น approved future canonical source/history ส่วน Clerk ถูกเลือกเฉพาะ Development สำหรับ synthetic alpha; production identity suitability ยังเปิดอยู่ เช่นเดียวกับ branch protection, CI, deployment transport, reverse proxy, process supervisor, database placement, object storage, backup, analytics, monitoring และ payment vendor

## Why Next.js

### Framework decision matrix

คะแนน 1–5 สะท้อนความเหมาะสมกับ Rise Pals MVP ไม่ใช่การจัดอันดับ framework ทั่วไป

| Criterion | Weight | Next.js App Router | React Router framework mode | Vite React SPA |
|---|---:|---:|---:|---:|
| Public SEO and server rendering | 20% | 5 | 4 | 2 |
| Interactive assessment/lesson UX | 20% | 5 | 5 | 5 |
| One deployable full-stack unit | 15% | 5 | 4 | 2 |
| Server-only handling of sensitive data | 15% | 5 | 4 | 2 |
| MVP ecosystem and hiring pool | 10% | 5 | 4 | 5 |
| Hosting portability | 10% | 4 | 5 | 5 |
| Convention and maintenance burden | 10% | 4 | 4 | 4 |
| **Weighted result** | **100%** | **4.75** | **4.30** | **3.25** |

**Recommendation after VPS re-evaluation:** Next.js App Router remains the best fit. It supports self-hosted Node deployment and streaming while preserving public pre-rendering/metadata and server-side access to sensitive assessment data. Interactive assessment and lesson elements remain small Client Component islands. The recommendation deliberately avoids depending on Vercel-only services, Edge-only middleware or serverless platform primitives; every production feature must pass the native Windows/Node release test. Official Next.js guidance recommends a reverse proxy in front of a self-hosted server rather than exposing the Next.js process directly.

**Alternative — React Router framework mode:** more runtime-portable and suitable if the team later rejects Next.js conventions. It has less direct alignment with the prepared Next.js-oriented deployment ecosystem and would require a separate validation of content and hosting integrations.

**Alternative — Vite SPA:** simplest purely client-side build, but it would push authentication, personalized data fetching and SEO concerns into additional services. That is a poor trade for sensitive assessment data and a public acquisition site in the same MVP.

## Runtime and dependency policy

- Use **Node.js 24 LTS**, not the newer Current line. Node's official release policy says production applications should use Active or Maintenance LTS; as checked on 2026-08-01, v24 is LTS while v26 is Current.
- Use **npm** initially because it ships with Node and supports reproducible `npm ci`; introducing another package manager is not justified before the project has dependencies.
- Commit `package-lock.json` and pin the runtime in `.nvmrc` or an equivalent file during the scaffold turn.
- Pin direct dependency ranges and let automated update PRs propose upgrades; do not use unreviewed `latest` in CI or production.
- Add a dependency only when its value exceeds its bundle, maintenance, security and vendor-coupling costs.

Next.js currently documents Node.js 20.9 as its minimum, but Rise Pals should target Node 24 LTS because it is supported by the planned Playwright stack and has a longer remaining support window. Exact Next.js and React versions must be captured in the lockfile at scaffold time rather than frozen in this architecture document.

## System shape

```text
Internet browser
  v
Windows Firewall: public 80/443 only
  v
HTTPS reverse proxy service
  |  TLS, request limits, security headers, access logs
  v
127.0.0.1 on an application port selected during the infrastructure-readiness turn
  v
Supervised Next.js/Node modular monolith service
  |-- presentation and route boundary
  |-- server actions / route handlers
  |-- application services and authorization
  |-- domain modules and provider adapters
  +---- TLS database connection ---- PostgreSQL system of record
  +---- private object storage
  +---- consent-safe analytics / redacted telemetry
```

There is one application deployment and one transactional database. The reverse proxy and application run as separate supervised Windows services under least-privilege identities. Logical module boundaries must be enforced in code and tests so a module can be extracted later only when scale, security isolation or team ownership proves the need. Docker, WSL and Linux are not architectural prerequisites because none is currently verified on the production target.

## Approved public-GitHub destination and proposed source/release workflow

Jeff has explicitly approved the existing **Public** repository [`noppol87/RisePals`](https://github.com/noppol87/RisePals), owned by his personal GitHub account, as the future canonical source/history. Ownership and Public visibility are decided. This local workspace is not a Git repository and is not connected to that destination: Git is unavailable, and no local initialization, remote, authentication, commit or push has occurred. Those mutations require a separately authorized Git/GitHub turn.

Proposed flow:

```text
authorized workspace / bounded branch
  → intentional commit
  → public GitHub repository noppol87/RisePals
  → pull request and review
  → automated lint/type/test/content/build checks
  → immutable or versioned release artifact with checksum and source commit ID
  → authenticated transfer to VPS build/staging area
  → install/verify without touching the active release
  → switch active release
  → readiness and external health checks
  → keep release or immediately switch back to the last known-good release
```

Rules:

1. The approved Public GitHub destination is the future source/history authority, not the runtime filesystem. The current VPS workspace and served release directories must never become the only source copy.
2. Because the repository is Public, every tracked file and every commit must be safe for unrestricted disclosure. Never commit `.env` files other than a reviewed safe `.env.example`; credentials, tokens or private keys; production configuration containing secrets; database dumps; uploads or proof artifacts; assessment answers or other personal data; private logs or production telemetry; certificate private keys; generated production data; Playwright authentication state; or backup artifacts.
3. Pull-request review and required checks are the desired main-branch gate. Exact branch protection/ruleset configuration and CI provider remain open and require the separate Git/GitHub turn.
4. CI builds from a pinned lockfile and records source commit, dependency lock digest, build time and artifact checksum. The deployment channel verifies these values before release activation.
5. Production deployment credentials are separate from developer credentials, least-privilege, short-lived where feasible and restricted to the deployment operation. A general-purpose self-hosted GitHub Actions runner must not run on the production VPS without a dedicated threat review.
6. GitHub Actions is a CI candidate, not a decided provider. Confirm the selected branch rules, required reviewers, environment protections and plan capabilities before relying on them.
7. Database migrations run through a distinct, audited migration identity and explicit release step. The application service account never receives schema-owner privileges.
8. Source rollback means selecting a previously verified release artifact, not rebuilding an old commit during the incident. Data rollback uses reviewed forward/restore procedures and is never implied by a code rollback.
9. Do not add a `LICENSE` file until Jeff makes a separate software-licensing decision. Public visibility does not itself grant a reusable software license.

### Required gates before the first push

- inventory every file proposed for tracking and classify whether it is safe for public disclosure
- run a secret scan over the complete worktree and the exact staged content
- confirm every fixture is synthetic and contains no assessment answers, personal data, proof artifact or production-derived value
- review `.gitignore` coverage and verify ignored sensitive/build/runtime paths are not staged
- review documentation for operationally sensitive details such as live credentials, private endpoints, access instructions, host secrets and incident data
- verify the remote destination is exactly `https://github.com/noppol87/RisePals` and the destination visibility is **Public**
- inspect the complete commit history that would be pushed, not only the current files; rewrite/remove exposed data before any network operation
- stop before push and report evidence for these gates in the separately authorized Git/GitHub turn

Open GitHub operational decisions:

- Git/GitHub authentication on authoring workspaces and deployment authentication on the VPS
- branch rules/rulesets, required reviewers and CI provider/plan
- artifact storage/retention and deployment transport (for example restricted SSH/SFTP, WinRM or a pull-based agent)
- software licensing; no `LICENSE` is added by this architecture turn

## Application modules and data ownership

| Module | Responsibility | Owns | Must not own |
|---|---|---|---|
| Public experience | Landing, product explanation, evidence claims, waitlist/pricing placeholder | Published public content cache | User assessment or proof |
| Identity and access | Session verification, provider identity mapping, roles | Provider mapping and application account status | Career profile fields |
| Profile and consent | Role context, goals, locale, consent receipts | User profile and consent records | Authentication credentials |
| Framework | Immutable 8+2 definitions and proficiency stages | Framework/competency versions | User scores |
| Assessment | Definitions, sessions, raw answers, scoring runs, explanations | Assessment data and recommendations | Hiring eligibility |
| Learning content | Lesson/practice/rubric/source versions and publication state | Published content metadata | User attempts |
| Learning progress | Lesson attempts, practice submissions, feedback, XP ledger and progress snapshots | User learning records | Content source files |
| Evidence | User-controlled proof metadata, files and share grants | Evidence artifacts and access grants | Public-by-default portfolio |
| Measurement | Minimal consent-aware product events and operational telemetry | Pseudonymous event stream | Raw answers, proof contents or free text |
| Internal operations | Draft/review/publish actions and audit records | Staff action audit trail | Direct unrestricted client access to tables |

Cross-module reads go through typed application services or read models. Direct imports of another module's internal repository are prohibited. Shared code is limited to identifiers, timestamps, error types, localization primitives and validation utilities.

## Rendering and request boundaries

| Experience | Default rendering | Client responsibility | Server responsibility |
|---|---|---|---|
| Landing/evidence | Static or revalidated Server Components | Small navigation/CTA interactions | Published claims, metadata, cache policy |
| Onboarding/profile | Server-rendered shell | Field interaction and progressive disclosure | Validation, consent recording, authorization |
| Assessment | Server-rendered shell plus Client Component player | Current-question state, keyboard interaction, optimistic progress | Session ownership, answer validation, durable save |
| Skill result | Dynamic Server Components | Accessible chart interaction and optional animation | Score/explanation retrieval and DTO shaping |
| Lesson/practice | Server-rendered content plus interactive islands | Scenario choices, simulation and motion | Content version, attempt state, rubric evaluation |
| Progress/proof | Dynamic Server Components | Filters, upload interaction and share controls | Owner checks, signed upload/download operations, ledger calculation |

Rules:

1. Server Components are the default. Add `'use client'` only at the smallest boundary that needs browser state or APIs.
2. Secrets, database access, scoring and authorization live in server-only modules.
3. Server Actions are suitable for first-party form mutations. Route Handlers are used for stable HTTP boundaries such as webhooks, uploads or future external integrations.
4. Every mutation performs authentication, authorization, input validation and audit/event decisions inside the application service; hiding a control in the UI is never authorization.
5. Personalized or sensitive responses must never enter a public/shared cache. DTOs return only fields required by the view.

## Domain and persistence direction

### PostgreSQL

PostgreSQL fits the MVP because immutable framework/content versions, assessment responses, score derivations, consent, attempts and evidence require relational integrity. `jsonb` is reserved for bounded, schema-validated snapshots such as answer payloads or rubric details; stable identifiers and relationships remain normal columns with foreign keys.

PostgreSQL Row-Level Security should be used as defense in depth on user-owned tables when the chosen hosting/auth model can provide a trustworthy user context. RLS is not a replacement for server-side authorization: table owners and roles with `BYPASSRLS` can bypass policies, so application tests must cover both the Data Access Layer and database policy behavior.

RP-TURN-012 implements the first bounded learner-state slice through exactly two additional tables. `assessment_sessions` anchors the internal owner, exact published assessment version, granted consent receipt used at start, database-owned lifecycle timestamps and an item-version resume marker. `assessment_responses` keeps an exact versioned selected-option payload plus monotonic revision, supersession, client-mutation idempotency and active-revision state. Composite foreign keys prove session/item version compatibility; triggers reject non-canonical options, malformed payloads, incomplete submission and every post-submit mutation. Both tables use ENABLE/FORCE RLS, and the application role has no DELETE privilege. The authenticated Server Action/DAL path remains inside the accepted authorization transaction; no database UUID, provider subject, consent history, rubric, target or score enters a client DTO.

RP-TURN-013 adds a bounded derived-result layer without changing the raw-response or session lifecycle. One forward migration adds exactly `scoring_runs`, `competency_scores`, `multiplier_observations`, `score_explanations` and `priority_recommendations`. Composite foreign keys preserve owner/session/framework provenance; all five tables use ENABLE/FORCE RLS, and the application role has SELECT/INSERT only. Deferred completion constraints require an atomic two-core/two-multiplier/six-explanation/zero-or-one-priority shape, reproduce exact submitted rubric evidence and reject malformed priorities before commit. Triggers make completed runs and children immutable.

The server-only scorer pins `persisted-synthetic-priority-v1@1.0.0` and its canonical SHA-256 digest. Canonical input contains exact accepted assessment/framework/scoring identities and content digests, policy provenance and canonical item/revision/option evidence, but not owner/session UUID, time or locale. Semantic output excludes database IDs, time and localized copy. Normal generation locks the submitted session and uses a transaction advisory lock so concurrent requests converge on one run; only an explicit server-only API can append a next rescore run. Result GETs are read-only, and the browser action supplies only locale plus a mutation UUID.

The result DTO is deliberately narrower than persisted storage: localized names, raw earned/available core fractions, evidence counts, six unassessed names, separate multiplier observation labels, controlled explanations/limitations and a bounded priority/action state. Selected options, raw payloads, table/row IDs, digests, policy details and RLS context never cross the client boundary. The result remains a synthetic-alpha two-core slice, not a validated profile, percentage proficiency or employment inference.

This does not change the public session-only player. `/[locale]/assessment` keeps its existing temporary tab-local state, while `/[locale]/assessment/attempt` is an explicit signed-in PostgreSQL flow and never reads or promotes the public player's `sessionStorage`. Disposable bootstrap data publishes only the repository-local reviewed synthetic definition; no product definition is seeded by the production migration.

### Drizzle

Drizzle is recommended because its SQL-like, typed API and generated SQL migrations keep PostgreSQL behavior visible. This matters for immutable version references, constraints, partial indexes, RLS and future data export/deletion work.

**Alternative — Prisma:** stronger declarative schema ergonomics and a mature generated client. Prisma migrations remain customizable SQL, but PostgreSQL-specific policies and complex query behavior may require more explicit custom migration work. Re-evaluate if the implementation team values Prisma's workflow more than SQL proximity.

**Alternative — direct `pg` plus SQL migrations:** maximum control and minimum abstraction, but adds repetitive mapping and type-maintenance work too early.

## Lesson content architecture

The pilot source of truth lives in Git. RP-TURN-014 implements this exact source and generated-output shape:

```text
content/
  lessons/
    source-verification-practice/
      1.0.0/
        lesson.meta.json
        practice.json
        rubric.json
        proof.json
        sources.json
        locales/
          th/lesson.mdx
          en/lesson.mdx
  publication-manifest.json
  published-lessons.json
```

Git-reviewed metadata, practice, rubric, proof, source records and localized MDX are authoritative inputs. The manifest and registry are tracked deterministic outputs. The published identity is the exact lesson key plus semantic version; every strict UTF-8/LF input has a SHA-256, and the sorted path/digest set produces one aggregate lesson digest. Identical source produces byte-identical JSON. An altered digest under an already published identity fails before output mutation and requires a new semantic version.

Each metadata file must validate at build/publish time and include:

- stable lesson ID, semantic content version and publication status
- exact Thai/English locale set and an explicit no-fallback policy
- framework version, target competencies and target proficiency stage
- R.O.I. pillar mapping
- prerequisite and estimated active time
- practice definition, feedback rubric and proof contract
- source/evidence metadata required by `docs/05_BRAND_VISUAL_CONTENT.md`
- author/reviewer identity references and review timestamps

MDX is allowed only from the trusted repository. Exact-pinned build-only `unified`, `remark-parse` and `remark-mdx` packages create an AST; the pipeline never compiles or evaluates that AST as JavaScript. It emits only a controlled JSON render plan. Paragraphs, headings 2–4, ordered/unordered lists, strong/emphasis, blockquotes, inline code and reviewed HTTPS/same-origin links are the complete Markdown allowlist. `Scenario`, `ConceptList`, `PracticeMount`, `RubricSummary`, `ProofPlaceholder` and `ReflectionPrompt` are the complete local component allowlist for the current bundle. Runtime imports only the validated JSON registry through a server-only boundary and maps those identifiers to fixed local lesson sections.

ESM, expressions, spread or expression-valued attributes, event handlers, raw HTML, images, unknown nodes/components, unsafe URLs, traversal, absolute filesystem paths, symlinks, unsupported files and ambiguous IDs fail closed. User inputs and proof are data, never executable lesson content. No user-supplied, database-supplied, remote-CMS or network-fetched MDX is accepted.

RP-TURN-014 selects a build-time registry and content digest for the pilot rather than a database import. It adds no lesson/practice/rubric/source table or migration. A database mirror, internal CMS, preview service and production publishing operations remain future decisions. Operational status `published` means available through the repository-local registry for synthetic alpha; separate status `prototype-unvalidated` means publication does not claim calibrated outcomes, efficacy, credentials, employability or external validation.

**Alternative — structured block JSON:** safer for a future CMS and non-technical authors, but requires an editor and renderer schema before the lesson grammar has been validated.

**Alternative — headless CMS:** useful when content operations outgrow Git review, but introduces vendor cost, webhooks, preview authorization and another data source before the pilot workflow is known.

## Provider seams and deployment options

No cloud resource is selected or created in RP-TURN-001. Application code must depend on small internal interfaces rather than importing vendor SDKs throughout the domain:

- `IdentityProvider`: resolve session and provider subject; never define application roles solely in provider metadata
- `ObjectStore`: create signed upload/download/delete operations and record checksums
- `ProductAnalytics`: accept allowlisted event name and non-sensitive properties
- `Telemetry`: capture redacted errors, traces and correlation IDs
- `EmailDelivery`: reserved boundary; no email vendor is needed in the prototype
- `EntitlementProvider`: reserved for paid beta; payment status is not the learning domain

### Confirmed application host and feasible Windows approaches

The intended production application target is this Windows Server 2022 VPS. This is a deployment constraint, not an exit path. The host is **not production-ready yet**: only OS/PowerShell facts are verified; Git, Node, Docker and a usable WSL distribution were not found, and reverse proxy, service accounts, firewall rules, backup and monitoring state have not been approved or configured.

| Approach | Strength for Rise Pals | Trade-off / validation need | Status |
|---|---|---|---|
| Native Node standalone/`next start` + Caddy as Windows services | Direct fit with confirmed Windows host; Caddy documents Windows service and reverse-proxy/HTTPS operation; no container prerequisite | Adds Caddy and a Node service wrapper/supervisor; Windows service identities, certificate storage, streaming, logs and restart behavior need a rehearsal | Preferred readiness candidate, not selected/installed |
| Native Node + IIS, URL Rewrite and ARR | Microsoft-native administration and mature Windows TLS/IIS tooling | IIS roles plus URL Rewrite/ARR modules are prerequisites and not verified; proxy buffering/streaming and patch ownership require tests | Active Windows alternative |
| Native Node + another reviewed Windows reverse proxy/service wrapper | May fit existing operator expertise | Security maintenance, TLS automation, service recovery and log rotation must be evidenced tool by tool | Open alternative |
| Windows/Linux containers | Reproducible packaging if the host is deliberately prepared for it | Docker is absent and usable WSL/Linux is unverified; Windows container compatibility and operations add a separate platform decision | Not a baseline assumption |
| Vercel, Cloudflare Workers or AWS Amplify | Lower server operations and useful preview environments | Would change the confirmed production target or create a split-host design, external cost and data-region review | Alternative only; requires a new Jeff decision |

Next.js remains suitable because its official self-hosting path supports a Node server, App Router streaming and a reverse proxy. The implementation must avoid cloud-only dependencies and test the exact Windows artifact before release. `output: 'standalone'` versus `next start` is intentionally open until the scaffold and infrastructure turns compare artifact contents, runtime cache/image behavior and service supervision.

### Production boundary contracts

#### HTTPS termination and reverse proxy

- Only the reverse proxy listens publicly on TCP 80/443. Redirect HTTP to HTTPS and manage certificate issuance/renewal with an audited process.
- The Next.js service binds to loopback only. Never expose its application port in the public firewall.
- Proxy configuration owns request/header size limits, slow-client protection, safe forwarded headers, timeouts and access-log redaction.
- Validate streaming/Suspense end-to-end; proxy buffering must not silently break App Router streaming.
- Proxy configuration and certificate state are separate: configuration templates may be in Git, private keys/certificate working state may not.
- Caddy versus IIS/ARR is unresolved. The infrastructure-readiness turn must inventory installed roles, prove TLS renewal/reload and document emergency certificate recovery before selection.

#### Node process supervision and restart

- Run the application as a Windows service with automatic start, controlled restart-on-failure, startup timeout and a bounded failure loop.
- Capture stdout/stderr without allowing unbounded files. Prove graceful stop and in-flight request behavior.
- A Windows service wrapper such as WinSW is one candidate; the exact wrapper and version are not selected. Running `npm start` in an interactive terminal or relying only on Task Scheduler is not a production supervision plan.
- Reverse proxy and application are independently restartable. A failed application readiness check must not cause the deployment script to switch traffic permanently.

#### Least-privilege identities and filesystem access

- Use separate non-interactive service identities for reverse proxy and application where practical; never run the application under the built-in Administrator account or LocalSystem without an explicit, evidenced requirement.
- The application identity reads the active release and its secret/config location, writes only approved runtime cache/log/temp paths and connects only to required network endpoints.
- The deployment identity can create a new versioned release and change the active-release mechanism but does not read application data or database contents.
- Administrators retain break-glass control; day-to-day deployment must not require an interactive admin session.

#### Firewall and exposed ports

- Default-deny inbound. Public rules allow only the chosen proxy executable/service on 80/443.
- Restrict VPS administration ports to Jeff's approved source IP/VPN/control plane; the exact administration method is open.
- Keep Node and any local database bound to loopback/private interfaces. A remote managed database accepts only encrypted, authenticated traffic from the approved VPS egress path.
- Document every rule with purpose, executable/service, ports, scope, owner and review date; verify externally that no unintended port is reachable.

#### Secret storage

- Store runtime secrets outside the repository, build/staging area and versioned releases, with ACLs limited to the application service and administrators.
- `.env` may be a local format only if the production file is outside Git/releases, ACL-restricted, excluded from logs/backups as appropriate and loaded without copying into the artifact. Windows Credential Manager/DPAPI or another secret store remains an alternative requiring operational testing.
- CI/deployment credentials and runtime application secrets are separate. Rotate them independently and document emergency revocation.

#### Logs, redaction and rotation

- Application logs are structured, include time/severity/correlation/release ID and exclude raw answers, scores, proof contents, tokens, cookies, signed URLs and direct identifiers.
- Separate application/error, reverse-proxy access, deployment/audit and security logs with explicit owner, path, rotation, retention and access controls.
- Rotation must cap disk use and preserve enough off-host evidence for incident response. Production telemetry storage is not GitHub.

#### Health checks and monitoring

- `/health/live` proves the process event loop can answer and reveals no dependency or version detail publicly.
- An authenticated/internal readiness check verifies critical dependencies such as database and content registry with strict timeouts; it never returns secrets or user data.
- Deployment runs local readiness then an external HTTPS smoke check. Monitoring alerts on availability, certificate expiry, repeated restart, disk pressure, backup failure and abnormal error rate.
- Define who receives and acknowledges alerts before public launch.

#### Build/deploy separation, releases and rollback

- Never build or develop inside the live served release directory. The repository workspace, build/staging area, immutable/versioned releases, persistent data, secrets and logs are distinct paths with distinct ACLs.
- A release is identified by source commit plus artifact checksum. Install into a new release directory, verify dependencies/content/migrations, start/probe it and only then switch the active release.
- The switching mechanism may be a validated NTFS junction/symlink, proxy upstream/port switch or another atomic Windows-safe method. It remains open until rehearsal proves permissions, file-lock and rollback behavior.
- Retain at least the last known-good release according to a disk/retention policy. Rollback switches to that already-built artifact and reruns health checks; it does not overwrite the broken directory.

#### Database connectivity and backup/restore ownership

- PostgreSQL placement remains open: managed service is preferred for operational isolation, while VPS-local PostgreSQL requires a separate capacity, patch, exposure and off-host-backup decision.
- Use TLS, a least-privilege application role and a separate migration role. Do not expose PostgreSQL publicly or embed credentials in the release.
- Assign named ownership for database backups, object uploads, configuration/certificate material and VPS/system recovery. Define frequency, encryption, off-host location, retention, monitoring and restore targets.
- GitHub is not a database/upload/system backup. A backup is not accepted until a non-production restore drill proves it can recover within agreed objectives.

#### OS/runtime patching and incident response

- Assign an operator for Windows security updates, Node LTS/security updates, proxy/service-wrapper patches and dependency advisories. Patch via a scheduled, rehearsed window with post-restart health checks and rollback notes.
- Before launch, document incident severity, contact/decision owner, isolation steps, secret rotation, release rollback, evidence preservation, user/legal notification assessment and recovery verification.
- During an incident, preserve redacted logs and release identifiers, revoke compromised access, restore from known-good sources and record decisions; do not debug by copying production data into Git or the development workspace.

### Managed PostgreSQL

| Option | Strength | Trade-off | Status |
|---|---|---|---|
| Neon | Serverless Postgres, pooling and isolated/schema-only branching for previews | Separate auth/storage vendors; region, backup and cost review needed | Preferred database candidate, not selected |
| Supabase | Full Postgres plus integrated Auth, Storage and RLS-oriented tooling | Bundled services can couple identity/storage conventions to one platform | Active integrated alternative |
| AWS RDS/Aurora PostgreSQL | Mature networking, backup and enterprise controls | Higher setup and operations burden for MVP | Enterprise alternative |

### Authentication

| Option | Strength | Trade-off | Status |
|---|---|---|---|
| Clerk | First-class Next.js SDK and hosted email-code flow | External identity dependency; Development data is US-hosted and localization is experimental | Selected for synthetic-alpha Development only; production undecided |
| Supabase Auth | Natural integration if Supabase is also database/storage provider | Increases platform coupling; session/RLS design must be consistent | Integrated alternative |
| Auth.js | Open source and greater control of identity/provider adapters | Team owns more configuration, security maintenance and account UX | Control-oriented alternative |

Application users always receive an internal `user_id`; provider subjects map to it. Assessment, progress and evidence rows never use a vendor user ID as their primary ownership key. This keeps provider migration and account linking possible.

RP-TURN-011 implements Clerk only behind `IdentityProvider` and provider/server integration modules. Configuration accepts a complete `pk_test_`/`sk_test_` pair and rejects incomplete or live credentials without echoing values. Dedicated locale-prefixed catch-all sign-in and sign-up routes cross-link through explicit SDK URLs and share a same-locale validated fallback; a return target from the other locale is rejected rather than silently switching language. The Clerk SDK manages its own session cookies; Rise Pals creates no auth cookie and stores no provider token. The server validates the session, takes the provider subject directly from that validated server result, serializes first-sign-in resolution and maps it to `user_accounts.id` before setting transaction-local database context. Browser input cannot supply this subject to the data layer.

The resolve-or-provision function is `SECURITY DEFINER` owned by a dedicated `rise_pals_identity_resolver` role with `NOLOGIN`, `NOSUPERUSER`, `NOCREATEROLE`, `NOINHERIT` and `NOBYPASSRLS`. It receives only the table/function privileges required for Clerk lookup, atomic account creation and last-seen updates. Provider lookup remains behind forced RLS; neither `rise_pals_owner`, `rise_pals_app` nor `PUBLIC` receives an unrestricted provider-identity policy. A privileged deployment bootstrap may grant the migration owner temporary `SET ROLE` capability solely to transfer function ownership, but must revoke that membership immediately after the migration; the application role can execute the bounded function but cannot assume the definer role. The disposable harness represents and verifies this sequence without adding a privileged application-runtime URL.

The application authorization source remains PostgreSQL: `active` may proceed while `suspended`, `deletion_pending` and `deleted` fail closed. Clerk metadata is not an authorization, profile, goals, consent, assessment or application-role store. The database mapping intentionally leaves email null because the approved flow has no need to copy it. Client DTOs contain only controlled profile/consent presentation fields and never session tokens, provider subjects or secrets.

For RP-TURN-012, start/save/resume/submit also rechecks the current exact service-data purpose/notice decision inside the owner transaction. Start stores the exact granted receipt server-side; browser input cannot choose it. Consent decline or withdrawal blocks new writes and submission without claiming deletion. Retention, export and erasure remain open. Server operations resolve the owner session from trusted context rather than accepting a session UUID from the browser, use an expected revision plus client mutation UUID for safe retries and return a structured stale-write state without identifiers or payload-bearing error text.

This selection is deliberately non-production. Use one Jeff-controlled Clerk Development application, Free/Hobby, email verification code only and synthetic identities only. Do not enable Production, payment, social login, SMS, passwords, Organizations or custom domains. Clerk's Development instance and US identity hosting require a separate production privacy/legal/residency/security/vendor decision. Thai Clerk localization is experimental, so Rise Pals supplies authoritative bilingual boundary/fallback copy and regression coverage. A real provider smoke and synthetic-user deletion remain required when Jeff supplies ignored Development keys.

### Object storage, analytics and monitoring

- Object storage candidates: Supabase Storage, Cloudflare R2 or AWS S3. Require private buckets, short-lived signed URLs, server-side authorization and deletion support. Select only when proof upload enters scope.
- Product analytics candidates: PostHog, a privacy-focused hosted analytics service, or a minimal first-party event table. Selection requires consent, Thailand/legal review, data residency, retention and deletion evaluation.
- Monitoring candidates: Sentry or OpenTelemetry-compatible infrastructure. Error payloads must be redacted and must not include raw assessment responses, proof contents, tokens or sensitive profile fields.

## Localization, responsive UI, accessibility and motion

### Localization

- Route public and authenticated experiences through a locale segment such as `/th/...`; Thai is the initial default and English is the prepared fallback.
- Use BCP 47 locale identifiers and versioned message catalogs. UI strings do not live inline in reusable domain/UI components.
- Store content locale on every lesson/evidence claim version. Do not assume a Thai translation is semantically identical when a rubric changes.
- Dates, numbers and pluralization use `Intl`; timestamps remain UTC in storage and render in the user's chosen timezone.
- Search, line breaking, font choice and form validation must be tested with real Thai text, not only Latin placeholders.

### Accessibility and responsive contract

- Target **WCAG 2.2 AA** for public and authenticated flows.
- Semantic HTML, visible focus, complete keyboard paths, programmatic labels, useful errors, live-region feedback and non-color-only meaning are acceptance criteria.
- Custom pointer targets meet at least 24×24 CSS pixels or the WCAG spacing exception; primary touch actions should aim for 44×44.
- Charts and skill maps provide text/table equivalents and never encode risk only through red/green color or an unexplained gauge.
- Mobile-first layouts must work from 320 CSS pixels without horizontal scrolling at 400% zoom where the WCAG reflow exception does not apply.

### Motion contract

- Motion must explain progress, cause/effect or feedback; it is not a completion gate.
- Honor `prefers-reduced-motion: reduce` from the first component. Remove non-essential translation, scale, parallax and autoplay; preserve state changes with instant updates, opacity or static alternatives.
- Any automatically moving content lasting more than five seconds needs pause/stop/hide unless essential.
- Test full-motion and reduced-motion modes in component and end-to-end checks.

## Security and privacy baseline

Assessment and career data are sensitive even if local law does not assign every field a special category. The baseline is:

1. **Minimize:** collect only role context needed for recommendation; no employer name, exact salary, national ID or raw work documents in the MVP unless a later brief explicitly approves them.
2. **Separate:** raw answers, derived scores, explanations, analytics and user-controlled proof have separate entities and access paths.
3. **Authorize near data:** central Data Access Layer verifies session and ownership for every sensitive read/mutation; database policies add defense in depth.
4. **Private by default:** proof and profiles are private. Sharing requires an explicit, revocable grant with scope and expiry.
5. **Encrypt:** TLS in transit and managed encryption at rest are vendor-selection gates. Secrets stay in server runtime secret stores.
6. **Constrain caches and logs:** no sensitive response in shared cache, URL/query string, analytics payload or error breadcrumbs. Use opaque correlation IDs.
7. **Validate:** all boundaries validate size, type and allowed values. Parameterized ORM/SQL APIs prevent injection; rich content is sanitized/allowlisted.
8. **Protect uploads:** signed operations, content-type/size checks, malware-review strategy, checksum, non-executable delivery headers and owner-scoped object keys are required before proof uploads ship.
9. **Audit privileged actions:** publishing, staff access, export, deletion and share changes create tamper-evident audit records without copying sensitive payloads.
10. **Support agency:** consent is versioned; users can correct profile data, understand score provenance, export their data and request deletion.
11. **Secure web defaults:** `HttpOnly`, `Secure`, `SameSite` cookies; CSRF protection for cookie-authenticated mutations; CSP, frame restrictions, content-type protections, referrer policy and dependency scanning.
12. **No automated employment gate:** neither an overall score nor a priority gap becomes an eligibility field. Future matching must use user-approved evidence, explainability, fairness audit and human review.

## Quality and operational boundaries

- Validate environment variables once at server startup; reject missing or malformed required configuration.
- Schema migrations are reviewed SQL artifacts, run forward in CI/staging before production and paired with rollback/roll-forward notes.
- Backups, point-in-time recovery, region, data-processing terms, deletion from backups and incident response are vendor-selection gates.
- Every content build validates framework references, lesson/rubric versions, locale coverage and evidence-source metadata.
- Observability separates product events from security/audit events and from error telemetry.
- Performance budgets begin in the scaffold: minimize client JavaScript, lazy-load motion/visualization code and test representative Thai mobile pages.
- A VPS release cannot be declared ready until HTTPS/reverse proxy, service restart, least-privilege identity, firewall, secrets, log rotation/redaction, health monitoring, backup restore and rollback have passed a dedicated non-production rehearsal.
- Production release directories are treated as replaceable/read-only artifacts. Persistent uploads, secrets, logs and database state survive release replacement through separately owned paths/services.

## Explicitly deferred decisions

- Production authentication suitability/deletion orchestration plus database-hosting and object-storage vendors/placement
- Windows HTTPS reverse proxy, Node service supervisor/wrapper, release-switch mechanism and deployment authentication
- Public `noppol87/RisePals` connection/first push, Git/GitHub authentication, branch rules, CI provider/plan, deployment transport and software licensing
- Analytics, monitoring, email and payment vendors
- Production region and data-retention periods pending privacy/legal review
- Backup products/locations, recovery objectives, log destinations/retention and incident-response ownership
- Exact lesson authoring UI after the Git-based pilot demonstrates content operations
- Multi-tenant employer model and all hiring/matching services
- Any AI-generated feedback service, model or data-processing agreement

## Evidence reviewed

All links below were checked on 2026-08-01. They support framework/runtime capabilities and decision trade-offs; vendor marketing claims still require a commercial, security and privacy review before purchase.

- [Next.js installation and system requirements](https://nextjs.org/docs/app/getting-started/installation)
- [Next.js Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components)
- [Next.js authentication and Data Access Layer guidance](https://nextjs.org/docs/app/guides/authentication)
- [Next.js internationalization guide](https://nextjs.org/docs/app/guides/internationalization)
- [Next.js MDX guide](https://nextjs.org/docs/app/guides/mdx)
- [Next.js self-hosting and reverse-proxy guidance](https://nextjs.org/docs/app/guides/self-hosting)
- [Node.js release policy and current LTS lines](https://nodejs.org/en/about/previous-releases)
- [PostgreSQL Row-Level Security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [PostgreSQL JSON types](https://www.postgresql.org/docs/current/datatype-json.html)
- [Drizzle ORM overview and migration model](https://orm.drizzle.team/docs/overview)
- [Prisma ORM and customizable SQL migrations](https://www.prisma.io/docs/orm)
- [Cloudflare Workers support for Next.js](https://developers.cloudflare.com/workers/framework-guides/web-apps/nextjs/)
- [AWS Amplify Next.js deployment](https://docs.aws.amazon.com/amplify/latest/userguide/getting-started-next.html)
- [Caddy Windows service guidance](https://caddyserver.com/docs/running)
- [Caddy reverse proxy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
- [Microsoft IIS URL Rewrite and ARR reverse proxy](https://learn.microsoft.com/en-us/iis/extensions/url-rewrite-module/reverse-proxy-with-url-rewrite-v2-and-application-request-routing)
- [Microsoft Windows service account guidance](https://learn.microsoft.com/en-us/windows/win32/ad/guidelines-for-selecting-a-service-logon-account)
- [Microsoft Windows Firewall rule guidance](https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/rules)
- [GitHub protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [GitHub deployment environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)
- [GitHub push protection](https://docs.github.com/en/code-security/concepts/secret-security/push-protection)
- [Neon branching workflow](https://neon.com/docs/get-started-with-neon/workflow-primer)
- [Supabase PostgreSQL and RLS guidance](https://supabase.com/docs/guides/database/overview)
- [Clerk Next.js SDK](https://clerk.com/docs/reference/nextjs/overview)
- [Auth.js](https://authjs.dev/)
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)
- [WCAG guidance for animation from interactions](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions)
- [Playwright test runner and browser support](https://playwright.dev/docs/intro)
