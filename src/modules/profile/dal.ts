import "server-only";
import type { IdentityProvider } from "@/modules/identity/contract";
import { createClerkDevelopmentIdentityProvider } from "@/modules/identity/providers/clerk/server";
import {
  withAuthorizedUserTransaction,
  type AuthorizationFailureReason,
} from "@/modules/account/authorization";
import {
  isConsentDecision,
  MEASUREMENT_CONSENT_PURPOSE,
  MEASUREMENT_NOTICE_VERSION,
  measurementNoticeProofDigest,
  PRIVACY_NOTICE_VERSION,
  privacyNoticeProofDigest,
  SERVICE_DATA_PURPOSE,
  type ConsentDecision,
} from "@/modules/consent/notice";
import { parseProfileInput, type ClientSafeProfile, type ProfileInput } from "./validation";
import { isLocale, type Locale } from "@/lib/i18n/config";

export type ClientSafeConsent = Readonly<{
  decision: ConsentDecision | null;
  noticeVersion: typeof PRIVACY_NOTICE_VERSION;
}>;

export type ClientSafeMeasurementConsent = Readonly<{
  status: "not-set" | "granted" | "declined" | "withdrawn" | "stale";
  noticeVersion: typeof MEASUREMENT_NOTICE_VERSION;
}>;

export type ProfilePageState =
  | Readonly<{ state: "denied"; reason: AuthorizationFailureReason }>
  | Readonly<{
      state: "ready";
      profile: ClientSafeProfile | null;
      consent: ClientSafeConsent;
      measurementConsent: ClientSafeMeasurementConsent;
    }>;

type ProfileRow = Readonly<{
  preferred_locale: unknown;
  timezone: unknown;
  role_family: unknown;
  function: unknown;
  experience_band: unknown;
  goals: unknown;
  profile_schema_version: unknown;
  onboarding_completed_at: unknown;
}>;

function clientSafeProfile(row: ProfileRow): ClientSafeProfile {
  const profile = parseProfileInput({
    preferredLocale: row.preferred_locale,
    timezone: row.timezone,
    roleFamily: row.role_family,
    function: row.function,
    experienceBand: row.experience_band,
    goals: row.goals,
    profileSchemaVersion: row.profile_schema_version,
  });

  return { ...profile, onboardingComplete: row.onboarding_completed_at instanceof Date };
}

export async function loadProfilePageState(
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
): Promise<ProfilePageState> {
  const result = await withAuthorizedUserTransaction(identityProvider, async (client) => {
    const [profileResult, consentResult, measurementConsentResult] = await Promise.all([
      client.query<ProfileRow>(
        `SELECT preferred_locale, timezone, role_family, function, experience_band,
                goals, profile_schema_version, onboarding_completed_at
         FROM user_profiles`,
      ),
      client.query<{ decision: unknown }>(
        `SELECT decision
         FROM consent_records
         WHERE purpose_code = $1 AND notice_version = $2
         ORDER BY occurred_at DESC, id DESC
         LIMIT 1`,
        [SERVICE_DATA_PURPOSE, PRIVACY_NOTICE_VERSION],
      ),
      client.query<{ decision: unknown; notice_version: unknown; proof_digest: unknown }>(
        `SELECT decision, notice_version, proof_digest
         FROM consent_records
         WHERE purpose_code = $1
         ORDER BY occurred_at DESC, id DESC
         LIMIT 1`,
        [MEASUREMENT_CONSENT_PURPOSE],
      ),
    ]);
    const consentDecision = consentResult.rows[0]?.decision;
    const measurementRow = measurementConsentResult.rows[0];
    const measurementDecision = measurementRow?.decision;
    const measurementStatus =
      measurementRow === undefined
        ? "not-set"
        : measurementRow.notice_version !== MEASUREMENT_NOTICE_VERSION ||
            measurementRow.proof_digest !== measurementNoticeProofDigest ||
            !isConsentDecision(measurementDecision)
          ? "stale"
          : measurementDecision;

    return {
      profile: profileResult.rows[0] ? clientSafeProfile(profileResult.rows[0]) : null,
      consent: {
        decision: isConsentDecision(consentDecision) ? consentDecision : null,
        noticeVersion: PRIVACY_NOTICE_VERSION,
      },
      measurementConsent: {
        status: measurementStatus,
        noticeVersion: MEASUREMENT_NOTICE_VERSION,
      },
    } as const;
  });

  return result.state === "authorized"
    ? { state: "ready", ...result.value }
    : { state: "denied", reason: result.reason };
}

export async function appendMeasurementConsentReceipt(
  decision: ConsentDecision,
  locale: Locale,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
) {
  if (!isConsentDecision(decision) || !isLocale(locale)) {
    throw new Error("Measurement consent input is invalid.");
  }

  return withAuthorizedUserTransaction(identityProvider, async (client, userId) => {
    await client.query(`SELECT id FROM user_accounts WHERE id = $1 FOR UPDATE`, [userId]);
    await client.query(
      `INSERT INTO consent_records
        (user_id, purpose_code, notice_version, decision, occurred_at, locale,
         source_surface, proof_digest)
       VALUES ($1, $2, $3, $4, clock_timestamp(), $5, 'profile-measurement-v1', $6)`,
      [
        userId,
        MEASUREMENT_CONSENT_PURPOSE,
        MEASUREMENT_NOTICE_VERSION,
        decision,
        locale,
        measurementNoticeProofDigest,
      ],
    );
    return { decision } as const;
  });
}

export async function appendConsentReceipt(
  decision: ConsentDecision,
  locale: Locale,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
) {
  if (!isConsentDecision(decision) || !isLocale(locale)) {
    throw new Error("Consent input is invalid.");
  }

  return withAuthorizedUserTransaction(identityProvider, async (client, userId) => {
    await client.query(`SELECT id FROM user_accounts WHERE id = $1 FOR UPDATE`, [userId]);
    await client.query(
      `INSERT INTO consent_records
        (user_id, purpose_code, notice_version, decision, occurred_at, locale,
         source_surface, proof_digest)
       VALUES ($1, $2, $3, $4, clock_timestamp(), $5, 'profile-onboarding-v1', $6)`,
      [
        userId,
        SERVICE_DATA_PURPOSE,
        PRIVACY_NOTICE_VERSION,
        decision,
        locale,
        privacyNoticeProofDigest,
      ],
    );

    return { decision } as const;
  });
}

export async function saveProfile(
  rawInput: FormData | Readonly<Record<string, unknown>>,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
) {
  const input: ProfileInput = parseProfileInput(rawInput);

  return withAuthorizedUserTransaction(identityProvider, async (client, userId) => {
    await client.query(`SELECT id FROM user_accounts WHERE id = $1 FOR UPDATE`, [userId]);
    const consent = await client.query<{ decision: unknown }>(
      `SELECT decision
       FROM consent_records
       WHERE purpose_code = $1 AND notice_version = $2
       ORDER BY occurred_at DESC, id DESC
       LIMIT 1`,
      [SERVICE_DATA_PURPOSE, PRIVACY_NOTICE_VERSION],
    );

    if (consent.rows[0]?.decision !== "granted") {
      throw new Error("Current service-data consent is required before saving a profile.");
    }

    await client.query(
      `INSERT INTO user_profiles
        (user_id, preferred_locale, timezone, role_family, function, experience_band,
         goals, onboarding_completed_at, profile_schema_version, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7::text[], now(), $8, now())
       ON CONFLICT (user_id) DO UPDATE SET
         preferred_locale = EXCLUDED.preferred_locale,
         timezone = EXCLUDED.timezone,
         role_family = EXCLUDED.role_family,
         function = EXCLUDED.function,
         experience_band = EXCLUDED.experience_band,
         goals = EXCLUDED.goals,
         onboarding_completed_at = EXCLUDED.onboarding_completed_at,
         profile_schema_version = EXCLUDED.profile_schema_version,
         updated_at = now()`,
      [
        userId,
        input.preferredLocale,
        input.timezone,
        input.roleFamily,
        input.function,
        input.experienceBand,
        input.goals,
        input.profileSchemaVersion,
      ],
    );

    return { ...input, onboardingComplete: true } satisfies ClientSafeProfile;
  });
}
