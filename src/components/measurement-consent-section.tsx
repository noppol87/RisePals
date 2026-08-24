import type { ComponentProps } from "react";
import type { Locale } from "@/lib/i18n/config";
import { createMeasurementConsentView } from "@/modules/consent/measurement-view";
import type { ClientSafeMeasurementConsent } from "@/modules/profile/dal";

export function MeasurementConsentSection({
  locale,
  consent,
  formAction,
}: Readonly<{
  locale: Locale;
  consent: ClientSafeMeasurementConsent;
  formAction: ComponentProps<"form">["action"];
}>) {
  const view = createMeasurementConsentView(locale, consent.status);

  return (
    <section className="surface-card profile-panel" aria-labelledby="measurement-consent-heading">
      <h2 id="measurement-consent-heading">{view.heading}</h2>
      <p>{view.summary}</p>
      <p>{view.fields}</p>
      <p>{view.exclusions}</p>
      <p>{view.independence}</p>
      <p>{view.withdrawal}</p>
      <p aria-live="polite">
        <strong>{view.statusLabel}:</strong> {view.status}
      </p>
      <form className="profile-actions" action={formAction}>
        <input type="hidden" name="preferredLocale" value={locale} />
        {view.actions.map((action) => (
          <button
            className={`player-button player-button--${action.decision === "granted" ? "primary" : "quiet"}`}
            name="decision"
            value={action.decision}
            key={action.decision}
          >
            {action.label}
          </button>
        ))}
      </form>
    </section>
  );
}
