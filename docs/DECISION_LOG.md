# Decision Log

บันทึกเฉพาะการตัดสินใจที่มีผลต่อทิศทางผลิตภัณฑ์หรือวิธีทำงาน ไม่ใช้แทน task tracker

## D-001 — Brand name

- **Date:** 2026-08-01
- **Status:** Accepted
- **Decision:** ใช้ชื่อ **Rise Pals** และ digital wordmark `risepals`
- **Reason:** สื่อถึงการเติบโตและการมี companion/community โดยไม่ผูกแบรนด์กับ AI tool หรือ course format ใดรูปแบบหนึ่ง

## D-002 — Primary domain

- **Date:** 2026-08-01
- **Status:** Accepted
- **Decision:** ใช้ `risepals.com` เป็น primary domain
- **Note:** Jeff จดโดเมนเรียบร้อยแล้ว

## D-003 — Initial audience

- **Date:** 2026-08-01
- **Status:** Accepted
- **Decision:** เริ่มจากคนทำงานออฟฟิศไทยที่กำลังเผชิญ skill obsolescence และความกังวลจาก AI
- **Consequence:** Product และ copy ต้อง Thai-first แต่ data model และ architecture ไม่ควรปิดทางสู่ตลาดอื่น

## D-004 — Core framework

- **Date:** 2026-08-01
- **Status:** Accepted
- **Decision:** ใช้ AI-Era High-Skilled Professional Strategy & Survival Framework version 2.0 และระบบ 8+2 เป็นแกน
- **Consequence:** Assessment, lessons, proof และ opportunity matching ต้อง trace กลับมาที่ competencies และ R.O.I. pillars ได้

## D-005 — Business model direction

- **Date:** 2026-08-01
- **Status:** Accepted as hypothesis
- **Decision:** Subscription รายเดือน/รายปี พร้อม privileges สำหรับ online และ onsite learning; เปิดรับ revenue model อื่นจากหลักฐานการใช้งาน

## D-006 — Image generation

- **Date:** 2026-08-01
- **Status:** Accepted
- **Decision:** ภาพ raster และ illustration ใหม่สำหรับ Rise Pals ใช้ GPT-Image-2
- **Consequence:** ต้องสร้าง art direction และ asset provenance workflow ก่อนผลิตภาพจำนวนมาก

## D-007 — Codex operating model

- **Date:** 2026-08-01
- **Status:** Accepted
- **Decision:** ทำงานแบบ turn-by-turn โดย VS Code Codex implement และ Project Codex review/audit ก่อนออกคำสั่ง turn ถัดไป
- **Consequence:** ทุก turn ต้องมี brief, verification และ handoff copy block

## D-008 — Evidence-based urgency

- **Date:** 2026-08-01
- **Status:** Accepted
- **Decision:** ใช้หลักฐานและตัวเลขสร้างความเร่งด่วน แต่ไม่ใช้ fabricated fear, misleading prediction หรือ dark pattern
- **Reason:** ความน่าเชื่อถือและ learner agency เป็นสินทรัพย์ระยะยาวของแบรนด์

## D-009 — Cross-context message protocol

- **Date:** 2026-08-01
- **Status:** Accepted by Jeff in RP-TURN-001
- **Decision:** ข้อความที่ copy ระหว่าง Codex contexts ต้องระบุ `SOURCE`, `DESTINATION` และ `MESSAGE TYPE`; completed-turn submission จาก VS Code Codex ต้องใช้ `MESSAGE TYPE: TURN HANDOFF` และ handoff template เท่านั้น
- **Consequence:** Status, orientation, advice และ explanation ไม่ถือเป็นหลักฐานว่า turn complete; final review copy block ต้องรักษา envelope และห้ามติดป้ายข้อความที่ Jeff เขียนว่าเป็น VS Code Codex

## D-010 — Initial web architecture recommendation

- **Date:** 2026-08-01
- **Status:** Accepted by Jeff in RP-TURN-002
- **Decision:** เริ่ม Rise Pals เป็น modular monolith บน Next.js App Router, React, strict TypeScript, Node.js 24 LTS/npm, PostgreSQL และ Drizzle โดยใช้ Git-versioned trusted MDX/metadata สำหรับ pilot lesson content และทดสอบทุก production feature บน native Windows/Node target
- **Reason:** รองรับ public SEO, sensitive server-side data access และ interactive assessment/lesson ใน codebase เดียว พร้อม transaction/versioning ที่ตรวจสอบได้โดยไม่เพิ่ม microservice complexity ก่อน MVP
- **Consequence:** Windows VPS target ถูกยืนยันแยกใน D-011; reverse proxy, process supervisor, auth, managed PostgreSQL placement, object storage, analytics และ monitoring ยังไม่ถูกเลือก Domain ใช้ internal IDs/provider adapters และหลีกเลี่ยง Vercel-only runtime dependency

## D-011 — Production application target

- **Date:** 2026-08-01
- **Status:** Accepted by Jeff in RP-TURN-001-R1
- **Decision:** ใช้ Windows Server 2022 VPS เครื่องนี้เป็น intended production application deployment target ของ Rise Pals
- **Consequence:** สถาปัตยกรรมต้องรองรับ native Windows/Node, HTTPS reverse proxy, supervised services, least-privilege identities, firewall, secrets, logs/monitoring, versioned releases/rollback, database connectivity, off-host backup/restore, patching และ incident response โดยไม่สมมติว่ามี Docker, WSL หรือ Linux
- **Note:** การยืนยัน target ไม่ได้แปลว่า VPS พร้อม production; ยังไม่มี application, service, deployment หรือ public launch

## D-012 — Approved Public GitHub source destination

- **Date:** 2026-08-01
- **Status:** Accepted by Jeff in RP-TURN-001-R2
- **Decision:** ใช้ existing Public repository [`noppol87/RisePals`](https://github.com/noppol87/RisePals) บน personal GitHub account ของ Jeff เป็น future canonical source/history ผ่าน branch, pull request, automated checks และ versioned release artifacts
- **Consequence:** ทุก tracked file และ commit ต้องปลอดภัยต่อการเปิดเผยสาธารณะ Workspace/release บน VPS ต้องไม่เป็น source copy เดียว และ GitHub ไม่ใช่ backup สำหรับ database, uploads, proof, secrets, production state, private logs หรือ telemetry
- **Required before first push:** inventory tracked files, scan secrets/worktree/staged/history, ใช้ synthetic fixtures เท่านั้น, ตรวจ `.gitignore`, review เอกสารเพื่อหา operationally sensitive data, ยืนยัน destination/visibility และ review complete commit history
- **Never commit:** `.env` นอกจาก safe `.env.example`, credentials/tokens/private keys, secret-bearing production config, database dumps, uploads/proof artifacts, assessment answers/personal data, private logs/production telemetry, certificate private keys, generated production data หรือ backups
- **Open:** Git/GitHub และ VPS deployment authentication, local initialization/remote/first commit/push, branch rules, CI provider/plan, artifact retention, deployment transport และ software license; ห้ามเพิ่ม `LICENSE` จนกว่า Jeff จะตัดสินใจ
- **Note:** local Git ยังไม่มีและยังไม่เชื่อมกับ repository; RP-TURN-001-R2 ไม่ติดตั้ง, initialize, authenticate, commit, push, configure workflow หรือเปลี่ยน external state

## D-013 — Partial assessment scoring and multiplier separation

- **Date:** 2026-08-02
- **Status:** Accepted by Jeff in RP-TURN-006 authorization
- **Decision:** RP-TURN-006 ใช้ deterministic integer rubric เพื่อสร้างเฉพาะคะแนนสัญญาณ `earned / available` ราย core competency ที่มีข้อคำถาม และ observation แยกสำหรับ Ownership Thinking กับ Sense of Urgency โดยไม่สร้าง overall score, proficiency stage, priority gap หรือ recommendation จาก assessment slice ที่ยังไม่ validate
- **Reason:** ชุดคำถามจำลองหกข้อครอบคลุม core เพียง 2 จาก 8 ด้านและ multiplier ด้านละหนึ่งสถานการณ์ จึงไม่มีหลักฐานเพียงพอสำหรับคะแนนรวม pattern พฤติกรรม ความมั่นใจ หรือการพยากรณ์บุคคล
- **Consequence:** canonical core weights ยังคงเป็น metadata รวม 100% แต่ไม่ถูกใช้สร้าง partial aggregate; +2 ไม่คูณหรือเปลี่ยน core signals; output และ explanation ต้องระบุว่า provisional/fixture-only, แสดงหก core ที่ยังไม่ถูกประเมิน และห้ามใช้ทำนาย job loss, job performance, employability หรือ hiring eligibility
- **Open:** assessment methodology, psychometric/content validation, calibration, confidence semantics, proficiency mapping, priority logic และการใช้ผลกับ UX จริงต้องผ่าน review และ turn แยกก่อน

## D-014 — Prototype-only assessment resume state

- **Date:** 2026-08-02
- **Status:** Accepted by Jeff in RP-TURN-007 authorization
- **Decision:** RP-TURN-007 ใช้ versioned same-tab `sessionStorage` เท่านั้นเพื่อ resume ขั้นและตัวเลือกของ player โดยเก็บเฉพาะ storage schema version, assessment version ID, phase/current item และคู่ item/option IDs ที่เลือก; selected IDs จัดเป็นข้อมูล assessment ระดับ P3 แม้อยู่ใน browser ชั่วคราว
- **Reason:** ทดสอบ usability ของ multi-step flow และ refresh recovery ได้โดยไม่สร้าง account, cookie, API, server persistence, consent receipt, analytics หรือ dependency เพิ่ม
- **Consequence:** payload ต้องใช้ exact allowlist, validate กับ assessment definition ปัจจุบัน, ล้าง record ที่ malformed/unknown/incomplete/version-incompatible, ทำงานต่อได้เมื่อ storage ถูก block และมี clear action โดยผู้ใช้; ห้ามเก็บ copy, rubric, target, weight, score, timestamp, profile หรือ free text และห้ามส่งคำตอบใน URL/log/network
- **Open:** durable/cross-device resume, authentication, consent, retention, export/deletion, server-side assessment sessions/responses และ production storage ต้องผ่าน privacy/product review และ turn แยก; decision นี้ห้ามใช้เป็น production persistence design

## D-015 — Synthetic example-result boundary

- **Date:** 2026-08-02
- **Status:** Accepted by Jeff in RP-TURN-008 authorization
- **Decision:** RP-TURN-008 แสดง skill-map และ next-practice UX prototype จาก reviewed synthetic fixture ที่ระบุชัดเจนเท่านั้น โดยไม่อ่าน ไม่ให้คะแนน และไม่ตีความ item/option IDs ใน `sessionStorage` ของผู้ใช้ ผลที่เห็นจึงเป็นตัวอย่างคงที่ ไม่ใช่ผลประเมินหรือคำแนะนำเฉพาะบุคคล
- **Reason:** ทีมต้องทดสอบการสื่อสาร raw evidence coverage, ข้อจำกัด, +2 observations และ recommendation trace ก่อนที่ assessment methodology, priority logic, lesson content หรือ production privacy/consent system จะพร้อม โดยไม่ทำให้ตัวเลือกจาก usability player ดูเหมือนผลที่ผ่านการตรวจสอบแล้ว
- **Consequence:** route ต้อง server-render จาก fixture/version ที่กำหนด, แสดงเฉพาะสอง provisional core signals ที่ fixture ครอบคลุม, หก unassessed cores และ multiplier ด้านละหนึ่งสถานการณ์แยกกัน; next practice ต้องติดป้ายว่าเป็นตัวอย่างและอ้างถึง planned/unavailable lesson version ห้ามสร้าง overall/weighted score, proficiency/confidence/stage, readiness/risk/personality หรือ employment/hiring inference และห้ามส่งคำตอบผ่าน URL, log, analytics หรือ network
- **Open:** validated assessment result UX, personalized priority algorithm, proficiency/confidence semantics, lesson availability, real learner recommendations, durable result storage, consent, export/deletion และ production use ต้องมี evidence review และ turn authorization แยกต่างหาก

## D-016 — Repository-local lesson and practice prototype boundary

- **Date:** 2026-08-03
- **Status:** Accepted for RP-TURN-009 implementation
- **Decision:** RP-TURN-009 เพิ่มบทเรียนต้นแบบสองภาษา `source-verification-practice` รุ่น `lesson-source-verification-practice-v1@1.0.0` ผ่าน typed local content contract ที่ schema-validated และ versioned ใน Git โดยเชื่อม fixed example-result ไปยังบทเรียนด้วยข้อความชัดเจนว่าไม่ใช่คำแนะนำเฉพาะบุคคล; ประสบการณ์ Learn → Practice → Feedback → Proof placeholder ทำงานใน browser memory เท่านั้นและไม่อ่าน assessment response ทั้งนี้ยังไม่สร้าง MDX compilation/publication pipeline ซึ่งเลื่อนไป RP-TURN-014
- **Reason:** ทีมต้องพิสูจน์เส้นทางจากเนื้อหาสั้นสู่การตัดสินใจที่ลงมือทำได้, feedback ตามเกณฑ์ที่เปิดเผย และรูปแบบหลักฐานในอนาคต โดยไม่ทำให้ต้นแบบดูเป็นบทเรียนที่เผยแพร่แล้วหรือผลลัพธ์การเรียนรู้ที่ผ่านการตรวจสอบ
- **Consequence:** บทเรียนต้องระบุ Critical Thinking & Fact-Checking, working stage `Practicing`, R.O.I. pillar `Intelligent Risk & Governance`, เกณฑ์ binary สามข้อ และกติกาตัวอย่าง 20 XP เฉพาะเมื่อผ่านครบทั้งสามข้อ; passive viewing/incomplete ได้ 0, การประเมินซ้ำแทนที่ผลเดิมและไม่สะสม XP, refresh ล้าง state, proof/reflection ไม่มี input, upload, file generation หรือ persistence และห้ามส่ง choice/progress ผ่าน storage, URL, cookie, log, analytics, network หรือ server action
- **Open:** publication workflow, trusted content schema/MDX pipeline ใน RP-TURN-014, author/reviewer identity, efficacy/validation evidence, durable progress, real XP ledger, proof submission/review, reflection collection, credentials, consent, retention/export/deletion และ production lesson delivery ต้องผ่าน decision และ turn authorization แยก; D-016 ไม่ใช่ production learning architecture

## D-017 — PostgreSQL baseline and trusted RLS context

- **Date:** 2026-08-03
- **Status:** Accepted by Project Codex after RP-TURN-010 closeout
- **Decision:** Establish one PostgreSQL/Drizzle baseline migration for only the nine authorized identity, consent and versioned definition tables. Force RLS on user-owned tables and resolve ownership through a validated transaction-local user UUID set only by trusted server code. The normal application role must be separate from the migration/table-owner role and must be neither superuser nor `BYPASSRLS`.
- **Reason:** Database invariants and tenant isolation need evidence from PostgreSQL itself before durable user workflows are authorized. A disposable loopback-only PostgreSQL instance with synthetic users tests the migration without selecting or creating production infrastructure.
- **Consequence:** Version rows begin as drafts, publish only after database validation, may retire only through a status-only transition and are immutable while published or retired. The eight exact core weights total 10,000 basis points; multipliers remain unweighted; consent is append-only; unsafe foreign-key deletion fails closed; JSON content requires an explicit schema version. Ordered parent locks protect OLD and NEW framework/assessment parents from reparent and publication races. Normal application runtime receives only the non-owner `DATABASE_URL`; migration/test tooling alone receives the separately decoded-role-validated owner URL. Application credentials cannot migrate schema or bypass RLS, and browser code must never receive a database credential or control the trusted context directly.
- **Open:** Production provider/placement, supported deployed major version, credentials and rotation, TLS path, pooling, backups/restore, retention/deletion, monitoring and operational access remain separate decisions. RP-TURN-010 does not authorize authentication, profiles, assessment response persistence, scoring persistence, lesson progress, XP, proof storage, CI, a Windows service or deployment.

## D-018 — Clerk Development synthetic-alpha identity boundary

- **Date:** 2026-08-06
- **Status:** Accepted by Project Codex after RP-TURN-011 closeout
- **Decision:** Use one Jeff-controlled Clerk Development application behind the internal `IdentityProvider` boundary for synthetic alpha only, on Free/Hobby without payment information, with email verification code as the only method. Accept Clerk's US identity hosting only for synthetic test identities. Rise Pals owns authorization and data through internal `user_accounts.id`; the Clerk subject is only a server-validated external mapping key and is never an application ownership key.
- **Reason:** A hosted Development flow can test account/profile usability without implementing password or token handling, while an internal provider adapter plus PostgreSQL account state preserves migration options and prevents vendor metadata from becoming the product authorization/profile store.
- **Consequence:** Only `pk_test_`/`sk_test_` configuration is accepted from ignored local environment files; live/incomplete pairs fail closed. Do not copy email unless a later approved requirement proves it essential. Do not store profile, goals, consent, assessment data or application roles in Clerk metadata, and do not expose tokens/provider subjects in DTOs, URLs, logs or browser storage. Thai localization is experimental and requires authoritative visible fallback copy. Real users/data, Production instances, paid features, social OAuth, SMS, passwords, Organizations and custom domains are prohibited. Any synthetic smoke identity must be deleted before handoff; no identity existed in the keyless RP-TURN-011 implementation run.
- **Open:** Production identity provider suitability, Thailand/privacy/legal/data-residency/DPA review, production region, cost, credential rotation, incident response, final session policy, account linking/recovery, deletion orchestration and real-user consent remain separate decisions. RP-TURN-011 does not authorize RP-TURN-012, production PostgreSQL, CI, infrastructure or deployment.

## D-019 — Owner-scoped raw assessment persistence boundary

- **Date:** 2026-08-16
- **Status:** Authorized for RP-TURN-012 synthetic-alpha implementation; implementation and required real-provider verification complete pending Project Codex review
- **Decision:** Add one distinct authenticated `/[locale]/assessment/attempt` path whose PostgreSQL source of truth is limited to one owner-scoped session for exact accepted published assessment/item versions and append-only raw selected-option revisions. The existing public `/[locale]/assessment` same-tab `sessionStorage` prototype remains separate and is never imported or promoted. Session start requires an active internal account plus the current exact `service-profile-learning-state` / `alpha-privacy-v1` grant and records the granted consent receipt used at start. Browser input never supplies the internal owner, consent receipt, database version IDs or trusted RLS context.
- **Reason:** Cross-refresh and cross-sign-in persistence needs a narrowly testable owner/consent/version contract before scoring is authorized. Raw option identities are P3 sensitive career/assessment data, so PostgreSQL constraints, forced RLS and minimal client DTOs must enforce the boundary independently of presentation code.
- **Consequence:** `assessment_sessions` supports only `in_progress → submitted`, has database-owned timestamps and an exact-version resume marker, allows at most one alpha session per owner/version and cannot be reopened, replaced or deleted. `assessment_responses` stores only `{schemaVersion, selectedOptionId}` plus monotonic revision, supersession and client-mutation provenance; database validation rejects unknown items/options, malformed payloads, stale history shapes and post-submit mutation. Exactly one active revision exists per answered item. Server operations use the accepted authorization transaction and return no session/user/row UUID, provider subject, scoring/rubric/weight metadata or answer-bearing URL/storage/log field to the browser. No context snapshot is stored because it is unnecessary for this bounded flow.
- **Open:** RP-TURN-012 does not authorize scoring runs, derived results, recommendations, re-assessment, abandonment, deletion, retention/export/erasure operations, real users/data, production identity/database/provider approval, CI, infrastructure or deployment. The final bounded real-provider smoke verified logout denial, same-identity re-authentication, safe return handling, browser/database privacy boundaries and complete identity/build/database cleanup. This verification does not constitute Project Codex acceptance or production approval. RP-TURN-013 remains unstarted and unauthorized.
