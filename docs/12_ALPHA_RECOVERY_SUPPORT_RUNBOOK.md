# Rise Pals Synthetic-Alpha Recovery and Support Runbook

Status: RP-TURN-018 implementation evidence pending Project Codex review.

This runbook is bilingual-aware: preserve the user's locale (`th` or `en`) in support communication, use the Thai/English controlled UI copy where available and record only redacted operational facts. It is limited to repository-controlled synthetic identities and disposable local resources.

## Start and stop criteria

Start a synthetic-alpha verification only when:

- the authorized branch/base and clean worktree match the active Project Codex brief;
- `.env.local` is ignored and untracked and the task does not require reading it;
- standard browser automation is explicitly Clerk-disabled and loopback-only;
- the checksum-pinned PostgreSQL 18.4 runtime is available;
- publication/scoring digests match the accepted values;
- no PostgreSQL Windows service or unrelated listener is present.

Stop immediately and escalate if a trust-boundary, privacy, digest, cleanup or cross-owner assertion fails. Do not rerun a provider smoke; RP-TURN-018 authorizes no real Clerk smoke.

Thai support summary: `หยุดการทดสอบและแจ้งเหตุโดยไม่ส่งคำตอบ แบบประเมิน หลักฐาน อีเมล รหัสผู้ใช้ หรือข้อมูลลับผ่านแชต`

English support summary: `Stop the test and escalate without sending assessment answers, evidence, email, user IDs or secrets through chat.`

## Triage and incident classification

| Class | Examples | Initial action |
|---|---|---|
| P0 privacy/security | Cross-owner access, secret/export/P2/P3 leakage, unauthorized erasure | Stop, isolate the bounded disposable process, preserve only redacted timestamps/status and escalate to Jeff/Project Codex |
| P1 integrity/recovery | Digest drift, incomplete migration/restore, unexpected replay mutation, missing RLS | Stop mutation, retain only sanitized command/result metadata, run bounded cleanup and request a decision |
| P2 availability/accessibility | Loopback build failure, keyboard trap, serious/critical axe finding, 320px overflow | Record locale/route/check name without payload, keep PR Draft and correct only within an authorized revision |
| P3 support/content | Copy mismatch or controlled validation feedback | Record locale, public route and expected/actual controlled message; never request private payloads |

Safe diagnostics include UTC timestamp, turn/commit, locale, fixed route template, controlled error category, command exit code and aggregate counts. Never request or paste answer option IDs, evidence selections, email/provider subjects, cookies, tokens, UUIDs, export bytes, database URLs, stacks with values or `.env.local` content.

## Deterministic verification

From the verified repository root, ordinary gates are:

```powershell
npm ci
npm run check
npm run test:e2e
npm run test:e2e:alpha
npm run db:test:disposable
npm run db:test:recovery
```

These commands must remain secret-free. The disposable runner chooses a loopback port, creates no Windows service, uses a GUID temporary child and deletes database data/log/credentials after stopping PostgreSQL.

## Owner export dry run

1. Confirm the internal owner comes from the authenticated server boundary; never accept an owner UUID from a browser export field.
2. Use `rise-pals-alpha-export-v1@1.0.0` through the server-only module.
3. Write only beneath a newly created GUID child of `%TEMP%\risepals-alpha-recovery` after validating the resolved parent.
4. Generate twice from unchanged state and compare bytes and SHA-256 without displaying content.
5. Confirm every section is owner-scoped and bounded; more than 500 rows in any section fails closed rather than truncating.
6. Confirm the manifest is present in Thai and English and that prohibited provider, subject, action/mutation digest, error, credential and arbitrary-metadata fields are absent.
7. Delete both export artifacts and verify no GUID child remains.

This is a dry run, not a legally complete data-subject export or a user delivery mechanism.

## Owner erasure dry run

1. Use only `rise-pals-alpha-erasure-v1@1.0.0` with the dedicated synthetic fake identity adapter.
2. Establish the separately controlled privacy context with the exact internal owner UUID and new opaque request UUID.
3. Request `deletion_pending`; confirm exact replay changes no timestamp and a conflicting UUID is rejected.
4. Run the fake provider revocation/deletion adapter; it must mutate once for the exact request.
5. Execute database erasure in the fixed dependency order and confirm only the minimized deleted `user_accounts` tombstone remains.
6. Replay the exact request and confirm zero deleted rows, no provider mutation and unchanged tombstone timestamps.
7. Confirm another synthetic owner, public definitions, publication identity and scoring digests are unchanged.

There is no browser route, staff UI, production operator credential or real provider deletion in this turn.

## Backup, restore and migration recovery

Use only `npm run db:test:recovery`. The script validates its own GUID child beneath the recovery temporary base and performs:

1. a fresh eight-migration/26-table disposable database check;
2. a separate seven-migration state followed by migration eight;
3. a bounded local PostgreSQL custom-format backup;
4. restore to a separate disposable database;
5. migration journal, table, forced-RLS, role, public/scoring digest and owner-count comparison;
6. export twice, erasure and exact replay on the restored copy;
7. a deliberately invalid restore that must fail;
8. child-database, dump/export, process/listener/log/credential cleanup.

Never point this command at a durable or production database. A production backup restored from before erasure can resurrect deleted rows. Production restore and deletion are blocked until Jeff approves a deletion ledger, backup-expiry/retention policy and reconciliation procedure.

## Cleanup verification

After every disposable run, confirm:

- no PostgreSQL Windows service exists;
- no PostgreSQL process or test listener remains;
- `%TEMP%\risepals-postgres-tests` has no child from the run;
- `%TEMP%\risepals-alpha-recovery` has no child from the run;
- no isolated build, dump, export, log or credential file remains;
- Git reports no generated artifact and `.env.local` remains ignored/untracked.

Do not delete a broad or computed path. Cleanup code must first resolve and verify the exact GUID child remains under the intended temporary parent.

## Identity/session and credential incidents

- For a Development session warning, record only the stage and whether navigation/session state was affected; do not suppress it or infer production suitability.
- Revoke or rotate a credential only through the owning provider's approved interface after Jeff authorizes the action. Never place a value in chat, a command argument that will be logged, source, docs, Git or a support ticket.
- After rotation, verify only sanitized key form/instance compatibility and rerun a separately authorized provider smoke at most once.
- Real-provider suitability, data residency, session behavior and production credential storage remain undecided.

## Open production blockers

RTO, RPO, retention periods, legal basis, privacy notice, provider suitability, staff access, operator dual control, deletion ledger, backup expiry, off-host/encrypted backup, production monitoring, CI, infrastructure and deployment are undecided. This runbook does not authorize real users, public launch or production resources.
