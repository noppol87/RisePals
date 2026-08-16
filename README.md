# Rise Pals

Rise Pals คือแพลตฟอร์มพัฒนาความพร้อมในการทำงานยุค AI สำหรับคนทำงานออฟฟิศไทย ช่วยให้ผู้ใช้รู้ว่าตนเองมีช่องว่างด้านทักษะอะไร ควรพัฒนาอะไรก่อน เรียนผ่านประสบการณ์แบบ gamified และสร้างหลักฐานความสามารถที่ต่อยอดไปสู่โอกาสทางอาชีพได้

**Brand:** Rise Pals  
**Digital wordmark:** `risepals`  
**Primary domain:** `risepals.com`  
**Project status:** RP-TURN-011 synthetic-alpha authentication/profile/consent implementation and real Clerk Development smoke pending review / no real users or production service  
**Last updated:** 2026-08-16

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

RP-TURN-003 established one minimal Next.js App Router application at the repository root. RP-TURN-004 established a Thai-first, server-rendered locale boundary, semantic responsive app shell, provisional semantic design tokens and the small accessible primitives required by that shell. RP-TURN-005 replaced the structural verification panel with a bounded public narrative. RP-TURN-007 adds a usability-only player for the accepted synthetic scenarios. RP-TURN-008 adds a fixed synthetic example-result page that is not the current user's result. RP-TURN-009 adds one repository-local lesson/practice prototype. RP-TURN-010 adds the accepted bounded database baseline. RP-TURN-011 adds a synthetic-alpha authentication, controlled-profile and service-data-consent implementation against one Jeff-controlled Clerk Development resource; it does not create a real account, production identity resource, production database, personalized result, published learning content or production launch.

Locale routes:

- `/` redirects to the Thai default at `/th`
- `/th` renders the Thai shell and catalog
- `/en` renders the prepared English shell and catalog
- `/th/assessment` and `/en/assessment` render the matching six-scenario player prototype
- `/th/assessment/example-result` and `/en/assessment/example-result` render the matching static synthetic example result
- `/th/lessons/source-verification-practice` and `/en/lessons/source-verification-practice` render the matching local lesson/practice prototype
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

The RP-TURN-008 result route is a separate server-rendered example using reviewed fixture `synthetic-mixed-review`; it never reads or scores that temporary player payload. It displays only raw `1/4` and `3/4` evidence signals for the two covered core competencies, lists all six unassessed cores, and keeps Ownership Thinking and Sense of Urgency as separate one-scenario observations. It has no overall or weighted score, percentage proficiency, stage, confidence percentage, employment inference, readiness/risk/personality inference or personalized priority recommendation.

The page includes one fixed example practice for Critical Thinking & Fact-Checking. Its trace records scoring model `scoring-integer-rubric-fixture-v1@1.0.0`, item keys `verify-ai-summary-source` and `test-process-assumption`, and exact prototype lesson version `lesson-source-verification-practice-v1@1.0.0`. Its locale-matched link says the result remains fixed and synthetic, the lesson is a prototype and the link is not a personalized recommendation.

RP-TURN-009 implements that one lesson through a typed, schema-validated, Git-versioned local content contract. The Thai/English routes share exact lesson, framework, competency, `Practicing` stage, `Intelligent Risk & Governance`, practice, rubric and proof identities. The entirely synthetic Bright River Operations case moves from source-verification concepts to a three-part structured decision and visible binary rubric. All three criteria are required for a demonstrated in-memory outcome and a 20 XP preview; incomplete or below-threshold work previews 0 XP, and retry replaces rather than accumulates. No XP is saved.

Practice selections and feedback exist only in React memory and reset on refresh. The route uses no browser storage, cookie, answer-bearing URL, API, server action, analytics, log or network transmission. The future source-verification note is a placeholder only: there is no free-text field, upload, file generation, proof storage or collected reflection. The production MDX compilation/publication pipeline remains deferred to RP-TURN-014.

## Database and synthetic-alpha account boundary

RP-TURN-010 defines nine PostgreSQL tables through Drizzle schema metadata and one reviewed forward SQL migration: user accounts, external identities, append-only consent records, framework versions, competency versions, scoring-model versions used for referential integrity, assessment versions, assessment-item versions and item-to-competency mappings.

The migration uses internal UUIDs, unique provider/subject and versioned business keys, validated versioned JSON objects, restrictive foreign keys, exact sealed 8+2 framework metadata and 10,000 core basis points, null multiplier weights and `timestamptz` timestamps. Definition rows start as drafts, publish only after database validation, retire through a status-only transition and remain immutable once published or retired. Deterministically ordered parent-row locks prevent reparent and publication races. Forced RLS protects all three user-owned tables. The normal `rise_pals_app` role owns no table and is `NOSUPERUSER`, `NOCREATEDB`, `NOCREATEROLE`, `NOINHERIT` and `NOBYPASSRLS`; it sees an owner only through a validated server-set transaction-local UUID.

RP-TURN-011 adds a second forward migration and a tenth table, `user_profiles`. Profile fields are controlled `profile-v1` codes only: locale, one of three timezones, broad role family, broad function, broad experience band and one to three goal codes. Goals are treated as sensitive career data. Employer name, exact title, salary, national identifier and free-text career concerns remain prohibited. Forced RLS now covers all four user-owned tables.

Clerk is behind an internal `IdentityProvider` boundary and is selected only for a Jeff-controlled Development application on Free/Hobby with email verification code. Development keys must remain in ignored local configuration and live keys fail closed. Dedicated same-locale sign-in/sign-up routes cross-link through explicit Clerk props; mismatched-locale, encoded, external, query and fragment return targets fall back to the current locale root. The server validates the Clerk session, resolves its subject to an internal UUID through a hardened concurrency-safe PostgreSQL function, checks the internal account state and only then establishes `app.current_user_id`. The function is owned by a credentialless `NOLOGIN`/`NOBYPASSRLS` resolver role that the application and migration owner cannot assume after the bounded bootstrap step; neither normal role can enumerate provider identities without trusted user context. Clerk metadata does not hold profile, consent, goals, application roles or assessment data, and provider subjects are not client DTO fields.

The bilingual `alpha-privacy-v1` notice covers only service profile and future learning-state processing, not marketing, analytics or research. Grant, decline and withdrawal append deterministic receipts; history is never overwritten. Declining cannot create/update a profile, and withdrawal is not account deletion.

This remains a synthetic, non-production implementation. Clerk identity hosting in the United States is accepted only for synthetic alpha testing. On 2026-08-16, one bounded real Development smoke created one synthetic test identity, proved localized email-code authentication and the internal account/profile/consent boundary, then deleted and rechecked that identity; no identifier is retained in Git or documentation. Ignored local Development keys remain configured for Jeff-authorized development use. Production provider suitability, legal/privacy/residency review, deletion orchestration, production PostgreSQL, credentials, backups and operations remain open. Assessment responses/results, lesson progress, XP and proof are still not persisted.

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

`npm run test:e2e:install` installs only the pinned Playwright Chromium browser. Run `npm run build` before `npm run test:e2e`; Playwright serves that production output with `next start`, so build-to-browser verification does not reuse or overwrite development output. The browser suite verifies locale routing, document language, evidence behavior, the locale-matched player CTA, keyboard completion, answer validation, Back/refresh/clear/language-switch state behavior, the static example result and its text-equivalent signal map, the memory-only lesson practice and deterministic feedback, 320px reflow, desktop layout, reduced motion, absence of answer data in storage/URLs/requests/logs/cookies, absence of unexpected third-party requests and serious/critical axe findings. `npm run test:auth:clerk:development` is an explicit opt-in external smoke: it requires ignored Development keys, creates only a disposable PostgreSQL cluster and unique Clerk synthetic identity, and must verify both provider-identity deletion and local cleanup before succeeding.

Copy `.env.example` to an ignored local environment file only when local configuration is needed. `APP_BASE_URL` is optional and accepts only a normalized HTTP(S) origin without credentials, a non-root path, query or fragment. Normal application runtime requires only `DATABASE_URL`; never place `DATABASE_MIGRATION_URL` or a table-owner credential in the production application environment. Migration/test tooling intentionally receives both URLs and verifies decoded role separation. The application identity must be a non-owner role without `BYPASSRLS`. The committed values are inert examples only. Never commit a real `.env` file or secret.

The exact install, verification results and Windows notes are recorded in [Local Development](docs/10_LOCAL_DEVELOPMENT.md).

## วิธีทำงานของโปรเจกต์

โปรเจกต์นี้ใช้ Codex สองบริบทที่มีหน้าที่ต่างกัน:

- **Project Codex:** ช่วย Jeff คิด product strategy, แตกงาน, review, comment, audit และออกคำสั่งสำหรับ turn ถัดไป
- **VS Code Codex:** ลงมือแก้ repository ตาม brief ทีละ turn พร้อมทดสอบและส่ง handoff กลับมา

ทุก turn ต้องจบด้วย handoff ที่ตรวจสอบได้ จากนั้น Project Codex จะอ่านไฟล์และ diff จริงก่อนออก brief รอบถัดไป รายละเอียดอยู่ใน [Codex Collaboration Workflow](docs/06_CODEX_COLLABORATION_WORKFLOW.md)

## Current boundary

RP-TURN-006 through RP-TURN-010 are Accepted. RP-TURN-011 is implemented and its bounded real Clerk Development smoke passed, but it remains Partial pending Project Codex review and disposition of one current high transitive dependency advisory. The player still produces no result; its selected item/option IDs may exist temporarily in same-tab `sessionStorage`, but the fixed result, lesson and new account/profile flows never read them. The synthetic smoke identity was deleted. No real user/data, production identity resource, published or externally validated lesson, production database, durable assessment/lesson session, saved XP, proof capture, payment, analytics, CI, VPS service or deployment exists. RP-TURN-012 is recommended next but is not authorized or started.
