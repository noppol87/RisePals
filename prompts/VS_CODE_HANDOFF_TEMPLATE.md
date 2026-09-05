# VS Code Handoff Template

## Active direct-report checklist

Jeff now directs and accepts work directly in VS Code Codex. The old envelope and copy-block template below is historical and is not required for current work.

Report concisely: outcome/status, changed files and commit when applicable, actual commands/results, remaining work, necessary Jeff decisions and task cleanup/safety state. Distinguish retained evidence from new verification. Do not claim independent review, acceptance, clean state, live readiness or deployment without evidence. Ordinary repository-only failures are progress updates; continue within the authorized scope.

## Historical template — superseded

Codex ใน VS Code ต้องใช้รูปแบบนี้เมื่อจบ turn ที่ได้รับอนุมัติและส่งให้ Project Codex review อย่างเป็นทางการ Status report, repository orientation, explanation และ advice ต้องใช้ message type ตามจริงและห้ามใช้ handoff template

```text
SOURCE: VS CODE CODEX
DESTINATION: PROJECT CODEX
MESSAGE TYPE: TURN HANDOFF

RISE PALS TURN HANDOFF

Turn:
RP-TURN-[###] — [TURN NAME]

Status:
[Complete / Partial / Blocked]

Outcome:
[สรุปสิ่งที่ใช้งานได้แล้ว 2–5 บรรทัด]

Files changed:
- [path] — [what changed]

Verification performed:
- `[exact command]` → [PASS/FAIL and concise result]

Acceptance criteria:
- [criterion] → [met/not met + evidence]

Decisions and assumptions:
- [item or None]

Known issues / risks:
- [item or None]

Not done:
- [explicitly list anything intentionally left out]

Suggested review focus:
- [files, behavior or risks Project Codex should inspect]

COPY BLOCK FOR PROJECT CODEX
---
SOURCE: VS CODE CODEX
DESTINATION: PROJECT CODEX
MESSAGE TYPE: TURN HANDOFF

Please review RP-TURN-[###] in C:\Codex PC SG2\Jeff\risepals.

Read AGENTS.md, the approved turn brief, PROJECT_STATUS.md, and inspect the actual changed files. Verify the implementation and test claims rather than relying only on this summary.

Implementation outcome:
[paste concise outcome]

Files changed:
[paste file list]

Tests/checks:
[paste exact commands and results]

Known issues or decisions needed:
[paste items]

Please return one of: Accepted, Revision required, or Decision required. Then provide the single next copy block for VS Code Codex.
---
```

Protocol requirements:

- ใช้ `MESSAGE TYPE: TURN HANDOFF` เฉพาะ completed/partial/blocked turn submission ที่ระบุ Turn ID ชัดเจน
- ข้อความที่ไม่มี envelope สามบรรทัดแรกไม่ใช่หลักฐานว่า turn เสร็จ
- Final copy block ต้องคง envelope ไว้เมื่อ Jeff copy แยกจาก handoff หลัก
- `SOURCE` ต้องเป็นผู้เขียนข้อความจริง ห้ามใช้ `SOURCE: VS CODE CODEX` กับข้อความที่ Jeff เขียนเอง
