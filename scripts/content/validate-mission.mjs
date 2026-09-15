import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
const data = JSON.parse(
  await readFile(
    new URL("../../content/missions/source-verification/2.0.0.json", import.meta.url),
    "utf8",
  ),
);
assert.equal(data.schemaVersion, "rise-pals-guided-mission-v2");
assert.equal(data.version, "2.0.0");
assert.equal(data.status, "local-prototype");
assert.equal(data.validationStatus, "unvalidated");
assert.equal(data.sourceIdentity, "source-verification-practice@1.0.0");
assert.equal(data.cases.length, 2);
const copy = (value) => {
  for (const locale of ["th", "en"])
    assert.ok(typeof value?.[locale] === "string" && value[locale].trim().length > 0);
};
assert.equal(new Set(data.cases.map((c) => c.id)).size, 2);
for (const [index, entry] of data.cases.entries()) {
  assert.equal(entry.mode, index === 0 ? "coached" : "independent");
  for (const key of ["title", "context", "before", "scope", "summaryPrefix"]) copy(entry[key]);
  assert.equal(entry.facts.length, 3);
  for (const fact of entry.facts) {
    for (const key of ["label", "detail"]) copy(fact[key]);
    assert.ok(typeof fact.value === "string");
    assert.ok(fact.amount === null || (Number.isFinite(fact.amount) && fact.amount >= 0));
  }
  assert.deepEqual(
    entry.questions.map((q) => q.id),
    ["claim", "evidence", "rewrite", "action"],
  );
  const ids = new Set();
  for (const question of entry.questions) {
    copy(question.prompt);
    assert.equal(question.options.length, 3);
    assert.equal(question.options.filter((o) => o.correct).length, 1);
    for (const option of question.options) {
      assert.equal(typeof option.correct, "boolean");
      assert.ok(!ids.has(option.id));
      ids.add(option.id);
      copy(option.label);
      copy(option.reason);
    }
  }
  assert.ok(
    new Set(entry.questions.map((q) => q.options.findIndex((o) => o.correct))).size > 1,
    "Correct answers must not all use one position",
  );
}
// The visual facts must continue to match the immutable source pack.
assert.deepEqual(
  data.cases[0].facts.map((f) => f.amount),
  [30, 8, null],
);
assert.deepEqual(
  data.cases[1].facts.map((f) => f.amount),
  [12, 8, 80],
);
console.log(
  "Validated guided mission 2.0.0: two fictional cases, bilingual choices and answer integrity.",
);
