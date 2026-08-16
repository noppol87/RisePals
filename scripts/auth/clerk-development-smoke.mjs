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
const thirdPartyRequestBodies = [];
const selectedSmokeOptionIds = [];
const resultDigestValues = [];
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
       (SELECT count(*)::integer FROM assessment_sessions) AS session_count,
       (SELECT count(*)::integer FROM assessment_sessions WHERE status = 'submitted')
         AS submitted_session_count,
       (SELECT count(*)::integer FROM assessment_responses) AS response_count,
       (SELECT count(*)::integer FROM assessment_responses WHERE is_active)
         AS active_response_count,
       (SELECT count(*)::integer FROM scoring_runs) AS scoring_run_count,
       (SELECT count(*)::integer FROM competency_scores) AS competency_score_count,
       (SELECT count(*)::integer FROM multiplier_observations) AS multiplier_observation_count,
       (SELECT count(*)::integer FROM score_explanations) AS score_explanation_count,
       (SELECT count(*)::integer FROM priority_recommendations) AS priority_recommendation_count,
       (SELECT run_number FROM scoring_runs ORDER BY run_number DESC LIMIT 1) AS run_number,
       (SELECT run_kind FROM scoring_runs ORDER BY run_number DESC LIMIT 1) AS run_kind,
       (SELECT input_digest FROM scoring_runs ORDER BY run_number DESC LIMIT 1) AS input_digest,
       (SELECT output_digest FROM scoring_runs ORDER BY run_number DESC LIMIT 1) AS output_digest,
       (SELECT array_agg(competency.competency_key ORDER BY competency.display_order)
        FROM competency_scores AS score
        JOIN competency_versions AS competency ON competency.id = score.competency_version_id)
         AS core_keys,
       (SELECT array_agg(competency.competency_key ORDER BY competency.display_order)
        FROM multiplier_observations AS observation
        JOIN competency_versions AS competency ON competency.id = observation.competency_version_id)
         AS multiplier_keys,
       (SELECT competency.competency_key
        FROM priority_recommendations AS priority
        JOIN competency_versions AS competency ON competency.id = priority.competency_version_id
        LIMIT 1) AS priority_key,
       (SELECT user_id::text FROM external_identities WHERE provider = 'clerk' LIMIT 1) AS internal_user_id,
       (SELECT provider_subject FROM external_identities WHERE provider = 'clerk' LIMIT 1) AS provider_subject,
       (SELECT count(*)::integer FROM user_accounts AS row_data
        WHERE strpos(to_jsonb(row_data)::text, $1) > 0) +
       (SELECT count(*)::integer FROM external_identities AS row_data
        WHERE strpos(to_jsonb(row_data)::text, $1) > 0) +
       (SELECT count(*)::integer FROM consent_records AS row_data
        WHERE strpos(to_jsonb(row_data)::text, $1) > 0) +
       (SELECT count(*)::integer FROM user_profiles AS row_data
        WHERE strpos(to_jsonb(row_data)::text, $1) > 0) +
       (SELECT count(*)::integer FROM assessment_sessions AS row_data
        WHERE strpos(to_jsonb(row_data)::text, $1) > 0) +
       (SELECT count(*)::integer FROM assessment_responses AS row_data
        WHERE strpos(to_jsonb(row_data)::text, $1) > 0) +
       (SELECT count(*)::integer FROM scoring_runs AS row_data
        WHERE strpos(to_jsonb(row_data)::text, $1) > 0) +
       (SELECT count(*)::integer FROM competency_scores AS row_data
        WHERE strpos(to_jsonb(row_data)::text, $1) > 0) +
       (SELECT count(*)::integer FROM multiplier_observations AS row_data
        WHERE strpos(to_jsonb(row_data)::text, $1) > 0) +
       (SELECT count(*)::integer FROM score_explanations AS row_data
        WHERE strpos(to_jsonb(row_data)::text, $1) > 0) +
       (SELECT count(*)::integer FROM priority_recommendations AS row_data
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
  assertNoSensitiveValue(JSON.stringify(storage), "browser storage", resultDigestValues);
  assertNoSensitiveValue(
    applicationUrlsWithoutHandshakeValues.join("\n"),
    "application URLs",
    resultDigestValues,
  );
  assertNoSensitiveValue(
    applicationJsonResponses.join("\n"),
    "application JSON responses",
    resultDigestValues,
  );
  assertNoSensitiveValue(browserMessages.join("\n"), "browser logs", resultDigestValues);
  assertNoSensitiveValue(childOutput.join("\n"), "server logs", resultDigestValues);
  for (const selectedOptionId of selectedSmokeOptionIds) {
    assert.equal(
      JSON.stringify(storage).includes(selectedOptionId),
      false,
      "answers stay out of storage",
    );
    assert.equal(
      applicationUrlsWithoutHandshakeValues.join("\n").includes(selectedOptionId),
      false,
      "answers stay out of URLs",
    );
    assert.equal(
      browserMessages.join("\n").includes(selectedOptionId),
      false,
      "answers stay out of browser logs",
    );
    assert.equal(
      childOutput.join("\n").includes(selectedOptionId),
      false,
      "answers stay out of server logs",
    );
    assert.equal(
      thirdPartyRequestBodies.join("\n").includes(selectedOptionId),
      false,
      "answers stay out of third-party requests",
    );
  }
}

function trackPage(page) {
  page.on("console", (message) => browserMessages.push(`${message.type()}:${message.text()}`));
  page.on("request", (request) => {
    if (request.url().startsWith(baseUrl)) applicationRequestUrls.push(request.url());
    else if (request.postData()) thirdPartyRequestBodies.push(request.postData());
  });
  page.on("response", async (response) => {
    if (
      response.url().startsWith(baseUrl) &&
      response.headers()["content-type"]?.includes("application/json")
    ) {
      applicationJsonResponses.push(await response.text());
    }
  });
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
  trackPage(page);

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
  assert.equal(saved.session_count, 0, "profile setup must not create an assessment session");
  assert.equal(saved.email_copy_count, 0, "the saved data must not contain the email");

  await page.goto(`${baseUrl}/th/assessment/attempt`);
  await page.getByRole("button", { name: "เริ่มการตอบแบบบันทึก", exact: true }).click();
  await page.waitForURL(
    (url) => url.origin === baseUrl && url.pathname === "/th/assessment/attempt",
  );
  let attemptForm = page.locator("form.assessment-question-form");
  await attemptForm.waitFor();
  const firstSelectedOption = await attemptForm.getByRole("radio").nth(1).getAttribute("value");
  assert(firstSelectedOption);
  selectedSmokeOptionIds.push(firstSelectedOption);
  await attemptForm.getByRole("radio").nth(1).check();
  await attemptForm.getByRole("button", { name: "บันทึกและไปข้อต่อไป" }).click();
  await page.getByRole("heading", { name: "สถานการณ์ 2 จาก 6" }).waitFor();
  await page.getByRole("button", { name: "ย้อนกลับ", exact: true }).click();
  attemptForm = page.locator("form.assessment-question-form");
  const correctedOption = await attemptForm.getByRole("radio").nth(2).getAttribute("value");
  assert(correctedOption);
  selectedSmokeOptionIds.push(correctedOption);
  await attemptForm.getByRole("radio").nth(2).check();
  await attemptForm.getByRole("button", { name: "บันทึกและไปข้อต่อไป" }).click();
  await page.getByRole("heading", { name: "สถานการณ์ 2 จาก 6" }).waitFor();
  await page.reload();
  await page.getByRole("heading", { name: "สถานการณ์ 2 จาก 6" }).waitFor();

  for (let index = 1; index < 6; index += 1) {
    const form = page.locator("form.assessment-question-form");
    await form.waitFor();
    const selectedOption = await form.getByRole("radio").nth(1).getAttribute("value");
    assert(selectedOption);
    selectedSmokeOptionIds.push(selectedOption);
    await form.getByRole("radio").nth(1).check();
    await form
      .getByRole("button", { name: index === 5 ? "บันทึกและตรวจทาน" : "บันทึกและไปข้อต่อไป" })
      .click();
    if (index < 5) {
      await page.getByRole("heading", { name: `สถานการณ์ ${index + 2} จาก 6` }).waitFor();
    }
  }
  await page.getByRole("heading", { name: "ตรวจทานก่อนส่ง" }).waitFor();
  await page.getByRole("button", { name: "ส่งและล็อกคำตอบดิบ", exact: true }).dblclick();
  await page.getByRole("heading", { name: "เซสชันถูกล็อกเรียบร้อย" }).waitFor();
  await page.reload();
  await page.getByRole("heading", { name: "เซสชันถูกล็อกเรียบร้อย" }).waitFor();
  assert.equal(await page.locator("form.assessment-question-form, input[type=radio]").count(), 0);

  const persisted = await databaseState();
  assert.equal(persisted.session_count, 1, "one persisted assessment session must exist");
  assert.equal(persisted.submitted_session_count, 1, "the persisted session must be submitted");
  assert.equal(persisted.response_count, 7, "one correction must preserve seven raw revisions");
  assert.equal(persisted.active_response_count, 6, "each answered item has one active response");
  assert.equal(
    persisted.email_copy_count,
    0,
    "persisted assessment data must not contain the email",
  );

  await page.getByRole("link", { name: "ไปสร้างผลลัพธ์สังเคราะห์", exact: true }).click();
  await page.getByRole("heading", { name: "พร้อมสร้างผลลัพธ์อย่างชัดเจน" }).waitFor();
  const concurrentPage = await context.newPage();
  trackPage(concurrentPage);
  await concurrentPage.goto(`${baseUrl}/th/assessment/result`);
  await concurrentPage.getByRole("heading", { name: "พร้อมสร้างผลลัพธ์อย่างชัดเจน" }).waitFor();
  await Promise.all([
    page.getByRole("button", { name: "สร้างผลลัพธ์สังเคราะห์", exact: true }).click(),
    concurrentPage.getByRole("button", { name: "สร้างผลลัพธ์สังเคราะห์", exact: true }).click(),
  ]);
  await Promise.all([
    page.getByRole("heading", { name: "สัญญาณทักษะจาก 6 สถานการณ์จำลอง" }).waitFor(),
    concurrentPage.getByRole("heading", { name: "สัญญาณทักษะจาก 6 สถานการณ์จำลอง" }).waitFor(),
  ]);
  await concurrentPage.close();

  assert.equal(
    await page.locator('section[aria-labelledby="persisted-core-heading"] article').count(),
    2,
    "the result must render exactly two assessed core signals",
  );
  assert.equal(
    await page.locator(".example-unassessed-list li").count(),
    6,
    "the result must name exactly six unassessed core competencies",
  );
  assert.equal(
    await page.locator('section[aria-labelledby="persisted-multiplier-heading"] article').count(),
    2,
    "the result must keep exactly two multiplier observations separate",
  );
  await page.getByText("ได้ 3 จาก 4 คะแนนหลักฐาน", { exact: true }).waitFor();
  await page.getByText("ได้ 4 จาก 4 คะแนนหลักฐาน", { exact: true }).waitFor();
  const lessonLink = page.getByRole("link", {
    name: "เปิดบทเรียนต้นแบบการตรวจสอบแหล่งข้อมูล",
    exact: true,
  });
  assert.equal(
    await lessonLink.getAttribute("href"),
    "/th/lessons/source-verification-practice",
    "the bounded Critical Thinking priority may link only to the existing prototype",
  );

  const derived = await databaseState();
  assert.equal(derived.scoring_run_count, 1, "concurrent generation must converge on one run");
  assert.equal(derived.run_number, 1, "normal generation must create run one");
  assert.equal(derived.run_kind, "normal", "browser generation cannot request a re-score");
  assert.equal(derived.competency_score_count, 2, "only two assessed core rows may exist");
  assert.deepEqual(derived.core_keys, ["critical-thinking-fact-checking", "systematic-thinking"]);
  assert.equal(derived.multiplier_observation_count, 2);
  assert.deepEqual(derived.multiplier_keys, ["ownership-thinking", "sense-of-urgency"]);
  assert.equal(derived.score_explanation_count, 6);
  assert.equal(derived.priority_recommendation_count, 1);
  assert.equal(derived.priority_key, "critical-thinking-fact-checking");
  assert.equal(derived.email_copy_count, 0, "derived data must not copy the email");
  assert.match(derived.input_digest, /^[0-9a-f]{64}$/);
  assert.match(derived.output_digest, /^[0-9a-f]{64}$/);
  resultDigestValues.push(derived.input_digest, derived.output_digest);

  await page.reload();
  await page.getByRole("heading", { name: "สัญญาณทักษะจาก 6 สถานการณ์จำลอง" }).waitFor();
  assert.equal(
    (await databaseState()).scoring_run_count,
    1,
    "refresh must restore the current result without creating a run",
  );

  await page.goto(`${baseUrl}/th/profile`);
  await page.locator("form.profile-form").waitFor();
  await signOut(page, "th");
  await page.goto(`${baseUrl}/th/assessment/attempt`);
  await page.waitForURL((url) => url.origin === baseUrl && url.pathname.startsWith("/th/sign-in"));
  assert.equal(await page.locator("form.assessment-question-form").count(), 0);
  await page.goto(`${baseUrl}/th/assessment/result`);
  await page.waitForURL((url) => url.origin === baseUrl && url.pathname.startsWith("/th/sign-in"));
  assert.equal(await page.locator(".persisted-result__card").count(), 0);
  await page.goto(`${baseUrl}/th/profile`);
  await page.waitForURL((url) => url.origin === baseUrl && url.pathname.startsWith("/th/sign-in"));
  assert.equal(
    await page.locator("form.profile-form").count(),
    0,
    "logout must deny profile access",
  );

  await submitEmailCode(page, "sign-in", "th", "/en/profile", "/th");
  await page.goto(`${baseUrl}/th/assessment/attempt`);
  await page.getByRole("heading", { name: "เซสชันถูกล็อกเรียบร้อย" }).waitFor();
  await page.goto(`${baseUrl}/th/assessment/result`);
  await page.getByRole("heading", { name: "สัญญาณทักษะจาก 6 สถานการณ์จำลอง" }).waitFor();
  assert.equal((await databaseState()).scoring_run_count, 1);
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
    "Clerk Development smoke PASS (localized email-code sign-up/sign-in, stable owner mapping and consent/profile; persisted submission; concurrent explicit result generation converging on one run; exact two-core, six-unassessed, separate two-multiplier and bounded priority evidence; refresh/logout/re-auth restoration; safe returns; privacy boundaries; and verified synthetic identity deletion).",
  );
} else if (!process.exitCode) {
  throw new Error("The Clerk Development smoke did not satisfy its cleanup contract.");
}
