# Codex Collaboration Workflow

## Active workflow — Jeff and VS Code Codex

Jeff has ended the two-context review relay and authorized continuous bounded repository work in this context. This section supersedes the historical protocol below. No separate Project Codex acceptance, message envelope or copy block is required.

- Jeff owns product direction, priorities, acceptance and decisions with material cost or risk.
- Codex plans, implements, inspects the actual diff, tests and reports directly to Jeff. Self-checks are not independent reviews.
- Continue through ordinary repository-only corrections. Use focused gates during iteration and required full/security gates at integration checkpoints; do not silently skip checks or use retry-until-pass.
- Keep one factual status: completed work, actual verification, remaining blockers and next action. Progress percentages are scope-specific planning estimates, not measured readiness.
- Preserve existing work and historical acceptance evidence. Source priority remains Jeff's latest explicit instruction, current bounded scope, actual repository/test evidence, documents, then summaries.
- Removing the review relay does not override execution-tool policy or permit bypassing access controls.
- Host/service/ACL/firewall/certificate changes, UAC, real-user data, production resources, external costs and deployment still require explicit scoped authorization. Existing narrow exceptions apply only to their exact targets.
- Preserve clean-worktree simulation checks, exact-head binding, authorized staging, secret scans and truthful cleanup. Do not merge a Draft PR merely because the review workflow changed.
- Preserve synthetic-alpha, consent, forced-RLS, publication, scoring-separation and prototype-unvalidated boundaries. RP-TURN-019 remains Partial until its remaining gates are proven.
- Use `prompts/VS_CODE_HANDOFF_TEMPLATE.md` as a direct-report checklist. Ask Jeff only for missing authority, a material trade-off or a genuine external blocker.

## Historical two-context protocol — no longer active

The following original process is retained for provenance only. Its Project Codex review and copy-block requirements do not govern new work.

## Purpose

สร้างวิธีทำงานที่ Jeff สามารถควบคุมทิศทางได้ ขณะที่ Codex ใน VS Code ลงมือเขียนโค้ด และ Project Codex ทำหน้าที่ตรวจสอบคุณภาพกับออก brief ของ turn ถัดไป

## Roles

### Jeff — Product Owner

- กำหนดวิสัยทัศน์ ลำดับความสำคัญ และข้อจำกัดทางธุรกิจ
- ตัดสินใจเมื่อมี trade-off ที่เปลี่ยน product direction
- ส่ง copy block ระหว่าง Codex สองบริบท
- อนุมัติการขยาย scope, external cost และ production action

### Project Codex — Strategy, Review and Audit

- แปลงเป้าหมายของ Jeff เป็น turn brief ที่มีขอบเขตชัดเจน
- อ่าน repository, diff และผลทดสอบจริง
- Review product, UX, architecture, code quality, security, privacy และ evidence
- ชี้ bug, gap, risk และสิ่งที่ยังพิสูจน์ไม่ได้
- สร้าง copy block สำหรับ VS Code Codex ใน turn ถัดไป
- รักษา roadmap, decisions และ project status ให้สอดคล้องกับความจริง

### VS Code Codex — Implementation

- อ่าน repository instructions และ brief ของ turn
- ลงมือแก้เฉพาะ scope ที่ได้รับ
- รันทดสอบที่เกี่ยวข้องและรายงานผลตามจริง
- อัปเดต documentation/status ที่ brief กำหนด
- จบด้วย handoff copy block ที่ Project Codex ตรวจสอบต่อได้

## Source-of-truth hierarchy

เมื่อข้อมูลขัดกัน ให้ใช้ลำดับนี้:

1. คำสั่งล่าสุดที่ Jeff ระบุชัดเจน
2. Approved turn brief ล่าสุด
3. Repository และผลทดสอบจริง
4. Decision log และ project documents
5. Handoff summary ของ agent

Handoff เป็นรายงาน ไม่ใช่หลักฐานแทนโค้ด Project Codex ต้องตรวจไฟล์จริงเมื่อทำได้

## Cross-context message protocol

ข้อความทุกชุดที่ตั้งใจ copy ระหว่าง Project Codex, VS Code Codex และ Jeff ต้องเริ่มด้วย envelope สามบรรทัดก่อนเนื้อหา เพื่อให้รู้ว่าใครเป็นผู้เขียน ส่งให้ใคร และมีวัตถุประสงค์อะไร:

```text
SOURCE: [ACTUAL AUTHOR]
DESTINATION: [INTENDED RECIPIENT]
MESSAGE TYPE: [PURPOSE]
```

ข้อความจาก VS Code Codex ที่ตั้งใจส่งกลับให้ Project Codex ต้องใช้ค่า exact ต่อไปนี้:

```text
SOURCE: VS CODE CODEX
DESTINATION: PROJECT CODEX
MESSAGE TYPE: TURN HANDOFF | STATUS | ADVICE | DECISION REQUEST
```

กฎของ protocol:

1. ใช้ `MESSAGE TYPE: TURN HANDOFF` เฉพาะ submission ที่ VS Code Codex ทำ turn ที่ได้รับอนุมัติเสร็จหรือจบในสถานะ Partial/Blocked และกำลังส่งให้ Project Codex review อย่างเป็นทางการ
2. Status report, repository orientation, explanation และ advice ใช้ `STATUS` หรือ `ADVICE` ตามจริง ห้ามจัดรูปแบบให้ดูเป็น turn handoff
3. Project Codex ต้องไม่ใช้ข้อความที่ไม่มี envelope หรือไม่ได้ระบุ `MESSAGE TYPE: TURN HANDOFF` เป็นหลักฐานว่า turn เสร็จ
4. TURN HANDOFF ทุกชุดต้องระบุ Turn ID แบบ exact และทำตาม `prompts/VS_CODE_HANDOFF_TEMPLATE.md` โดยคง fields เรื่อง outcome, changed files, exact verification, acceptance evidence, decisions, known issues, not done และ review focus
5. Final copy block ภายใน handoff ต้องมี envelope `SOURCE`, `DESTINATION` และ `MESSAGE TYPE` ซ้ำด้วย เพื่อให้ยังระบุต้นทางได้เมื่อ Jeff copy เฉพาะ block นั้น
6. `SOURCE` ต้องเป็นผู้เขียนข้อความจริง ห้ามติดป้ายข้อความที่ Jeff เขียนว่า `SOURCE: VS CODE CODEX`; หาก Jeff เพิ่มคำสั่งเองให้ใช้ `SOURCE: JEFF` หรือแยกส่วนของ Jeff ออกจากข้อความที่ forward
7. เมื่อ Jeff forward ข้อความเดิมโดยไม่แก้ ให้รักษา envelope ของผู้เขียนเดิมไว้ ถ้ารวมข้อความหลายต้นทาง ให้แยก envelope/เนื้อหาแต่ละส่วนอย่างชัดเจน
8. Project Codex → VS Code Codex ควรใช้ `SOURCE: PROJECT CODEX`, `DESTINATION: VS CODE CODEX` และ purpose ที่ชัด เช่น `APPROVED TURN BRIEF`, `REVISION BRIEF`, `REVIEW RESULT` หรือ `DECISION REQUEST`

Envelope ระบุต้นทางและวัตถุประสงค์ แต่ไม่แทน repository, diff, test output หรือการอนุมัติของ Jeff

## Turn lifecycle

### Step 1 — Project Codex creates a Turn Brief

Brief ต้องมี:

- Turn ID และชื่อ
- Objective เดียวที่ชัดเจน
- Context และไฟล์ที่ต้องอ่าน
- In scope / out of scope
- Deliverables
- Acceptance criteria
- Verification commands
- Constraints และสิ่งที่ต้องขออนุมัติ
- Required handoff format

### Step 2 — Jeff sends the copy block to VS Code Codex

Jeff วางข้อความโดยไม่ต้องสรุปใหม่ เพื่อป้องกัน scope drift

### Step 3 — VS Code Codex implements and verifies

Codex ใน VS Code ตรวจสถานะ repository ก่อนแก้ ทำงานเฉพาะ turn และรันทดสอบจริง

### Step 4 — VS Code Codex returns a Handoff Block

ใช้ envelope `SOURCE: VS CODE CODEX`, `DESTINATION: PROJECT CODEX`, `MESSAGE TYPE: TURN HANDOFF` แล้วตามด้วยรูปแบบใน `prompts/VS_CODE_HANDOFF_TEMPLATE.md` Handoff ต้องระบุ Turn ID สิ่งที่ไม่ได้ทำและปัญหาที่ยังเหลือด้วย

### Step 5 — Jeff sends the handoff to Project Codex

Jeff ส่งข้อความพร้อม envelope เดิม Project Codex จะใช้ handoff เป็น index แล้วเปิดดูไฟล์ การเปลี่ยนแปลง และผลทดสอบใน project โดยตรง ข้อความที่ไม่มี `MESSAGE TYPE: TURN HANDOFF` ไม่ใช่ completed-turn submission

### Step 6 — Project Codex reviews and decides

ผล review มีได้สามแบบ:

- **Accepted:** ผ่าน acceptance criteria และไป turn ใหม่ได้
- **Revision required:** ยังอยู่ turn เดิม พร้อมรายการแก้ที่ชัดเจน
- **Decision required:** ต้องให้ Jeff ตัดสินใจ trade-off ก่อนเดินต่อ

### Step 7 — Next copy block

Project Codex ส่ง copy block เพียงหนึ่งชุดที่เป็นคำสั่งปัจจุบัน ลดความสับสนจากคำสั่งหลายเวอร์ชัน

## Review gates

Project Codex ตรวจตามความเสี่ยงของ turn:

- Scope compliance
- Product behavior and UX
- Correctness and edge cases
- Type safety and maintainability
- Tests/build/runtime behavior
- Accessibility and responsive design
- Authentication, authorization and data exposure
- Privacy and consent
- Evidence/citation integrity
- Performance and dependency risk
- Documentation and status accuracy

## Turn sizing

หนึ่ง turn ควรมี outcome ที่ review ได้ในรอบเดียว เช่น:

- สร้าง repository scaffold และ quality gates
- ทำ landing hero หนึ่ง flow พร้อม responsive test
- ทำ assessment data model และ migration
- ทำ assessment question renderer หนึ่งชุด

หลีกเลี่ยง brief แบบ “สร้างทั้ง MVP” เพราะตรวจยากและทำให้ agent ตัดสินใจแทน product owner มากเกินไป

## Change control

สิ่งต่อไปนี้ต้องขอ Jeff ก่อน หาก brief ยังไม่อนุมัติ:

- เปลี่ยน framework หรือ scoring philosophy
- เปลี่ยน stack หลักหลังเริ่ม implementation
- เพิ่มบริการที่มีค่าใช้จ่าย
- deploy production หรือแก้ DNS/domain
- เก็บข้อมูลส่วนบุคคลเพิ่ม
- เปิด automated hiring decision
- เปลี่ยน brand name, promise หรือ visual direction หลัก

## Copy-block conventions

- ใช้รหัส `RP-TURN-###`
- ระบุ repository root เสมอ
- ระบุ `SOURCE`, `DESTINATION` และ `MESSAGE TYPE` เป็นสามบรรทัดแรกของทุกข้อความที่ตั้งใจ copy ระหว่าง contexts
- Copy block สำหรับ VS Code ต้อง self-contained แต่ไม่คัดลอกเอกสารทั้งโปรเจกต์
- VS Code handoff และ final copy block ภายในต้องใช้ `MESSAGE TYPE: TURN HANDOFF`, ระบุ Turn ID, path และคำสั่งทดสอบที่แน่นอน
- Status, orientation, explanation และ advice ต้องใช้ message type ตามวัตถุประสงค์และห้ามใช้ handoff template
- ห้ามระบุข้อความที่ Jeff เขียนเองว่า `SOURCE: VS CODE CODEX`
- หาก turn ไม่ผ่าน ให้ใช้รหัสเดิมและเติม revision เช่น `RP-TURN-003-R1`
