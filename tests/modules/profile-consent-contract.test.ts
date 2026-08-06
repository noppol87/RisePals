import { createHash } from "node:crypto";
import { describe, expect, it } from "vitest";
import {
  PRIVACY_NOTICE_VERSION,
  privacyNotice,
  privacyNoticeProofDigest,
  SERVICE_DATA_PURPOSE,
} from "@/modules/consent/notice";
import { safeLocaleReturnPath } from "@/modules/identity/redirects";
import { profileCopy } from "@/modules/profile/copy";
import { parseProfileInput } from "@/modules/profile/validation";
import { PROFILE_SCHEMA_VERSION, profileVocabulary } from "@/modules/profile/vocabulary";

const validProfile = {
  preferredLocale: "th",
  timezone: "Asia/Bangkok",
  roleFamily: "individual-contributor",
  function: "operations",
  experienceBand: "mid",
  goals: ["adapt-to-change", "build-evidence"],
  profileSchemaVersion: PROFILE_SCHEMA_VERSION,
} as const;

describe("profile-v1 and consent contract", () => {
  it("accepts only the versioned controlled profile vocabulary", () => {
    expect(parseProfileInput(validProfile)).toEqual(validProfile);
    expect(profileVocabulary.roleFamily).toContain("other");
    expect(profileVocabulary.function).toContain("other");
    expect(profileVocabulary.goals).toContain("other");
  });

  it.each([
    { input: { ...validProfile, roleFamily: "exact-job-title" } },
    { input: { ...validProfile, goals: [] } },
    { input: { ...validProfile, goals: ["adapt-to-change", "adapt-to-change"] } },
    {
      input: {
        ...validProfile,
        goals: ["adapt-to-change", "build-evidence", "other", "improve-judgement"],
      },
    },
    { input: { ...validProfile, profileSchemaVersion: "profile-v2" } },
  ])("rejects $input", ({ input }) => {
    expect(() => parseProfileInput(input)).toThrow("approved profile-v1 controlled vocabulary");
  });

  it("never accepts prohibited free-text fields into the returned DTO", () => {
    const parsed = parseProfileInput({
      ...validProfile,
      employerName: "Synthetic Employer",
      exactJobTitle: "Synthetic exact title",
      salary: "1",
      nationalIdentifier: "synthetic-id",
      careerConcern: "synthetic free text",
    });

    expect(parsed).toEqual(validProfile);
    for (const prohibited of [
      "employerName",
      "exactJobTitle",
      "salary",
      "nationalIdentifier",
      "careerConcern",
    ]) {
      expect(parsed).not.toHaveProperty(prohibited);
    }
  });

  it("pins a deterministic notice/purpose digest", () => {
    const canonical = {
      schemaVersion: "consent-contract-v1",
      noticeVersion: PRIVACY_NOTICE_VERSION,
      purposeCode: SERVICE_DATA_PURPOSE,
      collectedFields: [
        "preferred_locale",
        "timezone",
        "role_family",
        "function",
        "experience_band",
        "goals",
      ],
      processing: ["profile", "future-learning-state"],
      exclusions: ["analytics", "marketing", "research"],
      identityProvider: "clerk-development",
      identityHostingRegion: "US",
    };
    const independentDigest = createHash("sha256")
      .update(JSON.stringify(canonical), "utf8")
      .digest("hex");

    expect(privacyNoticeProofDigest).toBe(independentDigest);
    expect(privacyNoticeProofDigest).toMatch(/^[0-9a-f]{64}$/);
  });

  it("keeps Thai and English notice/fallback coverage complete and explicit", () => {
    expect(Object.keys(privacyNotice.th)).toEqual(Object.keys(privacyNotice.en));
    expect(Object.keys(profileCopy.th)).toEqual(Object.keys(profileCopy.en));
    expect(privacyNotice.th.summary).toContain("ละเอียดอ่อน");
    expect(privacyNotice.en.summary).toContain("sensitive career data");
    expect(privacyNotice.th.identity).toContain("สหรัฐอเมริกา");
    expect(privacyNotice.en.identity).toContain("United States");
    expect(profileCopy.th.localizationFallback).toContain("ทดลอง");
    expect(profileCopy.en.localizationFallback).toContain("experimental");
  });

  it.each([
    ["/th/profile", "th", "/th/profile"],
    ["/en/onboarding", "en", "/en/onboarding"],
    ["https://attacker.example", "th", "/th"],
    ["//attacker.example", "en", "/en"],
    ["/th/profile?leak=value", "th", "/th"],
    ["/fr/profile", "en", "/en"],
    [null, "th", "/th"],
  ] as const)("normalizes return path %s without open redirects", (input, locale, expected) => {
    expect(safeLocaleReturnPath(input, locale)).toBe(expected);
  });
});
