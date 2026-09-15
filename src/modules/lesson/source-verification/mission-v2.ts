import content from "../../../../content/missions/source-verification/2.1.0.json";
import type { Locale } from "@/lib/i18n/config";

type Copy = Readonly<Record<Locale, string>>;
export type MissionOption = Readonly<{ id: string; label: Copy; reason: Copy; correct: boolean }>;
export type MissionCase = Readonly<{
  id: string;
  mode: string;
  title: Copy;
  context: Copy;
  before: Copy;
  facts: readonly Readonly<{
    id: string;
    label: Copy;
    value: string;
    detail: Copy;
    amount: number | null;
  }>[];
  scope: Copy;
  summaryPrefix: Copy;
  questions: readonly Readonly<{ id: string; prompt: Copy; options: readonly MissionOption[] }>[];
}>;
export const sourceVerificationMission = content satisfies { cases: MissionCase[] };

export function evaluateMission(
  mission: MissionCase,
  selections: Readonly<Record<string, string>>,
) {
  const results = mission.questions.map((question) => {
    const selected = question.options.find((option) => option.id === selections[question.id]);
    return { id: question.id, selected, correct: selected?.correct === true };
  });
  return {
    complete: results.every((result) => result.selected !== undefined),
    allCorrect: results.every((result) => result.correct),
    results,
  };
}
