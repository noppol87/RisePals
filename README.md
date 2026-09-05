# Rise Pals

Rise Pals คือแพลตฟอร์มพัฒนาความพร้อมในการทำงานยุค AI สำหรับคนทำงานออฟฟิศไทย ช่วยให้ผู้ใช้รู้ว่าตนเองมีช่องว่างด้านทักษะอะไร ควรพัฒนาอะไรก่อน เรียนผ่านประสบการณ์แบบ gamified และสร้างหลักฐานความสามารถที่ต่อยอดไปสู่โอกาสทางอาชีพได้

**Brand:** Rise Pals  
**Digital wordmark:** `risepals`  
**Primary domain:** `risepals.com`  
**Project status:** RP-TURN-019 repository-only recovery/launcher stabilization has passed its technical gates under Jeff's direct VS Code Codex workflow; RP-TURN-019 remains Partial because real candidate lifecycle/graceful-stop verification is still outstanding. The candidate remains unsigned and not production-approved; PR #17 stays Draft/unmerged and RP-TURN-020 remains unauthorized  
**Last updated:** 2026-09-05

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

RP-TURN-003 established one minimal Next.js App Router application at the repository root. RP-TURN-004 established a Thai-first localized shell. RP-TURN-005 through RP-TURN-014 established the bounded public narrative, synthetic assessment/player/result, lesson prototype, database/authentication/persistence boundaries and trusted content publication. RP-TURN-015 adds a separate authenticated synthetic-alpha lesson/practice/progress path with explicit server writes. RP-TURN-016 adds a separate private controlled source-verification note after demonstrated practice. RP-TURN-017 adds an optional first-party consent-aware measurement/error foundation without external telemetry. RP-TURN-018 adds Accepted non-production owner-export, operator-erasure and disposable-recovery evidence plus a threat model, support runbook and multi-viewport accessibility regression. These turns do not create a real account, production resource, validated learning outcome, credential, shareable proof or production launch.

RP-TURN-019 separately evaluates the non-public Windows host boundary with Next.js standalone on pinned Node 24.18.1 and standard Caddy 2.11.4. Project Codex Accepted the live recovery and exact residue cleanup: both services are Stopped/Disabled at PID 0; original stalled processes, relevant listeners, enabled firewall rules, drain state, canary and raw captures are absent; capture contents were not read; and no reboot or public mutation occurred. Forced termination was recovery, not graceful-stop success. Direct service stop stalled, so the current WinSW 2.12.0 supervision design is rejected pending a new decision and must not be rehearsed again.

The [Windows Service Supervision Decision Pack](docs/14_WINDOWS_SERVICE_SUPERVISION_DECISION.md) records D-027's selection of Option B for a repository-only prototype. The [prototype](infra/windows-service-host/README.md) is a minimal self-contained .NET 10 LTS Windows host with one isolated candidate SCM identity, native Stop/Preshutdown states, bounded checkpoints, an ACL-restricted private named pipe, transactional suspended-before-Job-assignment Node startup, proven whole-tree cleanup, finite restart and typed allowlisted evidence that never persists raw Node output. Its accepted R3-R1 evidence includes 51 .NET tests and repeated byte-identical single-file publication. It is intentionally NotSigned and has not been installed or run as a service.

RP-TURN-019-R4-R1 adds only a repository-owned candidate rehearsal harness. It pins the accepted unsigned host, schema and dependency manifest; the exact signed Node v24.18.1 executable; and both retained service definitions including exact command, account, Own Process type, executable length/SHA-256 and Stopped/Disabled/PID 0 state. It derives the exact virtual-service-account SID, defines nonce-scoped staging/config/log paths and three-principal ACLs, validates fresh digest-bound single-use structured results and encodes 23 fail-closed future rehearsal/cleanup stages. Non-reboot Preshutdown proof is now limited to a read-only exact-timeout/accepted-controls registration query plus accepted repository tests; delivery by Windows remains pending a separately authorized controlled reboot. Retained-proxy independence is snapshot-based: `RisePalsProxy` stays Stopped/Disabled/PID 0 and is never enabled, started or restarted, while candidate probes use direct loopback with no proxy dependency. Its deterministic plan/tests are non-elevated and read-only with respect to services and `C:\RisePals`. The future live path is gated by a separate exact-head authorization and was not invoked. No UAC, service, listener, filesystem, firewall, DNS, certificate, reboot or deployment mutation is authorized by R4-R1. Option D and RP-TURN-020 remain unauthorized. See also the [Windows VPS Infrastructure Readiness Runbook](docs/13_WINDOWS_VPS_READINESS_RUNBOOK.md).

R4-R3 replaces the build-context-sensitive executable pin with explicit service-host-only version metadata: `0.1.0-rp19-prototype`, assembly/file version `0.1.0.0` and source-revision suffixing disabled. Three clean publishes—one Git-aware and two file-only at different paths and timestamps—are byte-identical at 73,606,961 bytes and SHA-256 `d86c4e4afcc8c1f6d8e77694b5de163185326c460fea1be50e5533d29aca0e8c`; artifact identity records post-policy production source tree `125eb5a7765c58cbc7cee094fbe82207642fd2a5` and excludes volatile outer-repository commit metadata. LIVE2 stopped before UAC; no live/elevated or host mutation occurred.

R4-DIAG1-R2 closes the cleanup-truth and process-exit review gaps without changing the service-host behavior or claiming an unknowable historical LIVE3 root cause. The parent first atomically writes, reopens and validates an authenticated pre-cleanup checkpoint. It then attempts exact transient cleanup and writes a separate schema-v3 authoritative result containing the checkpoint filename/digest, validated launch/marker/final state, cleanup attempted/completed state, invocation absence and sanitized residue counts/paths. Overall success requires a valid successful child result, both durable records and zero remaining transient objects. A clean-head suite invokes the committed parent in ten hidden Windows PowerShell 5.1 processes, waits for exit and independently validates the records without parsing stdout. The bootstrap still owns only `bootstrap-started` and `child-launch-attempted`; the child owns `child-started` and `live-started`. No UAC or Live mode was used; another attempt requires separate exact-head authorization.

LIVE4B later ran exactly once and failed. Its two durable records prove cleanup completed, the transient invocation was absent, residue was zero and the host ended safe; they do not reveal a reliable internal failed stage or individual functional-gate result. DIAG2 therefore adds a future-only, digest-authenticated allowlist of child status, controlled failure stage/code, ordered stages, fixed gate dispositions and four lifecycle booleans to both durable records before transient cleanup. The two records must carry the identical diagnostic digest, and success remains impossible unless every mandatory Live gate passed and cleanup reached zero residue. This does not reconstruct LIVE4B or authorize another UAC/Live run, reboot or deployment.

LIVE5 later stopped before elevated process creation: `processLaunched` was false and no bootstrap, child, Live gate or host mutation occurred. DIAG2 proves complete cleanup and a safe zero-residue final state, but the exact launcher failure remains unknown. DIAG3 adds future-only closed launch evidence to both durable records: controlled disposition/failure code, bounded numeric native/HResult/depth evidence, fixed approved launcher basename/existence/signature/verb, and only the argument count plus canonical digest. Missing, extra, inconsistent, tampered or checkpoint/result-mismatched fields fail closed. DIAG3 does not inspect old captures, infer LIVE5's cause or authorize another UAC/Live attempt.

R4-DIAG4 adds a future-only `ElevationProbe` mode. It uses the same canonical committed PowerShell `RunAs` launch builder as Live but selects a dedicated child that cannot invoke the Live sequence or service, `C:\RisePals`, Node, firewall, certificate or reboot operations. Its closed digest-authenticated result records only provenance/elevation booleans and a closed integrity level; all Live gates remain `not_applicable` and all Live lifecycle flags remain false. DIAG4 did not request UAC or execute the probe. A separately authorized passing probe would establish only the elevation transport boundary, not service supervision or graceful shutdown. RP-TURN-019 therefore remains Partial.

NODE1/DIAG1 also remains Partial: its temporary path validator failed before protected inspection, and initialized zero/false values in that failed record are not evidence about the destination. NODE-DIAG2-R1 prepares a future-only read-only PowerShell 5.1 diagnostic that explicitly probes `C:\RisePals`, `tools`, `node`, `24.18.1` and `node.exe` in order with `Get-Item`/`Get-Acl` error semantics. R2 pins `Microsoft.PowerShell.Security` to the exact Windows PowerShell 5.1 `$PSHOME` manifest, validates the manifest boundary and loaded module/`Get-Acl` provenance and ignores ambient `PSModulePath` ordering without changing it. R3 imports that validated literal manifest into process-global scope so `Get-Acl` remains available after the initializer returns. A real incompatible PowerShell-7-first fixture passes explicit post-return provenance and execution checks, the 45 boundary simulations and candidate rehearsal harness; five separate synthetic failures prove missing, reparse, outside-home and mismatching module/command paths fail closed with sanitized evidence and removed captures. The real `C:\RisePals\tools\node\24.18.1` state remains unknown; this repository turn used no UAC, LiveReadOnly execution, protected inspection, Node restoration or Live rehearsal.

NODE-DIAG4 adds a separate future-only durable transport for failures that happen before that schema-v2 measurement exists. A fresh atomic request binds authorization, nonce, repository head and exact launcher/bootstrap/child/diagnostic/inventory hashes before launch. The child writes authenticated hash-chained markers from bootstrap entry through schema-v2 persistence, while the parent treats process exit and durable evidence separately, independently reopens every durable request/checkpoint/result, and removes transient markers only after reopening the checkpoint. Sixteen isolated Windows PowerShell 5.1 scenarios fail closed for launch, bootstrap, import, binding, pre-dispatch, nonzero exit, malformed/bound/replayed/digest-mismatched evidence, interrupted writes, cleanup and final persistence. It stores no raw streams, exception details, arguments, environment values, secrets or ACL contents and does not change the existing schema-v2 contract. This does not reconstruct NODE-DIAG3, establish destination facts without valid schema-v2 evidence or authorize UAC/LiveReadOnly.

NODE-DIAG5 later stopped before DIAG4 request persistence and therefore established no protected-destination fact; its exact historical cause is not inferred. NODE-DIAG6 adds a future-only durable raw-argument parent entry before that boundary. It persists the earliest marker before outer-contract import, validates exact mode/repository/evidence/inventory/committed-artifact bindings and creates/reopens the unchanged DIAG4 request. Its `PreflightOnly` path stops before inner transport dispatch, `RunAs`, UAC, elevated-child creation and protected inspection. Forty-one isolated Windows PowerShell 5.1 simulations cover the ordered 13-stage/16-category contract, every committed-artifact hash, failure/tamper/stale/partial/replay/cleanup boundaries and prove zero UAC/elevated children. RP-TURN-019 remains Partial and another host attempt requires separate authorization.

LIVE7 later stopped fail-closed before UAC when the fresh Phase A service-host suite timed out waiting for the synthetic fixture's private-pipe `Ready` message and passed 50/51 tests. R4-R4-R1 keeps the three-second deadline and production drain transport unchanged. Its test-only reader requires every exact property once, binds filenames to sequence and rejects unknown, duplicate, missing, mistyped, negative-elapsed, malformed, stale, replayed, wrong-nonce, non-atomic and path/reparse-unsafe evidence. A bounded observation window distinguishes incomplete publication from invalid evidence while retaining the original timeout, exit or protocol classification; setup observation has its own bound. Cleanup accepts only the flat exact diagnostic layout and refuses unexpected directories or reparse objects. The diagnostics suite passes 26/26, the focused fixture/pipe/drain suite passes 38/38, the affected stream/drain test passes 10/10 separate processes and the expanded 77-test service-host suite passes three consecutive runs. This repository evidence does not authorize another UAC or Live attempt.

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

RP-TURN-017 adds one seventh forward migration and exactly three tables, bringing the disposable schema to 26 tables: `measurement_subjects`, `product_events` and `error_occurrences`. A separate `measurement-monitoring` grant creates a pseudonymous subject tied to that exact current receipt; withdrawal stops capture and re-grant rotates the subject. Server-only provider-neutral adapters accept only a prevalidated five-field candidate with a context-bound SHA-256 action digest, two event classes, four surfaces and controlled operation/error codes; raw mutation UUIDs never cross that adapter boundary. An activation is the first newly applied explicit persisted action; a meaningful return requires another newly applied action on a later UTC date. Exact replay—including replay after a consent grant or subject rotation—denial, conflict, validation failure and passive reads do not create success events. Owner-bound digest uniqueness preserves replay provenance across rotated subjects. Unexpected action failures return a fixed controlled result without reporting or rethrowing the original error message, stack or cause. Capture/reporter failure is non-authoritative and cannot change domain results, lifecycle timestamps or access. No external SDK/request, page/click tracking, browser identifier, cookie, storage, beacon, pixel or staff dashboard was introduced.

The protected `/th/assessment/result` and `/en/assessment/result` routes never score on GET. After an explicit action, they display earned/available fractions for exactly two assessed cores, all six unassessed cores, and two separate one-scenario multiplier observations. A unique lowest assessed-core ratio, compared by integer cross multiplication without weights/profile/multipliers, yields at most one provisional next-practice priority; a tie yields none. Critical Thinking links only to the existing prototype lesson, while Systematic Thinking reports that a matching practice is unavailable. Raw responses, selected options, database IDs, digests, policy internals and RLS context remain server-only.

Clerk is behind an internal `IdentityProvider` boundary and is selected only for a Jeff-controlled Development application on Free/Hobby with email verification code. Development keys must remain in ignored local configuration and live keys fail closed. Dedicated same-locale sign-in/sign-up routes cross-link through explicit Clerk props; mismatched-locale, encoded, external, query and fragment return targets fall back to the current locale root. The server validates the Clerk session, resolves its subject to an internal UUID through a hardened concurrency-safe PostgreSQL function, checks the internal account state and only then establishes `app.current_user_id`. The function is owned by a credentialless `NOLOGIN`/`NOBYPASSRLS` resolver role that the application and migration owner cannot assume after the bounded bootstrap step; neither normal role can enumerate provider identities without trusted user context. Clerk metadata does not hold profile, consent, goals, application roles or assessment data, and provider subjects are not client DTO fields.

The bilingual `alpha-privacy-v1` notice covers only service profile and future learning-state processing, not marketing, analytics or research. Grant, decline and withdrawal append deterministic receipts; history is never overwritten. Declining cannot create/update a profile, and withdrawal is not account deletion.

The independent bilingual `alpha-measurement-monitoring-v1` notice uses `measurement-consent-contract-v1`, is never preselected and covers only the exact allowlisted first-party product-event and redacted-error fields. Grant, decline and withdrawal append receipts without changing service-data consent or product access. Project Codex Accepted this only for the bounded synthetic-alpha implementation at reviewed head `4d6fb73e33202379401b5a72763e27a71fdecda2`; it is not production legal approval, external provider selection or an accepted retention/export/erasure policy.

This remains a synthetic, non-production implementation. Clerk Development authentication, internal identity/profile authorization and versioned consent are accepted only for synthetic alpha, and Clerk identity hosting in the United States is accepted only for that testing boundary. On 2026-08-16, the final bounded RP-TURN-012 smoke used one new synthetic identity and verified Thai email-code sign-up/onboarding, one stable internal mapping, current consent/profile persistence, persisted start, response correction, refresh resume, complete atomic/idempotent submission, immutable receipt reload, profile logout denial, same-identity re-authentication, safe return handling and final browser/database privacy boundaries. The identity was deleted and verified absent; the isolated build and disposable database/process/data/logs/credentials were removed. Ignored local Development keys remain configured for Jeff-authorized development use. Production provider suitability, legal/privacy/data-residency review, retention/export/erasure operations, production PostgreSQL, credentials, backups and operations remain open. RP-TURN-013 persists only bounded synthetic-alpha derived evidence; no validated assessment/proficiency result, real learner recommendation, lesson progress, XP or proof is persisted.

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
npm run test:e2e:alpha
npm run db:test:disposable
npm run db:test:recovery
npm run test:auth:clerk:development
```

`npm run content:validate` is read-only; `npm run content:publish` atomically regenerates tracked deterministic outputs only after the entire source bundle passes. The pipeline uses exact-pinned build-only `unified`, `remark-parse` and `remark-mdx` packages to parse an AST, never a runtime MDX evaluator. `npm run test:e2e:install` installs only the pinned Playwright Chromium browser. `npm run build`, `npm run check` and `npm run test:e2e` explicitly blank Clerk configuration in their child processes, so ignored Development keys cannot activate Clerk during standard gates. Run the build before E2E; Playwright serves that secret-free production output through an independently secret-free start command and blocks every browser origin except `http://127.0.0.1:3104`. The suite verifies locale routing, document language, evidence behavior, player/lesson/result privacy, 320px reflow, reduced motion and serious/critical axe findings. `npm run test:auth:clerk:development` is the only opt-in external path: it requires ignored Development keys, builds into a separate ignored directory, creates only a disposable PostgreSQL cluster and unique Clerk synthetic identity, and must verify provider-identity deletion plus local build/database cleanup before succeeding.

`npm run test:e2e:alpha` exercises the bounded Thai/English critical-surface regression in desktop Chromium, a 320 CSS-pixel viewport and reduced-motion mode. `npm run db:test:recovery` uses only the pinned disposable PostgreSQL toolchain to prove fresh and seven-to-eight migrations, temporary backup/restore, deterministic export, erasure replay and invalid-restore cleanup. Neither command contacts Clerk or creates a durable/production resource.

Copy `.env.example` to an ignored local environment file only when local configuration is needed. `APP_BASE_URL` is optional and accepts only a normalized HTTP(S) origin without credentials, a non-root path, query or fragment. Normal application runtime requires only `DATABASE_URL`; never place `DATABASE_MIGRATION_URL` or a table-owner credential in the production application environment. Migration/test tooling intentionally receives both URLs and verifies decoded role separation. The application identity must be a non-owner role without `BYPASSRLS`. The committed values are inert examples only. Never commit a real `.env` file or secret.

The exact install, verification results and Windows notes are recorded in [Local Development](docs/10_LOCAL_DEVELOPMENT.md).

## วิธีทำงานของโปรเจกต์

Jeff directs work and accepts outcomes directly in VS Code Codex. Codex plans bounded changes, implements them, inspects the diff and runs relevant tests here. A separate Project Codex review and cross-context copy blocks are no longer required. Historical acceptance records remain historical evidence, not a claim of new independent review.

Reports identify completed work, actual verification, remaining blockers and the next action. Host/service changes, real-user data, external costs and deployment still require explicit Jeff authorization. Details are in [Codex Collaboration Workflow](docs/06_CODEX_COLLABORATION_WORKFLOW.md).

## Current boundary

RP-TURN-006 through RP-TURN-018 are Accepted for their documented synthetic/prototype boundaries. RP-TURN-018 acceptance is limited to its non-production dry-run/server-only export and erasure contracts, fake identity-provider adapter and disposable database backup/restore evidence at reviewed head `5b21b56e2e268d794fcc8fd4b55d79ecaaca9c80`; it does not authorize launch or real-user collection. The public player and public lesson preserve their temporary/memory-only contracts, including the non-collecting proof placeholder. The separate private artifact is owner/current-consent scoped, controlled synthetic P3 state and `prototype-unvalidated`; it is not a validated result, credential or externally verifiable proof. Production retention, deletion ledger, backup expiry, restore reconciliation, legal/privacy/provider suitability, RTO/RPO and staff/operator access remain open. No real user/data, external analytics/monitoring provider, production identity/database or backup resource, approved production export/erasure operation, upload/object storage/share grant, saved XP, payment, CI or public deployment exists. RP-TURN-019-R4-NODE-DIAG6 is a repository-only parent-entry/pre-request correction pending review; no install, UAC, protected inspection, restoration, additional host run, reboot or deployment is authorized. RP-TURN-020 remains unstarted and unauthorized.
