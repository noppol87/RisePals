import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { access, rm } from "node:fs/promises";
import net from "node:net";
import { setTimeout as delay } from "node:timers/promises";
import { createClerkClient } from "@clerk/backend";
import { chromium } from "@playwright/test";
import pg from "pg";

const { Pool } = pg;
const publishableKey = process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY?.trim();
const secretKey = process.env.CLERK_SECRET_KEY?.trim();
const inspectionUrl = process.env.RISE_PALS_DISPOSABLE_BOOTSTRAP_URL;
const smokeBuildDirectory = ".next-clerk-development-smoke";
const profileValues = [
  "individual-contributor",
  "technology-data",
  "mid",
  "Asia/Bangkok",
  "adapt-to-change",
];

if (!publishableKey?.startsWith("pk_test_") || !secretKey?.startsWith("sk_test_")) {
  throw new Error("The real-provider smoke requires one complete Clerk Development key pair.");
}
if (!inspectionUrl || !process.env.DATABASE_URL || !process.env.DATABASE_MIGRATION_URL) {
  throw new Error("The real-provider smoke requires the disposable PostgreSQL environment.");
}

const syntheticEmail = `risepals-smoke-${randomUUID().replaceAll("-", "")}+clerk_test@example.com`;
const frontendHost = Buffer.from(publishableKey.slice("pk_test_".length), "base64")
  .toString("utf8")
  .replace(/\$$/, "");
const clerk = createClerkClient({
  publishableKey,
  secretKey,
  telemetry: { disabled: true },
});
const inspectionPool = new Pool({ connectionString: inspectionUrl, max: 1 });
const childOutput = [];
const browserMessages = [];
const applicationRequestUrls = [];
const applicationJsonResponses = [];
let server;
let browser;
let context;
let testingToken;
let providerUserId;
let internalUserId;
let syntheticIdentityCreated = false;
let syntheticIdentityDeleted = false;
let smokePassed = false;

function redactDiagnostic(value) {
  let message = value instanceof Error ? value.message : String(value);
  for (const secret of [
    publishableKey,
    secretKey,
    syntheticEmail,
    providerUserId,
    internalUserId,
  ]) {
    if (secret) message = message.replaceAll(secret, "[REDACTED]");
  }
  for (const profileValue of profileValues)
    message = message.replaceAll(profileValue, "[REDACTED]");
  return message
    .replaceAll(/\b(?:pk|sk)_test(?:_[A-Za-z0-9_-]+)?\b/g, "[REDACTED]")
    .replaceAll(/\b(?:user|sess|client|ins)_[A-Za-z0-9_-]+\b/g, "[REDACTED_IDENTIFIER]")
    .replaceAll(/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g, "[REDACTED_TOKEN]")
    .replaceAll(/\b[a-z0-9-]+\.clerk\.accounts\.dev\b/g, "[REDACTED_PROVIDER_HOST]")
    .replaceAll(/"x-clerk-request-data":"[^"]+"/g, '"x-clerk-request-data":"[REDACTED]"');
}

async function reservePort() {
  const listener = net.createServer();
  await new Promise((resolvePromise, reject) => {
    listener.once("error", reject);
    listener.listen(0, "127.0.0.1", resolvePromise);
  });
  const address = listener.address();
  assert(address && typeof address === "object");
  const { port } = address;
  await new Promise((resolvePromise, reject) =>
    listener.close((error) => (error ? reject(error) : resolvePromise())),
  );
  return port;
}

function capture(stream, label) {
  stream.setEncoding("utf8");
  stream.on("data", (chunk) => {
    childOutput.push(`${label}:${chunk}`);
    if (childOutput.join("").length > 2_000_000) childOutput.shift();
  });
}

async function createSmokeProductionBuild() {
  await rm(smokeBuildDirectory, { force: true, recursive: true });
  const build = spawn(process.execPath, ["node_modules/next/dist/bin/next", "build"], {
    cwd: process.cwd(),
    env: {
      ...process.env,
      CLERK_TELEMETRY_DISABLED: "true",
      NEXT_PUBLIC_CLERK_TELEMETRY_DISABLED: "true",
      RISE_PALS_CLERK_DEVELOPMENT_SMOKE: "true",
    },
    stdio: ["ignore", "pipe", "pipe"],
    windowsHide: true,
  });
  capture(build.stdout, "build:stdout");
  capture(build.stderr, "build:stderr");
  const result = await new Promise((resolvePromise, reject) => {
    build.once("error", reject);
    build.once("exit", (code, signal) => resolvePromise({ code, signal }));
  });
  if (result.signal || result.code !== 0) {
    throw new Error("The Clerk Development smoke production build failed.");
  }
  await access(`${smokeBuildDirectory}/BUILD_ID`);
}

async function waitForServer(port) {
  for (let attempt = 0; attempt < 120; attempt += 1) {
    if (server.exitCode !== null) {
      throw new Error("The production server exited before smoke verification.");
    }
    try {
      await new Promise((resolvePromise, reject) => {
        const socket = net.createConnection({ host: "localhost", port });
        socket.setTimeout(1_000);
        socket.once("connect", () => {
          socket.destroy();
          resolvePromise();
        });
        socket.once("error", (error) => {
          socket.destroy();
          reject(error);
        });
        socket.once("timeout", () => {
          socket.destroy();
          reject(new Error("The production server socket timed out."));
        });
      });
      return;
    } catch {
      await delay(250);
    }
  }
  throw new Error("The production server did not become ready.");
}

async function listSyntheticUsers() {
  const result = await clerk.users.getUserList({ emailAddress: [syntheticEmail], limit: 10 });
  return result.data;
}

async function deleteSyntheticIdentity() {
  const users = await listSyntheticUsers();
  for (const user of users) await clerk.users.deleteUser(user.id);
  const remaining = await listSyntheticUsers();
  assert.equal(remaining.length, 0, "the synthetic Clerk identity must be deleted");
  if (syntheticIdentityCreated) syntheticIdentityDeleted = true;
}

async function databaseState() {
  const result = await inspectionPool.query(
    `SELECT
       (SELECT count(*)::integer FROM user_accounts) AS account_count,
       (SELECT count(*)::integer FROM external_identities WHERE provider = 'clerk') AS identity_count,
       (SELECT count(*)::integer FROM consent_records) AS consent_count,
       (SELECT count(*)::integer FROM user_profiles) AS profile_count,
       (SELECT user_id::text FROM external_identities WHERE provider = 'clerk' LIMIT 1) AS internal_user_id,
       (SELECT provider_subject FROM external_identities WHERE provider = 'clerk' LIMIT 1) AS provider_subject,
       (SELECT count(*)::integer FROM user_accounts AS row_data
        WHERE strpos(to_jsonb(row_data)::text, $1) > 0) +
       (SELECT count(*)::integer FROM external_identities AS row_data
        WHERE strpos(to_jsonb(row_data)::text, $1) > 0) +
       (SELECT count(*)::integer FROM consent_records AS row_data
        WHERE strpos(to_jsonb(row_data)::text, $1) > 0) +
       (SELECT count(*)::integer FROM user_profiles AS row_data
        WHERE strpos(to_jsonb(row_data)::text, $1) > 0) AS email_copy_count`,
    [syntheticEmail],
  );
  return result.rows[0];
}

async function assertSingleMapping(expectedInternalUserId) {
  const state = await databaseState();
  assert.equal(state.account_count, 1, "exactly one internal account must exist");
  assert.equal(state.identity_count, 1, "exactly one Clerk mapping must exist");
  assert.equal(state.email_copy_count, 0, "Rise Pals PostgreSQL must not copy the email");
  assert.equal(
    state.provider_subject,
    providerUserId,
    "the mapping must use the authenticated subject",
  );
  if (expectedInternalUserId) {
    assert.equal(
      state.internal_user_id,
      expectedInternalUserId,
      "repeat sign-in must reuse the UUID",
    );
  }
  return state.internal_user_id;
}

async function assertEmailCodeOnly(panel) {
  for (const name of ["password", "phoneNumber", "username", "firstName", "lastName"]) {
    assert.equal(
      await panel.locator(`input[name="${name}"]`).count(),
      0,
      `${name} must be disabled`,
    );
  }
  assert.equal(
    await panel.locator(".cl-socialButtonsBlockButton").count(),
    0,
    "social sign-in disabled",
  );
}

async function submitEmailCode(page, kind, locale, returnTarget, expectedPath) {
  const route = kind === "sign-up" ? "sign-up" : "sign-in";
  const rootSelector = kind === "sign-up" ? ".cl-signUp-root" : ".cl-signIn-root";
  await page.goto(`${baseUrl}/${locale}/${route}?returnTo=${encodeURIComponent(returnTarget)}`);
  const panel = page.locator(rootSelector);
  await panel.waitFor();
  const localizedText = await panel.innerText();
  if (locale === "th") {
    assert.match(localizedText, /[\u0E00-\u0E7F]/, "the Clerk component must render Thai");
  } else {
    assert.match(localizedText, /[A-Za-z]/, "the Clerk component must render English");
  }
  await assertEmailCodeOnly(panel);

  const emailInput = panel.locator('input[name="emailAddress"], input[name="identifier"]').first();
  await emailInput.fill(syntheticEmail);
  await panel.locator(".cl-formButtonPrimary").click();

  const codeInput = panel.locator('input[inputmode="numeric"], input[name="code"]').first();
  try {
    await codeInput.waitFor({ state: "visible" });
  } catch (error) {
    throw new Error(`Clerk did not present the email-code step: ${await panel.innerText()}`, {
      cause: error,
    });
  }
  await codeInput.click();
  await page.keyboard.type("424242", { delay: 100 });
  await page.waitForURL((url) => url.origin === baseUrl && url.pathname === expectedPath, {
    timeout: 30_000,
  });
}

async function signOut(page, locale) {
  await page
    .getByRole("button", { name: locale === "th" ? "ออกจากระบบ" : "Sign out", exact: true })
    .click();
  await page.waitForURL((url) => url.origin === baseUrl && url.pathname === `/${locale}`);
}

function assertNoSensitiveValue(haystack, label, extraValues = []) {
  const values = [
    syntheticEmail,
    providerUserId,
    internalUserId,
    secretKey,
    ...profileValues,
    ...extraValues,
  ];
  for (const value of values) {
    if (value)
      assert.equal(haystack.includes(value), false, `${label} must not contain sensitive data`);
  }
  assert.doesNotMatch(haystack, /\bsk_test_[A-Za-z0-9_-]+\b/, `${label} must not contain a key`);
  assert.doesNotMatch(
    haystack,
    /\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/,
    `${label} must not contain a session token`,
  );
}

async function verifyBrowserPrivacy(page) {
  const storage = await page.evaluate(() => ({
    local: Object.fromEntries(Object.entries(localStorage)),
    session: Object.fromEntries(Object.entries(sessionStorage)),
  }));
  const tokenParameterNames = new Set();
  for (const requestUrl of applicationRequestUrls) {
    for (const [name, value] of new URL(requestUrl).searchParams) {
      if (/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/.test(value)) {
        tokenParameterNames.add(name);
      }
    }
  }
  assert.deepEqual(
    [...tokenParameterNames].sort(),
    ["__clerk_handshake"],
    `unexpected application URL JWT parameter names: ${JSON.stringify(
      [...tokenParameterNames].sort(),
    )}`,
  );
  const applicationUrlsWithoutHandshakeValues = applicationRequestUrls.map((requestUrl) => {
    const url = new URL(requestUrl);
    if (url.searchParams.has("__clerk_handshake")) {
      url.searchParams.set("__clerk_handshake", "[TRANSIENT_CLERK_DEVELOPMENT_HANDSHAKE]");
    }
    return url.toString();
  });
  const finalLocation = await page.evaluate(() => ({
    search: location.search,
    hash: location.hash,
  }));
  assert.deepEqual(finalLocation, { search: "", hash: "" }, "the final app URL must be clean");
  assertNoSensitiveValue(JSON.stringify(storage), "browser storage");
  assertNoSensitiveValue(applicationUrlsWithoutHandshakeValues.join("\n"), "application URLs");
  assertNoSensitiveValue(applicationJsonResponses.join("\n"), "application JSON responses");
  assertNoSensitiveValue(browserMessages.join("\n"), "browser logs");
  assertNoSensitiveValue(childOutput.join("\n"), "server logs");
}

const port = await reservePort();
const baseUrl = `http://localhost:${port}`;

try {
  await createSmokeProductionBuild();
  const [instance, organizationSettings, frontendResponse] = await Promise.all([
    clerk.instance.get(),
    clerk.instance.getOrganizationSettings(),
    fetch(`https://${frontendHost}/v1/environment?smoke=${Date.now()}`, { cache: "no-store" }),
  ]);
  const frontendEnvironment = await frontendResponse.json();
  const strategies = frontendEnvironment.auth_config?.identification_strategies ?? [];
  const factors = frontendEnvironment.auth_config?.first_factors ?? [];
  assert.equal(instance.environmentType, "development", "only a Development instance is allowed");
  assert.equal(organizationSettings.enabled, false, "Organizations must remain disabled");
  assert.deepEqual(strategies, ["email_address"], "email must be the only identification method");
  assert.equal(factors.includes("email_code"), true, "email code must be enabled");
  assert.equal(factors.includes("password"), false, "password must be disabled");
  assert.equal(
    factors.some((factor) => factor.startsWith("oauth_")),
    false,
    "OAuth disabled",
  );
  assert.deepEqual(
    await listSyntheticUsers(),
    [],
    "the unique synthetic identity must not pre-exist",
  );

  server = spawn(
    process.execPath,
    ["node_modules/next/dist/bin/next", "start", "--hostname", "localhost", "--port", String(port)],
    {
      cwd: process.cwd(),
      env: {
        ...process.env,
        CLERK_TELEMETRY_DISABLED: "true",
        NEXT_PUBLIC_CLERK_TELEMETRY_DISABLED: "true",
        RISE_PALS_CLERK_DEVELOPMENT_SMOKE: "true",
      },
      stdio: ["ignore", "pipe", "pipe"],
      windowsHide: true,
    },
  );
  capture(server.stdout, "server:stdout");
  capture(server.stderr, "server:stderr");
  await waitForServer(port);

  testingToken = await clerk.testingTokens.createTestingToken();
  browser = await chromium.launch({ headless: true });
  context = await browser.newContext();
  await context.route("**/*", async (route) => {
    const requestUrl = new URL(route.request().url());
    if (
      requestUrl.hostname.endsWith(".clerk.accounts.dev") &&
      requestUrl.pathname.includes("/v1/")
    ) {
      requestUrl.searchParams.set("__clerk_testing_token", testingToken.token);
      const response = await route.fetch({ url: requestUrl.toString() });
      if (response.headers()["content-type"]?.includes("application/json")) {
        const payload = await response.json();
        if (payload?.response?.captcha_bypass === false) payload.response.captcha_bypass = true;
        if (payload?.client?.captcha_bypass === false) payload.client.captcha_bypass = true;
        await route.fulfill({ response, json: payload });
      } else {
        await route.fulfill({ response });
      }
      return;
    }
    await route.continue();
  });

  const page = await context.newPage();
  page.on("console", (message) => browserMessages.push(`${message.type()}:${message.text()}`));
  page.on("request", (request) => {
    if (request.url().startsWith(baseUrl)) applicationRequestUrls.push(request.url());
  });
  page.on("response", async (response) => {
    if (
      response.url().startsWith(baseUrl) &&
      response.headers()["content-type"]?.includes("application/json")
    ) {
      applicationJsonResponses.push(await response.text());
    }
  });

  await submitEmailCode(page, "sign-up", "th", "/th/onboarding", "/th/onboarding");
  const users = await listSyntheticUsers();
  assert.equal(users.length, 1, "email-code sign-up must create exactly one synthetic identity");
  syntheticIdentityCreated = true;
  providerUserId = users[0].id;
  internalUserId = await assertSingleMapping();

  await page.locator('form.profile-actions button[value="granted"]').click();
  await page.locator("form.profile-form").waitFor();
  const form = page.locator("form.profile-form");
  await form.locator('select[name="roleFamily"]').selectOption("individual-contributor");
  await form.locator('select[name="function"]').selectOption("technology-data");
  await form.locator('select[name="experienceBand"]').selectOption("mid");
  await form.locator('select[name="timezone"]').selectOption("Asia/Bangkok");
  await form.locator('input[name="goals"][value="adapt-to-change"]').check();
  await form.getByRole("button", { name: "บันทึกโปรไฟล์", exact: true }).click();
  await page.waitForURL((url) => url.origin === baseUrl && url.pathname === "/th/profile");

  const saved = await databaseState();
  assert.equal(saved.consent_count, 1, "one granted consent receipt must exist");
  assert.equal(saved.profile_count, 1, "one controlled profile must exist");
  assert.equal(saved.email_copy_count, 0, "the saved data must not contain the email");

  await signOut(page, "th");
  await page.goto(`${baseUrl}/th/profile`);
  await page.waitForURL((url) => url.origin === baseUrl && url.pathname.startsWith("/th/sign-in"));
  assert.equal(
    await page.locator("form.profile-form").count(),
    0,
    "logout must deny profile access",
  );

  await submitEmailCode(page, "sign-in", "th", "/en/profile", "/th");
  await page.goto(`${baseUrl}/th/profile`);
  await page.locator("form.profile-form").waitFor();
  await assertSingleMapping(internalUserId);

  await signOut(page, "th");
  await submitEmailCode(page, "sign-in", "en", "https://example.org/private", "/en");
  await page.goto(`${baseUrl}/en/profile`);
  await page.locator("form.profile-form").waitFor();
  await assertSingleMapping(internalUserId);
  await verifyBrowserPrivacy(page);

  smokePassed = true;
} catch (error) {
  console.error(`Clerk Development smoke FAIL: ${redactDiagnostic(error)}`);
  const diagnostic = redactDiagnostic(childOutput.slice(-12).join(""));
  if (diagnostic.trim()) console.error(`Redacted server diagnostic:\n${diagnostic}`);
  process.exitCode = 1;
} finally {
  if (context) await context.close().catch(() => undefined);
  if (browser) await browser.close().catch(() => undefined);
  testingToken = undefined;
  await deleteSyntheticIdentity().catch((error) => {
    console.error(`Synthetic identity cleanup FAIL: ${redactDiagnostic(error)}`);
    process.exitCode = 1;
  });
  if (server && server.exitCode === null) {
    server.kill();
    await Promise.race([
      new Promise((resolvePromise) => server.once("exit", resolvePromise)),
      delay(10_000),
    ]);
  }
  await inspectionPool.end();
  await rm(smokeBuildDirectory, { force: true, recursive: true }).catch((error) => {
    console.error(`Temporary smoke build cleanup FAIL: ${redactDiagnostic(error)}`);
    process.exitCode = 1;
  });
}

if (smokePassed && syntheticIdentityCreated && syntheticIdentityDeleted && !process.exitCode) {
  console.log(
    "Clerk Development smoke PASS (localized email-code sign-up/sign-in, one stable internal mapping, consent/profile, logout denial, safe returns, privacy boundaries and verified synthetic identity deletion).",
  );
} else if (!process.exitCode) {
  throw new Error("The Clerk Development smoke did not satisfy its cleanup contract.");
}
