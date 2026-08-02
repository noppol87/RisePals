# Rise Pals

Rise Pals คือแพลตฟอร์มพัฒนาความพร้อมในการทำงานยุค AI สำหรับคนทำงานออฟฟิศไทย ช่วยให้ผู้ใช้รู้ว่าตนเองมีช่องว่างด้านทักษะอะไร ควรพัฒนาอะไรก่อน เรียนผ่านประสบการณ์แบบ gamified และสร้างหลักฐานความสามารถที่ต่อยอดไปสู่โอกาสทางอาชีพได้

**Brand:** Rise Pals  
**Digital wordmark:** `risepals`  
**Primary domain:** `risepals.com`  
**Project status:** RP-TURN-006 synthetic assessment-domain contract accepted / no assessment player, real assessment, data collection or persistence  
**Last updated:** 2026-08-02

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

RP-TURN-003 established one minimal Next.js App Router application at the repository root. RP-TURN-004 established a Thai-first, server-rendered locale boundary, semantic responsive app shell, provisional semantic design tokens and the small accessible primitives required by that shell. RP-TURN-005 replaces the structural verification panel with a bounded public narrative prototype; it is not onboarding, assessment or a production launch.

Locale routes:

- `/` redirects to the Thai default at `/th`
- `/th` renders the Thai shell and catalog
- `/en` renders the prepared English shell and catalog
- unsupported locale segments return not found

The public narrative now provides:

- Thai-first optimistic-realism hero copy with an honest internal CTA and no data collection
- exactly two localized evidence items from the ILO–NASK occupational-exposure study and the World Economic Forum Future of Jobs Report 2025
- visible source, date, geography, method/context, limitation and review metadata for every evidence item
- the complete Diagnose → Prioritize → Learn → Practice → Prove → Opportunity loop
- a compact preview that keeps the eight core competencies distinct from the two behavioural multipliers
- no assessment questions, scoring, personalized risk, waitlist form, pricing, account creation or external runtime fetch

The repository also contains the accepted RP-TURN-006 versioned synthetic assessment-domain contract. It is not connected to the public routes and provides:

- exactly six synthetic bilingual scenario-choice items: two Critical Thinking & Fact-Checking, two Systematic Thinking, one Ownership Thinking and one Sense of Urgency
- all eight canonical core identities and exact weights, with both behavioural multipliers structurally separate and unweighted
- pure deterministic integer-rubric scoring with earned/available points, evidence counts and traceable item keys
- two synthetic raw-response fixtures kept separate from expected scores and expected explanations
- explicit provisional limitations, six unassessed core competencies and no overall score, proficiency stage, priority recommendation or employment implication
- no React/Next.js route, browser API, profile, session, personal data, persistence or dependency addition

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
npm run test:e2e
```

`npm run test:e2e:install` installs only the pinned Playwright Chromium browser. `npm run test:e2e` verifies locale routing, document language, language switching, evidence attribution/limitations/source destinations, the honest CTA, keyboard and skip-link behavior, 320px reflow, desktop layout, reduced motion, absence of unexpected third-party requests and serious/critical axe findings.

Copy `.env.example` to an ignored local environment file only when local configuration is needed. `APP_BASE_URL` is optional and accepts only a normalized HTTP(S) origin without credentials, a non-root path, query or fragment. Never commit a real `.env` file or secret.

The exact install, verification results and Windows notes are recorded in [Local Development](docs/10_LOCAL_DEVELOPMENT.md).

## วิธีทำงานของโปรเจกต์

โปรเจกต์นี้ใช้ Codex สองบริบทที่มีหน้าที่ต่างกัน:

- **Project Codex:** ช่วย Jeff คิด product strategy, แตกงาน, review, comment, audit และออกคำสั่งสำหรับ turn ถัดไป
- **VS Code Codex:** ลงมือแก้ repository ตาม brief ทีละ turn พร้อมทดสอบและส่ง handoff กลับมา

ทุก turn ต้องจบด้วย handoff ที่ตรวจสอบได้ จากนั้น Project Codex จะอ่านไฟล์และ diff จริงก่อนออก brief รอบถัดไป รายละเอียดอยู่ใน [Codex Collaboration Workflow](docs/06_CODEX_COLLABORATION_WORKFLOW.md)

## Current boundary

RP-TURN-006 — Assessment Domain Fixtures and Scoring Contract is Accepted. Its outcome is a versioned synthetic contract with exact canonical 8+2 metadata, deterministic separate core/multiplier signals, explicit limitations and runtime validation. No assessment player, real assessment, onboarding, personalized result, lesson, profile, user data collection, persistence, authentication, database, proof, payment, analytics, CI, VPS service or deployment exists. RP-TURN-007 — Assessment Player Prototype is the next recommended turn but is not authorized or started.
