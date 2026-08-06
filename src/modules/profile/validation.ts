import { isLocale, type Locale } from "@/lib/i18n/config";
import {
  PROFILE_SCHEMA_VERSION,
  profileVocabulary,
  type ExperienceBand,
  type ProfileGoal,
  type ProfileTimezone,
  type RoleFamily,
  type WorkFunction,
} from "@/modules/profile/vocabulary";

export type ProfileInput = Readonly<{
  preferredLocale: Locale;
  timezone: ProfileTimezone;
  roleFamily: RoleFamily;
  function: WorkFunction;
  experienceBand: ExperienceBand;
  goals: readonly ProfileGoal[];
  profileSchemaVersion: typeof PROFILE_SCHEMA_VERSION;
}>;

export type ClientSafeProfile = ProfileInput & Readonly<{ onboardingComplete: boolean }>;

function isCode<const T extends readonly string[]>(values: T, value: unknown): value is T[number] {
  return typeof value === "string" && values.some((candidate) => candidate === value);
}

function valuesFor(input: FormData | Readonly<Record<string, unknown>>, key: string): unknown[] {
  if (input instanceof FormData) {
    return input.getAll(key);
  }

  const value = input[key];
  return Array.isArray(value) ? value : [value];
}

function firstValue(input: FormData | Readonly<Record<string, unknown>>, key: string): unknown {
  return valuesFor(input, key)[0];
}

export function parseProfileInput(
  input: FormData | Readonly<Record<string, unknown>>,
): ProfileInput {
  const preferredLocale = firstValue(input, "preferredLocale");
  const timezone = firstValue(input, "timezone");
  const roleFamily = firstValue(input, "roleFamily");
  const workFunction = firstValue(input, "function");
  const experienceBand = firstValue(input, "experienceBand");
  const submittedGoals = valuesFor(input, "goals");
  const goals = [...new Set(submittedGoals)];
  const profileSchemaVersion = firstValue(input, "profileSchemaVersion");

  if (
    typeof preferredLocale !== "string" ||
    !isLocale(preferredLocale) ||
    !isCode(profileVocabulary.timezone, timezone) ||
    !isCode(profileVocabulary.roleFamily, roleFamily) ||
    !isCode(profileVocabulary.function, workFunction) ||
    !isCode(profileVocabulary.experienceBand, experienceBand) ||
    profileSchemaVersion !== PROFILE_SCHEMA_VERSION ||
    goals.length < 1 ||
    goals.length > 3 ||
    goals.length !== submittedGoals.length ||
    !goals.every((goal) => isCode(profileVocabulary.goals, goal))
  ) {
    throw new Error("Profile input must use the approved profile-v1 controlled vocabulary.");
  }

  return {
    preferredLocale,
    timezone,
    roleFamily,
    function: workFunction,
    experienceBand,
    goals: goals as ProfileGoal[],
    profileSchemaVersion,
  };
}
