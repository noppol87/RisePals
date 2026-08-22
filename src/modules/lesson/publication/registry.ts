import "server-only";

import publishedRegistry from "../../../../content/published-lessons.json";
import type { Locale } from "@/lib/i18n/config";
import type { SourceVerificationLessonDefinition } from "@/modules/lesson/source-verification/types";
import { validateSourceVerificationLessonDefinition } from "@/modules/lesson/source-verification/validate";

export const SOURCE_VERIFICATION_PUBLISHED_IDENTITY = "source-verification-practice@1.0.0" as const;

const componentToLocalSection = {
  Scenario: "scenario",
  ConceptList: "concepts",
  RubricSummary: "rubric",
  PracticeMount: "practice",
  ProofPlaceholder: "proof",
  ReflectionPrompt: "reflection",
} as const;

type PublishedComponentName = keyof typeof componentToLocalSection;
type PublishedRegistryEntry = Readonly<{
  identity: string;
  digest: string;
  renderPlans: Readonly<Record<Locale, readonly PublishedRenderNode[]>>;
  definition: SourceVerificationLessonDefinition;
}>;
type PublishedRenderNode = Readonly<{
  type: "component";
  name: PublishedComponentName;
  props: Readonly<Record<string, string>>;
}>;

const entries = publishedRegistry.lessons as unknown as readonly PublishedRegistryEntry[];
const sourceVerificationEntry = requirePublishedEntry(SOURCE_VERIFICATION_PUBLISHED_IDENTITY);

function requirePublishedEntry(identity: string): PublishedRegistryEntry {
  const entry = entries.find((candidate) => candidate.identity === identity);
  if (!entry) {
    throw new Error(`Missing published lesson ${identity}.`);
  }
  return entry;
}

validateSourceVerificationLessonDefinition(sourceVerificationEntry.definition);
for (const locale of ["th", "en"] as const) {
  const plan = sourceVerificationEntry.renderPlans[locale];
  if (!Array.isArray(plan) || plan.length !== Object.keys(componentToLocalSection).length) {
    throw new Error(`Published ${locale} lesson render plan is invalid.`);
  }
  for (const node of plan) {
    if (node.type !== "component" || !(node.name in componentToLocalSection)) {
      throw new Error(`Published ${locale} lesson contains an unmapped render node.`);
    }
  }
}

export const sourceVerificationLessonDefinition = sourceVerificationEntry.definition;

export function getSourceVerificationRenderSections(locale: Locale) {
  return sourceVerificationEntry.renderPlans[locale].map((node) => ({
    component: node.name,
    localSection: componentToLocalSection[node.name],
    id: node.props.id,
  }));
}

export function getSourceVerificationPublicationDigest(): string {
  return sourceVerificationEntry.digest;
}
