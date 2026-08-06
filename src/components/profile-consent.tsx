import { Stack } from "@/components/primitives/stack";
import type { Locale } from "@/lib/i18n/config";
import { privacyNotice } from "@/modules/consent/notice";
import { ClerkLogoutControl } from "@/modules/identity/providers/clerk/client-boundary";
import type { ProfilePageState } from "@/modules/profile/dal";
import { profileCopy } from "@/modules/profile/copy";
import {
  PROFILE_SCHEMA_VERSION,
  profileVocabulary,
  profileVocabularyLabels,
} from "@/modules/profile/vocabulary";
import { recordConsentAction, saveProfileAction } from "@/app/[locale]/profile/actions";

function SelectField({
  label,
  name,
  options,
  labels,
  value,
}: Readonly<{
  label: string;
  name: string;
  options: readonly string[];
  labels: Readonly<Record<string, string>>;
  value: string | undefined;
}>) {
  return (
    <label className="profile-field">
      <span>{label}</span>
      <select name={name} defaultValue={value ?? options[0]} required>
        {options.map((option) => (
          <option key={option} value={option}>
            {labels[option]}
          </option>
        ))}
      </select>
    </label>
  );
}

export function ProfileConsent({
  locale,
  mode,
  state,
}: Readonly<{ locale: Locale; mode: "onboarding" | "profile"; state: ProfilePageState }>) {
  const copy = profileCopy[locale];

  if (state.state === "denied") {
    if (state.reason === "unavailable") {
      return (
        <section className="surface-card profile-panel">
          <h1>{copy.unavailableHeading}</h1>
          <p>{copy.unavailableBody}</p>
        </section>
      );
    }

    if (
      state.reason === "suspended" ||
      state.reason === "deletion_pending" ||
      state.reason === "deleted"
    ) {
      return (
        <section className="surface-card profile-panel">
          <h1>{copy.accountStateHeading}</h1>
          <p>{copy.accountState[state.reason]}</p>
        </section>
      );
    }

    return null;
  }

  const notice = privacyNotice[locale];
  const labels = profileVocabularyLabels[locale];
  const consentState = state.consent.decision ?? "none";
  const canEditProfile = state.consent.decision === "granted";

  return (
    <Stack className="profile-flow">
      <section className="surface-card profile-panel">
        <p className="eyebrow">{copy.eyebrow}</p>
        <h1>{mode === "onboarding" ? copy.onboardingHeading : copy.profileHeading}</h1>
        <p>{copy.introduction}</p>
        <p className="boundary-note">{copy.provisional}</p>
        <ClerkLogoutControl label={copy.logout} locale={locale} />
      </section>

      <section className="surface-card profile-panel" aria-labelledby="privacy-notice-heading">
        <h2 id="privacy-notice-heading">{notice.heading}</h2>
        <p>{notice.summary}</p>
        <p>{notice.identity}</p>
        <p>{notice.boundary}</p>
        <p>{notice.withdrawal}</p>
        <p>
          <strong>{copy.consentStatus}:</strong> {copy.consentStates[consentState]}
        </p>
        <form className="profile-actions" action={recordConsentAction}>
          <input type="hidden" name="preferredLocale" value={locale} />
          {canEditProfile ? (
            <button
              className="player-button player-button--quiet"
              name="decision"
              value="withdrawn"
            >
              {copy.withdraw}
            </button>
          ) : (
            <>
              <button
                className="player-button player-button--primary"
                name="decision"
                value="granted"
              >
                {copy.grant}
              </button>
              <button
                className="player-button player-button--quiet"
                name="decision"
                value="declined"
              >
                {copy.decline}
              </button>
            </>
          )}
        </form>
        <p className="boundary-note">{copy.withdrawalBoundary}</p>
      </section>

      {canEditProfile ? (
        <section className="surface-card profile-panel" aria-labelledby="profile-fields-heading">
          <h2 id="profile-fields-heading">{copy.profileHeading}</h2>
          <form className="profile-form" action={saveProfileAction}>
            <input type="hidden" name="preferredLocale" value={locale} />
            <input type="hidden" name="profileSchemaVersion" value={PROFILE_SCHEMA_VERSION} />
            <SelectField
              label={copy.roleFamily}
              name="roleFamily"
              options={profileVocabulary.roleFamily}
              labels={labels.roleFamily}
              value={state.profile?.roleFamily}
            />
            <SelectField
              label={copy.function}
              name="function"
              options={profileVocabulary.function}
              labels={labels.function}
              value={state.profile?.function}
            />
            <SelectField
              label={copy.experienceBand}
              name="experienceBand"
              options={profileVocabulary.experienceBand}
              labels={labels.experienceBand}
              value={state.profile?.experienceBand}
            />
            <SelectField
              label={copy.timezone}
              name="timezone"
              options={profileVocabulary.timezone}
              labels={labels.timezone}
              value={state.profile?.timezone}
            />
            <fieldset className="profile-goals">
              <legend>{copy.goals}</legend>
              <p>{copy.goalHint}</p>
              {profileVocabulary.goals.map((goal) => (
                <label key={goal}>
                  <input
                    type="checkbox"
                    name="goals"
                    value={goal}
                    defaultChecked={
                      state.profile?.goals.includes(goal) ?? goal === "adapt-to-change"
                    }
                  />
                  <span>{labels.goals[goal]}</span>
                </label>
              ))}
            </fieldset>
            <button className="player-button player-button--primary" type="submit">
              {copy.save}
            </button>
          </form>
        </section>
      ) : null}
    </Stack>
  );
}
