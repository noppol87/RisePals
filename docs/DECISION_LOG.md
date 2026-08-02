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
