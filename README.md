# Rise Pals

Rise Pals คือแพลตฟอร์มพัฒนาความพร้อมในการทำงานยุค AI สำหรับคนทำงานออฟฟิศไทย ช่วยให้ผู้ใช้รู้ว่าตนเองมีช่องว่างด้านทักษะอะไร ควรพัฒนาอะไรก่อน เรียนผ่านประสบการณ์แบบ gamified และสร้างหลักฐานความสามารถที่ต่อยอดไปสู่โอกาสทางอาชีพได้

**Brand:** Rise Pals  
**Digital wordmark:** `risepals`  
**Primary domain:** `risepals.com`  
**Project status:** RP-TURN-017 consent-aware measurement/monitoring foundation complete pending review / no real users, external telemetry or production service  
**Last updated:** 2026-08-24

## Product thesis

AI ไม่ได้ทำให้ตำแหน่งงานทุกตำแหน่งหายไปทันที แต่มันกำลังเปลี่ยนสิ่งที่บริษัทคาดหวังจากคนในตำแหน่งเดิม งานที่เป็น routine execution ถูกลดมูลค่า ขณะที่ judgment, system thinking, governance, storytelling และความสามารถในการสร้างผลลัพธ์ทางธุรกิจมีมูลค่าสูงขึ้น

Rise Pals จึงไม่ใช่เพียง course marketplace แต่เป็นระบบที่พาผู้ใช้เดินครบวงจร:

> Diagnose → Prioritize → Learn → Practice → Prove → Opportunity

## กลุ่มผู้ใช้เริ่มต้น

- คนทำงานออฟฟิศไทยที่กังวลว่าทักษะเดิมกำลังถูก AI ลดมูลค่า
- Professionals ในสาย Administration, Business Support, Finance, Accounting, IT, Digital Transformation, Marketing และสายงานที่มี routine knowledge work สูง
- คนที่ต้องการเปลี่ยนจาก task executor เป็นคนที่สร้าง business impact ได้ชัดเจน
- ในอนาคต: บริษัท ผู้สอน HR และ hiring partners

## คุณค่าหลักของผลิตภัณฑ์

1. ประเมินความพร้อมตามกรอบทักษะ 8+2
2. แสดง skill gaps และลำดับการพัฒนาที่เหมาะกับผู้ใช้
3. เปลี่ยนการเรียนเป็นภารกิจสั้น ๆ ที่มี feedback, XP และ progression
4. ให้ผู้ใช้ลงมือทำและสะสมหลักฐาน ไม่ใช่เพียงดูวิดีโอจบ
5. เชื่อม skill proof กับคอร์ส mentorship และโอกาสงานในอนาคต
6. ใช้ข้อมูลจริงสร้างความเร่งด่วนโดยไม่หลอกหรือทำให้ผู้ใช้ตื่นกลัวเกินจริง

## Revenue model เบื้องต้น

- Free assessment และผลลัพธ์ระดับพื้นฐาน
- Monthly / yearly membership
- Package privileges สำหรับ online course, live cohort และ onsite learning
- Premium coaching, workshop และ skill certification
- B2B workforce assessment และ team upskilling
- Talent matching / hiring marketplace ในระยะถัดไป

## เอกสารสำคัญ

- [Product Vision](docs/01_PRODUCT_VISION.md)
- [8+2 Skill Framework](docs/02_SKILL_FRAMEWORK.md)
- [MVP Scope](docs/03_MVP_SCOPE.md)
- [Product Roadmap](docs/04_PRODUCT_ROADMAP.md)
- [Brand, Visual and Content Principles](docs/05_BRAND_VISUAL_CONTENT.md)
- [Codex Collaboration Workflow](docs/06_CODEX_COLLABORATION_WORKFLOW.md)
- [Technical Architecture](docs/07_TECHNICAL_ARCHITECTURE.md)
- [Data Model](docs/08_DATA_MODEL.md)
- [Engineering Plan](docs/09_ENGINEERING_PLAN.md)
- [Local Development](docs/10_LOCAL_DEVELOPMENT.md)
- [Decision Log](docs/DECISION_LOG.md)
- [Current Project Status](PROJECT_STATUS.md)

## Application foundation

RP-TURN-003 established one minimal Next.js App Router application at the repository root. RP-TURN-004 established a Thai-first localized shell. RP-TURN-005 through RP-TURN-014 established the bounded public narrative, synthetic assessment/player/result, lesson prototype, database/authentication/persistence boundaries and trusted content publication. RP-TURN-015 adds a separate authenticated synthetic-alpha lesson/practice/progress path with explicit server writes. RP-TURN-016 adds a separate private controlled source-verification note after demonstrated practice. RP-TURN-017 adds an optional first-party consent-aware measurement/error foundation without external telemetry. These turns do not create a real account, production resource, validated learning outcome, credential, shareable proof or production launch.

Locale routes:

- `/` redirects to the Thai default at `/th`
- `/th` renders the Thai shell and catalog
- `/en` renders the prepared English shell and catalog
- `/th/assessment` and `/en/assessment` render the matching six-scenario player prototype
- `/th/assessment/attempt` and `/en/assessment/attempt` are dynamic protected synthetic-alpha paths for explicit PostgreSQL start/save/resume/submit; no session identifier appears in the URL
- `/th/assessment/example-result` and `/en/assessment/example-result` render the matching static synthetic example result
- `/th/lessons/source-verification-practice` and `/en/lessons/source-verification-practice` render the matching local lesson/practice prototype
- `/th/learning` and `/en/learning` are dynamic protected controlled-progress summaries
- `/th/lessons/source-verification-practice/attempt` and `/en/lessons/source-verification-practice/attempt` are dynamic protected explicit start/save/evaluate/retry paths; no attempt identifier appears in the URL
- `/th/sign-in`, `/en/sign-in`, `/th/sign-up` and `/en/sign-up` expose dedicated Clerk Development email-code routes and an explicit unavailable state when ignored Development keys are absent
- `/th/onboarding`, `/en/onboarding`, `/th/profile` and `/en/profile` are dynamic protected routes for controlled profile and service-data consent
- unsupported locale segments return not found

The public narrative now provides:

- Thai-first optimistic-realism hero copy with an honest locale-matched CTA to the prototype and no landing-page collection
- exactly two localized evidence items from the ILO–NASK occupational-exposure study and the World Economic Forum Future of Jobs Report 2025
- visible source, date, geography, method/context, limitation and review metadata for every evidence item
- the complete Diagnose → Prioritize → Learn → Practice → Prove → Opportunity loop
- a compact preview that keeps the eight core competencies distinct from the two behavioural multipliers
- no scoring, personalized risk, waitlist form, pricing, account creation or external runtime fetch

The repository also contains the accepted RP-TURN-006 versioned synthetic assessment-domain contract. RP-TURN-007 reads its reviewed item wording through a client-safe presentation adapter while keeping the scoring contract out of the interactive client boundary. The domain contract provides:

- exactly six synthetic bilingual scenario-choice items: two Critical Thinking & Fact-Checking, two Systematic Thinking, one Ownership Thinking and one Sense of Urgency
- all eight canonical core identities and exact weights, with both behavioural multipliers structurally separate and unweighted
- pure deterministic integer-rubric scoring with earned/available points, evidence counts and traceable item keys
- two synthetic raw-response fixtures kept separate from expected scores and expected explanations
- explicit provisional limitations, six unassessed core competencies and no overall score, proficiency stage, priority recommendation or employment implication
- no profile, server assessment session, durable persistence or dependency addition

The RP-TURN-007 player presents exactly those six accepted items one at a time with native radio groups, accessible progress and validation, Back/Continue controls and an explicit no-result completion state. A server-side adapter sends the interactive Client Component only localized prompts, item identity/order and option IDs/labels; scoring and explanation internals stay out of the client boundary.

For same-tab refresh recovery only, the player may store a versioned allowlisted payload in `sessionStorage`: the assessment version, player phase/current item and selected item/option IDs. Selected IDs are sensitive assessment data even though they remain local and temporary. The payload contains no copy, rubric, score, timestamp, profile field or free text; malformed or incompatible state is cleared, blocked storage does not crash the flow, and the user can clear state explicitly. Nothing is sent to an API or persisted on a server.

The authenticated `/assessment/attempt` path is a separate RP-TURN-012 synthetic-alpha flow. It never reads, imports or changes that same-tab payload. An explicit start anchors one internal owner, the current `alpha-privacy-v1` service-data grant and the exact published six-item assessment version in PostgreSQL. Each save sends only locale, accepted item/option IDs, expected revision and a client mutation UUID to a same-origin Server Action; the browser receives no user/session/row UUID, consent receipt, database version ID, provider subject, rubric, target, weight or scoring configuration. Refresh loads the owner state from PostgreSQL, and submission locks the complete six-response set while displaying only a bilingual no-result receipt.

The RP-TURN-008 example-result route remains a separate server-rendered demonstration using reviewed fixture `synthetic-mixed-review`; it never reads or scores the temporary player payload. It displays only raw `1/4` and `3/4` evidence signals for the two covered core competencies, lists all six unassessed cores, and keeps Ownership Thinking and Sense of Urgency as separate one-scenario observations. It has no overall or weighted score, percentage proficiency, stage, confidence percentage, employment inference, readiness/risk/personality inference or personalized priority recommendation.

The page includes one fixed example practice for Critical Thinking & Fact-Checking. Its trace records scoring model `scoring-integer-rubric-fixture-v1@1.0.0`, item keys `verify-ai-summary-source` and `test-process-assumption`, and exact prototype lesson version `lesson-source-verification-practice-v1@1.0.0`. Its locale-matched link says the result remains fixed and synthetic, the lesson is a prototype and the link is not a personalized recommendation.

RP-TURN-009 implements that one lesson through a typed, schema-validated, Git-versioned local content contract. Accepted RP-TURN-014 migrates it to trusted MDX plus metadata/practice/rubric/proof/source JSON under `content/lessons/source-verification-practice/1.0.0/` and publishes immutable identity `source-verification-practice@1.0.0` through an independently Git-reviewed publication seal plus tracked `publication-manifest.json` and `published-lessons.json`. Evidence dates are calendar-exact and require `publicationDate <= lastVerifiedDate < reviewExpiryDate`; evidence expires at or after its review-expiry instant. Operational status is `published` for synthetic alpha while efficacy remains `prototype-unvalidated`. The Thai/English routes share exact lesson, framework, competency, `Practicing` stage, `Intelligent Risk & Governance`, practice, rubric and proof identities. The entirely synthetic Bright River Operations case moves from source-verification concepts to a three-part structured decision and visible binary rubric. All three criteria are required for a demonstrated in-memory outcome and a 20 XP preview; incomplete or below-threshold work previews 0 XP, and retry replaces rather than accumulates. No XP is saved.

Practice selections and feedback exist only in React memory and reset on refresh. The route uses no browser storage, cookie, answer-bearing URL, API, server action, analytics, log or network transmission. The future source-verification note is a placeholder only: there is no free-text field, upload, file generation, proof storage or collected reflection. MDX is parsed into a controlled JSON render plan and is never evaluated as JavaScript. Build and aggregate checks run the read-only publication validator and fail on stale or invalid artifacts without rewriting the worktree.

## Database and synthetic-alpha account boundary

RP-TURN-010 defines nine PostgreSQL tables through Drizzle schema metadata and one reviewed forward SQL migration: user accounts, external identities, append-only consent records, framework versions, competency versions, scoring-model versions used for referential integrity, assessment versions, assessment-item versions and item-to-competency mappings.

The migration uses internal UUIDs, unique provider/subject and versioned business keys, validated versioned JSON objects, restrictive foreign keys, exact sealed 8+2 framework metadata and 10,000 core basis points, null multiplier weights and `timestamptz` timestamps. Definition rows start as drafts, publish only after database validation, retire through a status-only transition and remain immutable once published or retired. Deterministically ordered parent-row locks prevent reparent and publication races. Forced RLS protects all three user-owned tables. The normal `rise_pals_app` role owns no table and is `NOSUPERUSER`, `NOCREATEDB`, `NOCREATEROLE`, `NOINHERIT` and `NOBYPASSRLS`; it sees an owner only through a validated server-set transaction-local UUID.

RP-TURN-011 adds a second forward migration and a tenth table, `user_profiles`. Profile fields are controlled `profile-v1` codes only: locale, one of three timezones, broad role family, broad function, broad experience band and one to three goal codes. Goals are treated as sensitive career data. Employer name, exact title, salary, national identifier and free-text career concerns remain prohibited. Forced RLS now covers all four user-owned tables.

RP-TURN-012 adds exactly one third forward migration and only `assessment_sessions` and `assessment_responses`, bringing the disposable schema to 12 tables. Sessions use internal owner UUIDs, exact published assessment/version references, the granted consent receipt used at start, database-owned timestamps, a validated item-version resume marker and only `in_progress → submitted`. Responses use an exact `{schemaVersion, selectedOptionId}` JSON payload plus monotonic revision, explicit supersession, client-mutation idempotency and one-active-revision constraints. Both tables use ENABLE/FORCE RLS; application DELETE is absent, submitted history is immutable and scoring/results remain absent.

RP-TURN-013 adds one fourth forward migration and exactly five derived tables, bringing the disposable schema to 17 tables: `scoring_runs`, `competency_scores`, `multiplier_observations`, `score_explanations` and `priority_recommendations`. The immutable `persisted-synthetic-priority-v1@1.0.0` policy pins canonical JSON and digest `10f2ab076828d50b228ff53d57332527dfe9d1b2769c4b57bd0476dd3c263157`. Server-only derivation canonicalizes exact content identities/digests and response item/revision/option evidence, excludes owner/session/time/locale from semantics, and records reproducible input/output SHA-256 digests. Normal replay/concurrency converges on one run; only an explicit server-only operation creates an immutable next rescore run.

RP-TURN-015 adds one fifth forward migration and exactly three tables, bringing the disposable schema to 20 tables: `lesson_attempts`, `practice_attempts` and `learning_progress_events`. The model anchors exact accepted lesson/practice/rubric/evaluation identities and current consent, keeps response/evaluation history append-only, uses only meaningful start/evaluated/demonstrated events and forces owner RLS. Each practice revision persists normalized mutation intent, locale and expected revision; only an exact UUID replay returns the original revision, while changed provenance or selections conflicts without another row, event or lesson transition. A non-demonstrated evaluation can be followed only by an explicit payload-preserving retry draft; direct save/evaluate is denied by both DAL and PostgreSQL until that draft exists, after which save/evaluate is allowed. Evaluation remains the accepted deterministic rubric; no XP, proof, page-view analytics or assessment/scoring data is stored or coupled to lesson availability.

RP-TURN-016 adds one sixth forward migration and exactly three tables, bringing the disposable schema to 23 tables: `evidence_artifacts`, `evidence_artifact_revisions` and `evidence_competency_links`. One exact demonstrated source-verification practice plus current consent can explicitly start a private draft. Saves append controlled immutable revisions; an exact historical replay validates its original mutation row but returns the locked artifact's latest revision, payload, feedback and truthful draft/ready/withdrawn lifecycle without writing, while conflicting or cross-intent UUID reuse appends nothing and changes no lifecycle timestamp. Only the exact canonical five-part structure can become read-only `ready`; draft or ready may become permanently read-only `withdrawn`. The authenticated Client Component receives only controlled localized copy/options, public synthetic IDs, selections, revision, lifecycle and feedback—not the contract/proof/source-pack object or internal identity. The artifact uses only the fictional Bright River case, remains private to one owner, links only to Critical Thinking & Fact-Checking for traceability, and provides no free text, file/upload, sharing/export, XP, score, proficiency, recommendation or employment signal.

RP-TURN-017 adds one seventh forward migration and exactly three tables, bringing the disposable schema to 26 tables: `measurement_subjects`, `product_events` and `error_occurrences`. A separate `measurement-monitoring` grant creates a pseudonymous subject tied to that exact current receipt; withdrawal stops capture and re-grant rotates the subject. Server-only provider-neutral adapters accept only two event classes, four surfaces and controlled operation/error codes. An activation is the first successful explicit persisted action; a meaningful return requires another successful action on a later UTC date. Exact replay, denial, conflict, validation failure and passive reads do not create success events. Error rows accept only controlled redacted fields. Capture failure is non-authoritative and cannot change domain results, lifecycle timestamps or access. No external SDK/request, page/click tracking, browser identifier, cookie, storage, beacon, pixel or staff dashboard was introduced.

The protected `/th/assessment/result` and `/en/assessment/result` routes never score on GET. After an explicit action, they display earned/available fractions for exactly two assessed cores, all six unassessed cores, and two separate one-scenario multiplier observations. A unique lowest assessed-core ratio, compared by integer cross multiplication without weights/profile/multipliers, yields at most one provisional next-practice priority; a tie yields none. Critical Thinking links only to the existing prototype lesson, while Systematic Thinking reports that a matching practice is unavailable. Raw responses, selected options, database IDs, digests, policy internals and RLS context remain server-only.

Clerk is behind an internal `IdentityProvider` boundary and is selected only for a Jeff-controlled Development application on Free/Hobby with email verification code. Development keys must remain in ignored local configuration and live keys fail closed. Dedicated same-locale sign-in/sign-up routes cross-link through explicit Clerk props; mismatched-locale, encoded, external, query and fragment return targets fall back to the current locale root. The server validates the Clerk session, resolves its subject to an internal UUID through a hardened concurrency-safe PostgreSQL function, checks the internal account state and only then establishes `app.current_user_id`. The function is owned by a credentialless `NOLOGIN`/`NOBYPASSRLS` resolver role that the application and migration owner cannot assume after the bounded bootstrap step; neither normal role can enumerate provider identities without trusted user context. Clerk metadata does not hold profile, consent, goals, application roles or assessment data, and provider subjects are not client DTO fields.

The bilingual `alpha-privacy-v1` notice covers only service profile and future learning-state processing, not marketing, analytics or research. Grant, decline and withdrawal append deterministic receipts; history is never overwritten. Declining cannot create/update a profile, and withdrawal is not account deletion.

The independent bilingual `alpha-measurement-monitoring-v1` notice uses `measurement-consent-contract-v1`, is never preselected and covers only the exact allowlisted first-party product-event and redacted-error fields. Grant, decline and withdrawal append receipts without changing service-data consent or product access. This is a synthetic-alpha implementation pending Project Codex review, not production legal approval, external provider selection or an accepted retention/export/erasure policy.

This remains a synthetic, non-production implementation. Clerk Development authentication, internal identity/profile authorization and versioned consent are accepted only for synthetic alpha, and Clerk identity hosting in the United States is accepted only for that testing boundary. On 2026-08-16, the final bounded RP-TURN-012 smoke used one new synthetic identity and verified Thai email-code sign-up/onboarding, one stable internal mapping, current consent/profile persistence, persisted start, response correction, refresh resume, complete atomic/idempotent submission, immutable receipt reload, profile logout denial, same-identity re-authentication, safe return handling and final browser/database privacy boundaries. The identity was deleted and verified absent; the isolated build and disposable database/process/data/logs/credentials were removed. Ignored local Development keys remain configured for Jeff-authorized development use. Production provider suitability, legal/privacy/data-residency review, retention/export/erasure, production PostgreSQL, credentials, backups and operations remain open. RP-TURN-013 persists only bounded synthetic-alpha derived evidence; no validated assessment/proficiency result, real learner recommendation, lesson progress, XP or proof is persisted.

Verified prerequisites for this branch:

- Node.js `24.18.1` LTS x64
- npm `11.16.0`

Install from the committed lockfile and run the local application:

```powershell
npm ci
npm run dev
```

Run individual quality gates or the aggregate gate:

```powershell
npm run format:check
npm run content:validate
npm run content:publish
npm run lint
npm run typecheck
npm run test
npm run build
npm run check
npm run test:e2e:install
npm run db:prepare:disposable
npm run test:e2e
npm run db:test:disposable
npm run test:auth:clerk:development
```

`npm run content:validate` is read-only; `npm run content:publish` atomically regenerates tracked deterministic outputs only after the entire source bundle passes. The pipeline uses exact-pinned build-only `unified`, `remark-parse` and `remark-mdx` packages to parse an AST, never a runtime MDX evaluator. `npm run test:e2e:install` installs only the pinned Playwright Chromium browser. `npm run build`, `npm run check` and `npm run test:e2e` explicitly blank Clerk configuration in their child processes, so ignored Development keys cannot activate Clerk during standard gates. Run the build before E2E; Playwright serves that secret-free production output through an independently secret-free start command and blocks every browser origin except `http://127.0.0.1:3104`. The suite verifies locale routing, document language, evidence behavior, player/lesson/result privacy, 320px reflow, reduced motion and serious/critical axe findings. `npm run test:auth:clerk:development` is the only opt-in external path: it requires ignored Development keys, builds into a separate ignored directory, creates only a disposable PostgreSQL cluster and unique Clerk synthetic identity, and must verify provider-identity deletion plus local build/database cleanup before succeeding.

Copy `.env.example` to an ignored local environment file only when local configuration is needed. `APP_BASE_URL` is optional and accepts only a normalized HTTP(S) origin without credentials, a non-root path, query or fragment. Normal application runtime requires only `DATABASE_URL`; never place `DATABASE_MIGRATION_URL` or a table-owner credential in the production application environment. Migration/test tooling intentionally receives both URLs and verifies decoded role separation. The application identity must be a non-owner role without `BYPASSRLS`. The committed values are inert examples only. Never commit a real `.env` file or secret.

The exact install, verification results and Windows notes are recorded in [Local Development](docs/10_LOCAL_DEVELOPMENT.md).

## วิธีทำงานของโปรเจกต์

โปรเจกต์นี้ใช้ Codex สองบริบทที่มีหน้าที่ต่างกัน:

- **Project Codex:** ช่วย Jeff คิด product strategy, แตกงาน, review, comment, audit และออกคำสั่งสำหรับ turn ถัดไป
- **VS Code Codex:** ลงมือแก้ repository ตาม brief ทีละ turn พร้อมทดสอบและส่ง handoff กลับมา

ทุก turn ต้องจบด้วย handoff ที่ตรวจสอบได้ จากนั้น Project Codex จะอ่านไฟล์และ diff จริงก่อนออก brief รอบถัดไป รายละเอียดอยู่ใน [Codex Collaboration Workflow](docs/06_CODEX_COLLABORATION_WORKFLOW.md)

## Current boundary

RP-TURN-006 through RP-TURN-016 are Accepted for their documented synthetic/prototype boundaries. RP-TURN-017 is complete pending Project Codex review for only its optional first-party local synthetic-alpha boundary. The public player and public lesson preserve their temporary/memory-only contracts, including the non-collecting proof placeholder. The separate private artifact is owner/current-consent scoped, controlled synthetic P3 state and `prototype-unvalidated`; it is not a validated result, credential or externally verifiable proof. No real user/data, external analytics/monitoring provider, production identity/database resource, retention/export/erasure operation, upload/object storage/share grant, saved XP, payment, CI, VPS service or deployment exists. RP-TURN-018 is not authorized or started.
