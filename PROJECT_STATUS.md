# Rise Pals — Project Status

**Status date:** 2026-08-02  
**Current phase:** Design foundation, localized app shell and quality gates accepted; no product features implemented  
**Current turn:** RP-TURN-004 accepted

## Locked decisions

- Product and brand name: **Rise Pals**
- Primary domain: **risepals.com** (registered by Jeff)
- Initial market: Thai office workers affected by AI-driven changes to work
- Core model: AI-Era High-Skilled Professional Strategy & Survival Framework, version 2.0
- Skill system: 8 core competencies + 2 independent multipliers
- Learning experience: self-learning with motion, animation, practice, feedback and gamification
- Commercial direction: monthly/yearly subscriptions plus course privileges
- Future expansion: employer-facing skill signals, vacancy matching and hiring opportunities
- New raster imagery and illustrations: GPT-Image-2
- Delivery process: Project Codex reviews and directs; VS Code Codex implements one approved turn at a time
- Cross-context messages identify source, destination and purpose; only marked TURN HANDOFF messages are completed-turn submissions
- Accepted technical direction: Next.js App Router, React with strict TypeScript, Node.js 24 LTS/npm, PostgreSQL/Drizzle, Git-versioned trusted MDX/metadata for pilot lessons and a modular monolith
- Production application deployment target: this Windows Server 2022 VPS using native Node.js after a separately approved infrastructure-readiness turn; the repository contains an application scaffold, but no production application/service/deployment exists yet
- Canonical source/history: Jeff's personal Public repository [`noppol87/RisePals`](https://github.com/noppol87/RisePals), connected locally as the single `origin`

## Completed artifacts

- Product vision
- Product interpretation of the 8+2 framework
- MVP boundary
- Milestone roadmap
- Brand, visual and evidence principles
- Codex turn-by-turn collaboration protocol
- Turn brief and handoff templates
- Technical architecture and provider decision matrix
- Initial logical data model and sensitive-data lifecycle
- Sequenced engineering plan and test strategy
- Verified local-development environment baseline
- Next.js/npm-oriented root `.gitignore`
- Windows VPS production boundaries and approved Public-GitHub destination with proposed source/release workflow
- RP-TURN-002 Git/Public-GitHub brief and corrected engineering-turn sequence
- Git `2.55.0.windows.3`, GitHub CLI `2.97.0` and Gitleaks `8.30.1` verified from official releases
- Reviewed 20-file initial foundation baseline published without force to Public `noppol87/RisePals`
- Official Node.js `24.18.1` LTS x64 and bundled npm `11.16.0` installed per-user with matching official SHA-256 and a valid OpenJS Foundation executable signature
- Minimal Next.js `16.2.12` App Router scaffold on bounded branch `agent/application-scaffold`, with React `19.2.4`, strict TypeScript, Tailwind CSS tokens and Server Components by default
- Reproducible npm lockfile, typed server-only environment boundary, semantic scaffold render tests and format/lint/typecheck/test/build gates
- RP-TURN-003 application scaffold and quality gates accepted by Project Codex
- Thai-first `/th` and prepared English `/en` route boundary, with `/` default redirect, deterministic unsupported-locale handling and correct document language
- Matching typed Thai/English shell catalogs resolved server-side, semantic app shell, real-link language switcher, accessible layout primitives and provisional semantic design tokens
- Pinned Chromium-only Playwright and axe browser-test foundation covering locale routing, keyboard/focus, 320px reflow, desktop layout, reduced motion and serious/critical accessibility findings
- RP-TURN-004 design foundation, localized app shell and quality gates accepted by Project Codex

## Open decisions

- VPS deployment authentication and transport
- Branch protection/ruleset and CI provider/plan details
- GitHub deployment transport, artifact retention and software licensing
- Authentication provider and user identity model
- Windows reverse proxy, Node service supervisor, release switching and monitoring implementation
- Managed PostgreSQL/database placement, object storage and backup placement/ownership
- Payment provider and Thailand-specific billing requirements
- Analytics/monitoring vendors, privacy consent implementation and retention periods
- Assessment question methodology and validation process
- Future content-operations workflow beyond the accepted pilot Git-versioned MDX/metadata baseline
- Exact visual identity, color, typography and Pal character system
- Localization library and translation operations beyond the native Thai-first typed route/catalog contract
- Pilot audience and recruitment method

## Current risks

- Framework scores may look scientifically precise before validation; the UI must communicate their diagnostic nature
- Fear-based acquisition may create short-term conversion but damage trust and learner wellbeing
- Building job matching too early would dilute the learning and proof loop
- Gamification can reward superficial activity unless XP is tied to practice and demonstrated capability
- Self-learning content production may become the largest operational bottleneck
- Assessment, career and employment data will require strong privacy controls
- The scaffold and localized shell prove technical and interaction foundations only; they contain no validated product flow and must not be presented as Milestone 1 user-experience progress
- Current npm audits pass only with reviewed lockfile overrides for vulnerable transitive PostCSS and Sharp versions; future Next.js upgrades must re-evaluate and remove overrides when upstream is safe
- Cloud vendor region, DPA, backup deletion and cost have not been evaluated or accepted
- The Public repository exposes every pushed file and commit to unrestricted readers; inventory, secret/history scanning, synthetic-fixture checks and operational-document review remain mandatory for future pushes

## Next recommended turn

**RP-TURN-005 — Public Narrative and Evidence Contract**

Goal: establish the landing narrative structure with a source-backed evidence-block contract and an honest CTA placeholder after a separate approved turn brief.

RP-TURN-004 is accepted. RP-TURN-005 is the next recommended turn but is not authorized. No landing narrative, assessment, lesson, product feature, CI, database, production service or deployment exists; every later turn, branch-protection/CI change and VPS infrastructure action requires its own approved brief.

## Turn history

| Turn | Status | Outcome |
|---|---|---|
| 000 | Complete | Initialized the Rise Pals project folder and operating documents |
| 001 | Accepted | Architecture/data/plan/local baseline, Public `noppol87/RisePals` decision, first-push security gates and canonical workflow/status/decision/template updates verified |
| 002 | Accepted | Git/Public-GitHub tooling, security review, local `main`, single `origin`, intentional initial commit/push and credential cleanup verified |
| 003 | Accepted | Minimal application scaffold, pinned Node/npm/dependencies, deterministic quality gates and security review accepted by Project Codex |
| 004 | Accepted | Thai-first localized route boundary, semantic responsive app shell, provisional design tokens, accessible primitives and Chromium/axe verification accepted by Project Codex |
