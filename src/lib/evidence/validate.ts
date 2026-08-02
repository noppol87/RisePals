import {
  localizedEvidenceFields,
  type EvidenceLocaleContent,
  type EvidenceRecord,
} from "@/lib/evidence/model";
import { locales } from "@/lib/i18n/config";

type ValidationOptions = Readonly<{
  publicationDate: string;
  supportedLocales?: readonly string[];
}>;

const sourceFields = ["title", "url", "publisher", "publicationDate"] as const;
const recordFields = ["id", "localized", "source", "dateLastVerified", "reviewDate"] as const;
const rawHtmlPattern = /<\/?[a-z][^>]*>/i;
const stableIdPattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const isoDatePattern = /^\d{4}-\d{2}-\d{2}$/;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requireRecord(value: unknown, path: string): Record<string, unknown> {
  if (!isRecord(value)) {
    throw new Error(`${path} must be an object.`);
  }

  return value;
}

function requireString(value: unknown, path: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`${path} must be a non-blank string.`);
  }

  if (rawHtmlPattern.test(value)) {
    throw new Error(`${path} must not contain raw HTML.`);
  }

  return value;
}

function requireFields(value: Record<string, unknown>, fields: readonly string[], path: string) {
  for (const field of fields) {
    if (!(field in value)) {
      throw new Error(`${path}.${field} is required.`);
    }
  }
}

function requireIsoDate(value: unknown, path: string): string {
  const date = requireString(value, path);

  if (!isoDatePattern.test(date)) {
    throw new Error(`${path} must use a valid YYYY-MM-DD date.`);
  }

  const [yearText, monthText, dayText] = date.split("-");
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  const parsed = new Date(Date.UTC(year, month - 1, day));

  if (
    parsed.getUTCFullYear() !== year ||
    parsed.getUTCMonth() + 1 !== month ||
    parsed.getUTCDate() !== day
  ) {
    throw new Error(`${path} must use a valid YYYY-MM-DD date.`);
  }

  return date;
}

function requireHttpsUrl(value: unknown, path: string): string {
  const urlText = requireString(value, path);
  let parsed: URL;

  try {
    parsed = new URL(urlText);
  } catch {
    throw new Error(`${path} must be a valid absolute HTTPS URL.`);
  }

  if (parsed.protocol !== "https:" || parsed.username || parsed.password) {
    throw new Error(`${path} must be a valid absolute HTTPS URL.`);
  }

  return urlText;
}

function validateLocalizedContent(
  value: Record<string, unknown>,
  path: string,
): EvidenceLocaleContent {
  requireFields(value, localizedEvidenceFields, path);

  const localized = Object.fromEntries(
    localizedEvidenceFields.map((field) => [
      field,
      requireString(value[field], `${path}.${field}`),
    ]),
  );

  return localized as EvidenceLocaleContent;
}

function validateEvidenceRecord(
  value: unknown,
  index: number,
  supportedLocales: readonly string[],
  publicationDate: string,
): EvidenceRecord {
  const path = `evidence[${index}]`;
  const record = requireRecord(value, path);
  requireFields(record, recordFields, path);

  const id = requireString(record.id, `${path}.id`);
  if (!stableIdPattern.test(id)) {
    throw new Error(`${path}.id must be a stable lowercase kebab-case identifier.`);
  }

  const localizedRecord = requireRecord(record.localized, `${path}.localized`);
  const localeKeys = Object.keys(localizedRecord).sort();
  const expectedLocaleKeys = [...supportedLocales].sort();

  if (
    localeKeys.length !== expectedLocaleKeys.length ||
    localeKeys.some((locale, localeIndex) => locale !== expectedLocaleKeys[localeIndex])
  ) {
    throw new Error(
      `${path}.localized must cover exactly these locales: ${expectedLocaleKeys.join(", ")}.`,
    );
  }

  const localized = Object.fromEntries(
    supportedLocales.map((locale) => [
      locale,
      validateLocalizedContent(
        requireRecord(localizedRecord[locale], `${path}.localized.${locale}`),
        `${path}.localized.${locale}`,
      ),
    ]),
  );

  const sourceRecord = requireRecord(record.source, `${path}.source`);
  requireFields(sourceRecord, sourceFields, `${path}.source`);
  const publication = requireIsoDate(
    sourceRecord.publicationDate,
    `${path}.source.publicationDate`,
  );
  const verified = requireIsoDate(record.dateLastVerified, `${path}.dateLastVerified`);
  const review = requireIsoDate(record.reviewDate, `${path}.reviewDate`);

  if (review <= verified) {
    throw new Error(`${path}.reviewDate must be later than dateLastVerified.`);
  }

  if (publicationDate > review) {
    throw new Error(`${path} is past its review date and must not be published.`);
  }

  return {
    id,
    localized,
    source: {
      title: requireString(sourceRecord.title, `${path}.source.title`),
      url: requireHttpsUrl(sourceRecord.url, `${path}.source.url`),
      publisher: requireString(sourceRecord.publisher, `${path}.source.publisher`),
      publicationDate: publication,
    },
    dateLastVerified: verified,
    reviewDate: review,
  } as EvidenceRecord;
}

export function validateEvidenceRecords(
  value: unknown,
  { publicationDate, supportedLocales = locales }: ValidationOptions,
): readonly EvidenceRecord[] {
  requireIsoDate(publicationDate, "publicationDate");

  if (!Array.isArray(value) || value.length === 0) {
    throw new Error("evidence must be a non-empty array.");
  }

  const seenIds = new Set<string>();
  const records = value.map((record, index) => {
    const validated = validateEvidenceRecord(record, index, supportedLocales, publicationDate);

    if (seenIds.has(validated.id)) {
      throw new Error(`evidence contains duplicate ID: ${validated.id}.`);
    }

    seenIds.add(validated.id);
    return validated;
  });

  return records;
}
