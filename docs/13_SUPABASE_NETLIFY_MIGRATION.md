# Supabase + Netlify migration

## Direction and scope

Jeff selected Supabase, Netlify and GitHub on 15 September 2026 and asked to proceed.
This branch starts from GitHub main. The Windows infrastructure branch and old
local copy remain available as history. Product scoring, lesson content, public
demo behavior and synthetic-alpha limits remain intact.

The active identity factory now selects Supabase. Clerk modules remain only as
legacy compatibility code and regression evidence; the application does not mount
Clerk components, use its proxy, or select its provider. Legacy subjects are not
automatically linked to Supabase users by email.

## Local development

Use Node 24.18.1 and npm 11.16.0 (see `.node-version`, `package.json`).

```sh
npm ci
npm run dev
```

The public demo works with no environment file. To enable authentication, set
`SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` in ignored local configuration.
Both are used only by server-side clients; there is no browser Supabase SDK or
browser-readable auth cookie. Database-backed routes additionally need
`DATABASE_URL` for the restricted `rise_pals_app` role.

`RISE_PALS_SECRET_FREE_STANDARD_GATE=true` explicitly disables authentication.
Ordinary `npm run build` and browser regression commands use this mode.
`npm run build:netlify` keeps the deployment configuration instead of blanking it.

## Authentication

- Sign-up explicitly requests account creation; sign-in does not create users.
- Requesting a code returns the same message for unknown emails and API errors.
- Configure the Supabase email template with `{{ .Token }}` for email OTP, not a
  magic-link-only template. Configure rate limits and test email delivery before
  enabling a public sign-up flow. No real email was sent in local regression tests.
- Server Actions validate locale, intent, email and numeric code. Redirects accept
  only same-locale local paths. No token or email appears in return URLs.
- `getUser()` verifies identity with Auth before a database transaction. Anonymous,
  unconfirmed, invalid and unavailable identities cannot access learning data.
- Proxy refresh forwards updated cookies to both the request and response and
  marks protected responses private/no-store. Cookies are HttpOnly, SameSite=Lax,
  and Secure in production. Server Actions fail if session cookies cannot persist.
- Auth credentials and email remain with the Auth provider. Learning tables use
  the existing internal account UUID and explicit provider mapping.
- The new `alpha-privacy-supabase-v2` notice requires a new service consent. Old
  receipts remain immutable. Production region and data policies are not inferred.

Reference: [Supabase SSR clients](https://supabase.com/docs/guides/auth/server-side/creating-a-client).

## Database migrations and initial setup

The eight SQL migrations in `drizzle/` remain byte-for-byte unchanged. The additional
SQL file in `supabase/migrations/` was created by Supabase CLI 2.117.0. It extends
identity resolution for Supabase UUIDs, preserves legacy Clerk mappings, prevents
inactive-account timestamp mutations, enables RLS on definition tables, and denies
`anon`/`authenticated` Data API access. The app continues using server-side `pg`
transactions with `app.current_user_id`, not browser-supplied ownership claims.

**Do not run `supabase db push` against an empty project:** this incremental
migration depends on the legacy schema. The one-time initializer below applies
both ordered migration sets, records their hashes, and seeds only the reviewed
synthetic assessment. Future migrations must respect both recorded histories.

```sh
npm run db:provision          # prints the plan; no connection or mutation
npm run db:provision -- --apply
```

The apply command requires server-side environment variables:

- `SUPABASE_DB_ADMIN_URL`: authenticated direct/session connection for setup,
  with TLS outside loopback; never configure this on Netlify's app runtime.
- `RISE_PALS_APP_DB_PASSWORD`: unique generated password, at least 32 characters.

It refuses any project with existing public tables or Rise Pals roles. It creates
a restricted runtime login, credentialless owner/resolver/privacy roles, applies
all schema changes in one transaction, and revokes temporary resolver membership.
It never drops existing data. Its SQL definition grants assume a dedicated project.
Hosted Supabase permission compatibility still requires an actual hosted run.

Keep the setup credential out of the app. For Netlify runtime use the project's
transaction pooler with username `rise_pals_app.<project-ref>`, the generated app
password and TLS. Copy the endpoint from the project's Connect dialog. Avoid
prepared-statement names; user context stays inside a single transaction. The pool
has one connection per warm instance.

Reference: [Supabase database connections](https://supabase.com/docs/guides/database/connecting-to-postgres).

## Local database verification

Use an installed PostgreSQL binary directory; the commands start an isolated
loopback-only cluster in a temporary directory and remove it after testing.
They never use an existing database or a hosted project.

```sh
RISE_PALS_POSTGRES_BIN=/path/to/postgres/bin npm run db:test:local
RISE_PALS_POSTGRES_BIN=/path/to/postgres/bin npm run db:test:provision
```

The first runs the existing baseline regression and new identity migration tests:
concurrent provisioning, stable internal mapping, invalid UUIDs, owner isolation,
inactive/deleted accounts, resolver privileges and Data API denial. The second
checks initialization of an empty project, all 26 RLS tables, synthetic seed,
runtime-role access and safe refusal to reinitialize.

## Netlify

`netlify.toml` specifies `npm run build:netlify`, publish directory `.next`, and
the pinned Node/npm toolchain. Use Netlify's automatic Next.js/OpenNext adapter.
No Windows service, Caddy, standalone output or SPA wildcard rewrite is required.
Deploy previews default to the secret-free public demo. Runtime context checks also
disable auth for `deploy-preview`/`branch-deploy` unless `RISE_PALS_ALLOW_PREVIEW_AUTH=true`
is explicitly configured. Scope all credentials to the intended environment in
Netlify; `netlify.toml` build variables alone are not a runtime credential boundary.

For the eventual authenticated environment, configure `APP_BASE_URL`,
`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` and the restricted `DATABASE_URL`
in Netlify's appropriate build/function scopes. Do not add migration/admin
credentials. Configure Supabase Site URL and allowed redirects for the exact
environment; do not share a production database with arbitrary PR previews.

Next.js support reference: [Netlify Next.js](https://docs.netlify.com/build/frameworks/framework-setup-guides/nextjs/overview/).

The domain remains at Namecheap. Add the Netlify-provided DNS records after a
working deployment is verified; preserve any unrelated mail records. No DNS
values are guessed or changed by this branch.

## Dependency maintenance

The original install reported 5 advisories including a critical Next.js issue.
Targeted updates use Next.js/eslint-config-next 16.3.5, Sharp 0.35.4,
Vitest 4.1.11, @types/node 24.13.4 and patched transitive js-yaml. The lockfile
records the resolution. A small declaration file supplies Node 24 URLPattern
types required by Next 16.3 while retaining TypeScript 5.9's strict library checks.

References: [Next.js image advisory](https://github.com/advisories/GHSA-2xp9-vwfh-vxw4),
[Sharp advisory](https://github.com/advisories/GHSA-rgj7-g3m4-5g8c).

## Changed-file map

- `src/modules/identity/providers/supabase/`: server client, provider, cookie
  refresh, configuration, email-code actions and bilingual form.
- `src/modules/identity/contract.ts`, `src/modules/account/authorization.ts` and
  module DAL files: verified Supabase identity and internal account resolution.
- Auth pages, locale layout, profile consent and `src/proxy.ts`: active provider
  wiring; `src/modules/consent/notice.ts`: versioned consent disclosure.
- `supabase/migrations/20260915014119_supabase_identity.sql`: additional database
  policies and private resolver. `scripts/db/`: initialization and local tests.
- `netlify.toml`, `.env.example`, package files and TypeScript/ESLint settings:
  deployment, patched dependencies, and generated-build exclusions.
- `tests/`: Supabase identity, actions, form, proxy and regression coverage.
- `README.md`, `PROJECT_STATUS.md`, `AGENTS.md` and this guide: current direction,
  evidence and operating instructions; historical product records are retained.

## Verification record — 15 September 2026

Verified with Node 24.18.1 / npm 11.16.0 on macOS, PostgreSQL 16.13 and
Playwright Chromium 151.0.7922.34:

| Command / check | Result |
| --- | --- |
| `npm run format:check` | PASS |
| `npm run lint` | PASS, including after Netlify generated its output |
| `npm run typecheck` | PASS, both application and database configurations |
| `npm test` | PASS: 46 files, 416 tests |
| `RISE_PALS_POSTGRES_BIN=/opt/homebrew/opt/postgresql@16/bin npm run db:test:local` | PASS: 8 baseline migrations / 407 statements / 26 tables, then Supabase concurrency, isolation and privilege checks |
| `RISE_PALS_POSTGRES_BIN=/opt/homebrew/opt/postgresql@16/bin npm run db:test:provision` | PASS: clean initialization, 26 RLS tables, synthetic seed, restricted runtime and refusal to overwrite |
| `npx --yes netlify-cli@27.6.0 build --offline --context deploy-preview` | PASS: Next.js build plus server and edge function packaging; Next.js Runtime 5.15.13 |
| `npm run test:e2e` | PASS: 80 browser tests |
| `npm run test:e2e:alpha` | PASS: 6 tests across desktop, 320px and reduced-motion projects |
| `npm audit --omit=dev` | PASS: 0 reported vulnerabilities |
| `git diff --check` | PASS |

An additional browser inspection of the configured email-code form, using a
loopback dummy provider without submitting email, found no horizontal overflow
or serious/critical axe findings in either locale at 320px. This checks form
rendering only; it does not validate live Supabase authentication.

Original migration and content files have no changes. The content digest remains
`d1d73e26afc718fcdc86c2dab54853ddbd488ad171c1c1f81e3d64e2f55c1525`.
Unsupported-locale browser checks receive the expected 404; Next.js also logs
`Internal: NoFallbackError` for those requests. No browser assertion failed.
The first browser run exposed two ambiguous Thai text locators; the final run
uses the specific introductory sentence and passes all 80 cases.

## Remaining hosted work

The Organization "Jeff" is selected. The tool quoted 10 USD/month for a dedicated
RisePals project; explicit approval of that cost is pending. No hosted project,
paid resource, live email identity,
deployment, DNS change or migration of existing real-user data is implied by
local tests. Hosted Auth/email delivery, database privileges/pooling, Netlify
session continuity and domain TLS require verification in the chosen environment.
