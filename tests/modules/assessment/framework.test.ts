import { describe, expect, it } from "vitest";
import { assessmentDefinition, scoringModelDefinition } from "@/modules/assessment/assessment";
import {
  assessmentFramework,
  canonicalCoreWeightBasisPoints,
} from "@/modules/assessment/framework";
import type { FrameworkDefinition } from "@/modules/assessment/types";
import {
  validateAssessmentDomain,
  validateFrameworkDefinition,
} from "@/modules/assessment/validate";

type MutableObject = Record<string, unknown>;

function mutableFramework(): MutableObject {
  return structuredClone(assessmentFramework) as unknown as MutableObject;
}

function arrayField(parent: MutableObject, key: string): MutableObject[] {
  return parent[key] as MutableObject[];
}

describe("assessment framework contract", () => {
  it("uses the exact eight canonical core identities and weights totaling 100 percent", () => {
    expect(
      Object.fromEntries(
        assessmentFramework.coreCompetencies.map((competency) => [
          competency.id,
          competency.weightBasisPoints,
        ]),
      ),
    ).toEqual(canonicalCoreWeightBasisPoints);
    expect(
      assessmentFramework.coreCompetencies.reduce(
        (total, competency) => total + competency.weightBasisPoints,
        0,
      ),
    ).toBe(10_000);
    expect(assessmentFramework.coreCompetencies).toHaveLength(8);
  });

  it("keeps both multipliers structurally separate and unweighted", () => {
    expect(assessmentFramework.multipliers.map((multiplier) => multiplier.id)).toEqual([
      "ownership-thinking",
      "sense-of-urgency",
    ]);
    expect(
      assessmentFramework.multipliers.every(
        (multiplier) => !Reflect.has(multiplier, "weightBasisPoints"),
      ),
    ).toBe(true);
    expect(() =>
      validateAssessmentDomain(assessmentFramework, assessmentDefinition, scoringModelDefinition),
    ).not.toThrow();
  });

  it("rejects a changed canonical core weight", () => {
    const framework = mutableFramework();
    arrayField(framework, "coreCompetencies")[0]!.weightBasisPoints = 1_900;

    expect(() => validateFrameworkDefinition(framework as unknown as FrameworkDefinition)).toThrow(
      "framework.core.critical-thinking-fact-checking.weightBasisPoints must match the canonical framework weight.",
    );
  });

  it("rejects a core weight on a multiplier", () => {
    const framework = mutableFramework();
    arrayField(framework, "multipliers")[0]!.weightBasisPoints = 1_000;

    expect(() => validateFrameworkDefinition(framework as unknown as FrameworkDefinition)).toThrow(
      "framework.multiplier.ownership-thinking must not define a core weight.",
    );
  });

  it("rejects duplicate framework member identities", () => {
    const framework = mutableFramework();
    arrayField(framework, "multipliers")[1]!.id = "ownership-thinking";

    expect(() => validateFrameworkDefinition(framework as unknown as FrameworkDefinition)).toThrow(
      "framework member IDs must contain unique values.",
    );
  });
});
