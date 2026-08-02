# RP-TURN-002 — Git and Public GitHub Foundation

## Authorization

Jeff approved this bounded turn for the repository at `C:\Codex PC SG2\Jeff\risepals`.

Approved destination:

- Owner: `noppol87`
- Repository: `RisePals`
- Visibility: Public
- URL: `https://github.com/noppol87/RisePals`

The technical direction accepted with this turn is Next.js App Router, React with strict TypeScript, Node.js 24 LTS/npm, PostgreSQL with Drizzle, Git-versioned trusted MDX/metadata for pilot lessons, a modular monolith and later native Node.js deployment on the confirmed Windows Server 2022 VPS.

## Objective

Establish a verified Git source-control baseline and publish only the reviewed repository foundation to the exact approved empty Public GitHub repository before application development.

## Read first

- `AGENTS.md`
- `README.md`
- `PROJECT_STATUS.md`
- `docs/01_PRODUCT_VISION.md` through `docs/10_LOCAL_DEVELOPMENT.md`
- `docs/DECISION_LOG.md`
- `prompts/VS_CODE_HANDOFF_TEMPLATE.md`
- `prompts/TURN_001_REPO_FOUNDATION.md`

## Required work

1. Record Jeff's acceptance in D-010, correct the engineering turn order and update project status only with facts established in this turn.
2. Install only current supported Git for Windows and GitHub CLI distributions from official sources. Verify signature or official checksum where supported and record versions, sources, commands and results.
3. Before mutation, prove that no repository or parent `.git` exists and that the exact approved remote is Public, owned by `noppol87` and contains no branch, tag, file or commit.
4. Authenticate through GitHub's interactive web/device flow. Never request or expose a token, private email or private key.
5. Inventory every candidate file, review documentation for operationally sensitive data, verify `.gitignore`, use synthetic content only and run a recognized temporary secret scanner.
6. Initialize this exact directory with `main`, configure identity only in this repository using the authenticated account's derived GitHub noreply address and add exactly one `origin` after remote verification.
7. Stage only the reviewed foundation inventory. Inspect `git status --short`, the staged file list, `git diff --cached --stat` and `git diff --cached --check`; scan the exact staged content before commit.
8. Create one intentional commit named `chore: establish Rise Pals foundation` and push `main` to `origin` without force. Direct `main` push is allowed only because the verified remote is empty.
9. Verify local and remote hashes, upstream, clean status, GitHub owner/visibility/file inventory and prohibited-file absence.
10. Remove the interactive GitHub credential after the verified push while preserving the public read-only remote configuration.

## Public-repository security gates

Never commit:

- `.env` files other than a reviewed safe `.env.example`
- credentials, tokens, private keys or certificate private keys
- production configuration containing secrets
- database dumps, backups or generated production data
- uploads, proof artifacts or Playwright authentication state
- assessment answers, personal data, private logs or production telemetry

Before commit and push, verify:

- complete tracked/staged inventory
- worktree and exact staged-content secret scans
- synthetic fixtures only
- `.gitignore` coverage
- operationally safe documentation
- exact destination and Public visibility
- complete commit history to be pushed
- no `LICENSE`; software licensing remains open

## Constraints

- Preserve all existing files and Jeff's work.
- Do not force-push, overwrite, merge or pull unexpected remote history.
- Stop as Blocked if the remote is non-empty, has unexpected ownership/visibility or contains any ref.
- Do not expose authentication secrets in commands, files, logs or handoff.
- Do not install Node.js or application dependencies.
- Do not scaffold the application.
- Do not configure CI or branch protection.
- Do not create a VPS service, database, DNS change, cloud resource or deployment.
- Do not continue into RP-TURN-003.

## Acceptance and handoff

Complete only when the reviewed initial commit is present on Public `noppol87/RisePals`, local `main` and `origin/main` hashes match, the worktree is clean, prohibited data is absent and persistent interactive authentication has been removed.

Report every command actually executed and its exact result. Begin the final response with the required source/destination/message envelope and use `prompts/VS_CODE_HANDOFF_TEMPLATE.md`.
