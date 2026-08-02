# RP-TURN-001 — Repository Foundation and Technical Architecture

ส่ง copy block ด้านล่างให้ Codex ใน VS Code เป็น turn แรก

````text
RP-TURN-001 — Repository Foundation and Technical Architecture

Repository root:
C:\Codex PC SG2\Jeff\risepals

Objective:
Establish an evidence-backed technical direction and repository foundation for the Rise Pals MVP without building product features yet.

Read first:
- AGENTS.md
- README.md
- PROJECT_STATUS.md
- docs/01_PRODUCT_VISION.md
- docs/02_SKILL_FRAMEWORK.md
- docs/03_MVP_SCOPE.md
- docs/04_PRODUCT_ROADMAP.md
- docs/05_BRAND_VISUAL_CONTENT.md
- docs/06_CODEX_COLLABORATION_WORKFLOW.md
- docs/DECISION_LOG.md

Context:
Rise Pals will be developed in VS Code turn by turn. The initial experience must support a Thai-first, animated and gamified web app with assessment, lesson, practice, progress and future subscription/hiring expansion. The architecture should optimize for a fast MVP while preserving privacy, accessibility and future maintainability.

In scope:
- Inspect the actual local development environment and available runtimes.
- Check whether the repository is already under Git and report the result.
- Recommend the web stack using a concise decision matrix.
- Define application boundaries, major modules and data ownership.
- Draft the initial data model for user profile, framework version, competencies, assessment, lesson, practice, progress and evidence.
- Define quality gates, testing strategy, environment-variable policy and local developer workflow.
- Produce a sequenced implementation plan split into reviewable turns.
- Initialize Git only if it is available and the folder is not already inside another repository; do not create a remote or commit.

Out of scope:
- Do not scaffold the application framework yet.
- Do not install dependencies.
- Do not build UI or product features.
- Do not create cloud resources, accounts, databases or deployments.
- Do not alter DNS or risepals.com.
- Do not finalize payment, analytics or hosting vendors without presenting trade-offs.

Required deliverables:
1. Create docs/07_TECHNICAL_ARCHITECTURE.md with the recommended stack, decision matrix, system boundaries, security/privacy baseline and deployment options.
2. Create docs/08_DATA_MODEL.md with entities, key fields, relationships, sensitive-data classification and deletion/export considerations.
3. Create docs/09_ENGINEERING_PLAN.md with small implementation turns, acceptance gates and test strategy.
4. Create docs/10_LOCAL_DEVELOPMENT.md describing verified local prerequisites and proposed commands. Mark commands as proposed when they cannot yet be run.
5. Add a root .gitignore only if its contents can be chosen confidently from the recommended stack and local environment.
6. Update PROJECT_STATUS.md and docs/DECISION_LOG.md only with decisions actually made in this turn. Keep undecided vendor choices clearly open.

Architecture questions to answer:
- Which React/TypeScript framework best fits the MVP and why?
- What should render on the server versus client?
- How should lesson content be versioned and authored?
- How should assessment answers and score explanations be stored?
- How do we avoid locking the future hiring product to an unvalidated score?
- Which parts should be provider-agnostic at this stage?
- How will Thai/English localization, accessibility, motion preferences and mobile responsiveness be handled?
- What is the smallest useful automated-test pyramid for the first three milestones?

Acceptance criteria:
- Recommendations explicitly map to the documented MVP, not a generic SaaS template.
- Every major vendor recommendation includes at least one alternative and a trade-off.
- Data model separates raw answers, derived scores, framework versions and user-controlled proof.
- Architecture includes reduced-motion behavior, localization and privacy controls.
- Engineering plan uses bounded turns that Project Codex can review independently.
- No product feature code, dependency installation, external resource or deployment is created.

Verification:
- Verify every created Markdown file can be opened and contains no unresolved placeholder tokens.
- List the environment/runtime checks actually executed and their exact results.
- If Git is available, run `git status --short`; otherwise report that it is unavailable.

Constraints:
- Follow AGENTS.md.
- Preserve all existing files and Jeff's work.
- Prefer simple, reversible architecture.
- Do not pretend unverified assumptions are facts.
- Do not continue into Turn 002.

End-of-turn requirement:
Respond using prompts/VS_CODE_HANDOFF_TEMPLATE.md. Include the final copy block for Jeff to paste to Project Codex for review.
````

