import { cp, mkdtemp, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { afterEach, describe, expect, it } from "vitest";
import {
  PUBLISHED_LESSON_IDENTITY,
  compileContent,
  parseTrustedMdx,
  publishContent,
  validatePublishedContent,
} from "../../scripts/content/pipeline.mjs";

const canonicalContentRoot = join(process.cwd(), "content");
const temporaryRoots: string[] = [];
type MutableJsonObject = Record<string, unknown>;

afterEach(async () => {
  await Promise.all(
    temporaryRoots.splice(0).map((path) => rm(path, { force: true, recursive: true })),
  );
});

async function copyContent(): Promise<string> {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "risepals-content-"));
  temporaryRoots.push(temporaryRoot);
  const contentRoot = join(temporaryRoot, "content");
  await cp(canonicalContentRoot, contentRoot, { recursive: true });
  return contentRoot;
}

function bundlePath(contentRoot: string, relativePath: string): string {
  return join(
    contentRoot,
    "lessons",
    "source-verification-practice",
    "1.0.0",
    ...relativePath.split("/"),
  );
}

async function updateJson(
  contentRoot: string,
  relativePath: string,
  mutate: (value: MutableJsonObject) => void,
): Promise<void> {
  const path = bundlePath(contentRoot, relativePath);
  const value = JSON.parse(await readFile(path, "utf8")) as MutableJsonObject;
  mutate(value);
  await writeFile(path, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function objectAt(value: unknown, path: readonly string[]): MutableJsonObject {
  let current = value;
  for (const key of path) {
    if (current === null || typeof current !== "object" || Array.isArray(current)) {
      throw new Error(`Expected object at ${path.join(".")}.`);
    }
    current = (current as MutableJsonObject)[key];
  }
  if (current === null || typeof current !== "object" || Array.isArray(current)) {
    throw new Error(`Expected object at ${path.join(".")}.`);
  }
  return current as MutableJsonObject;
}

function arrayAt(value: unknown, path: readonly string[]): unknown[] {
  let current = value;
  for (const key of path) {
    if (current === null || typeof current !== "object" || Array.isArray(current)) {
      throw new Error(`Expected object at ${path.join(".")}.`);
    }
    current = (current as MutableJsonObject)[key];
  }
  if (!Array.isArray(current)) throw new Error(`Expected array at ${path.join(".")}.`);
  return current;
}

function setAt(value: MutableJsonObject, path: readonly string[], nextValue: unknown): void {
  const parent = objectAt(value, path.slice(0, -1));
  parent[path.at(-1)!] = nextValue;
}

describe("trusted content publication pipeline", () => {
  it("compiles the canonical bilingual lesson deterministically with pinned source digests", async () => {
    const first = await compileContent();
    const second = await compileContent();

    expect(first).toEqual(second);
    expect(first.lessonCount).toBe(1);
    expect(first.aggregateDigest).toMatch(/^[a-f0-9]{64}$/);
    expect(first.manifestBytes).toBe(second.manifestBytes);
    expect(first.registryBytes).toBe(second.registryBytes);
    expect(first.manifest.lessons).toEqual([
      expect.objectContaining({
        identity: PUBLISHED_LESSON_IDENTITY,
        key: "source-verification-practice",
        version: "1.0.0",
        digest: expect.stringMatching(/^[a-f0-9]{64}$/),
        sourceFiles: expect.arrayContaining([
          expect.objectContaining({
            path: "lessons/source-verification-practice/1.0.0/locales/th/lesson.mdx",
            sha256: expect.stringMatching(/^[a-f0-9]{64}$/),
          }),
        ]),
      }),
    ]);
    const publishedLesson = objectAt(arrayAt(first.registry, ["lessons"])[0], []);
    const renderPlans = objectAt(publishedLesson, ["renderPlans"]);
    for (const locale of ["th", "en"]) {
      expect(arrayAt(renderPlans, [locale]).map((node) => objectAt(node, []).name)).toEqual([
        "Scenario",
        "ConceptList",
        "RubricSummary",
        "PracticeMount",
        "ProofPlaceholder",
        "ReflectionPrompt",
      ]);
    }
    await expect(validatePublishedContent()).resolves.toMatchObject({ lessonCount: 1 });
  });

  it("detects stale generated output without rewriting it", async () => {
    const contentRoot = await copyContent();
    const registryPath = join(contentRoot, "published-lessons.json");
    const stale = `${await readFile(registryPath, "utf8")} `;
    await writeFile(registryPath, stale, "utf8");
    await expect(validatePublishedContent({ contentRoot })).rejects.toThrow(
      "published-lessons.json is stale",
    );
    expect(await readFile(registryPath, "utf8")).toBe(stale);
  });

  it("refuses publication when either immutable tracked output is missing", async () => {
    const contentRoot = await copyContent();
    await rm(join(contentRoot, "publication-manifest.json"));
    await expect(publishContent({ contentRoot })).rejects.toThrow(
      "both tracked publication outputs must exist",
    );
  });

  it("publishes idempotently and leaves byte-identical output", async () => {
    const contentRoot = await copyContent();
    const first = await publishContent({ contentRoot });
    const manifestBefore = await readFile(join(contentRoot, "publication-manifest.json"), "utf8");
    const registryBefore = await readFile(join(contentRoot, "published-lessons.json"), "utf8");
    const second = await publishContent({ contentRoot });

    expect(second.aggregateDigest).toBe(first.aggregateDigest);
    expect(await readFile(join(contentRoot, "publication-manifest.json"), "utf8")).toBe(
      manifestBefore,
    );
    expect(await readFile(join(contentRoot, "published-lessons.json"), "utf8")).toBe(
      registryBefore,
    );
  });

  it("rejects a same-version mutation before changing either published output", async () => {
    const contentRoot = await copyContent();
    const manifestPath = join(contentRoot, "publication-manifest.json");
    const registryPath = join(contentRoot, "published-lessons.json");
    const manifestBefore = await readFile(manifestPath, "utf8");
    const registryBefore = await readFile(registryPath, "utf8");
    await updateJson(contentRoot, "lesson.meta.json", (value) => {
      setAt(value, ["lesson", "estimatedActiveMinutes"], 9);
    });

    await expect(publishContent({ contentRoot })).rejects.toThrow("estimated active minutes");
    expect(await readFile(manifestPath, "utf8")).toBe(manifestBefore);
    expect(await readFile(registryPath, "utf8")).toBe(registryBefore);

    await updateJson(contentRoot, "lesson.meta.json", (value) => {
      setAt(value, ["lesson", "estimatedActiveMinutes"], 8);
      const hero = objectAt(value, ["localized", "en", "hero"]);
      hero.introduction = `${String(hero.introduction)} Changed without a version bump.`;
    });
    await expect(publishContent({ contentRoot })).rejects.toThrow(
      `digest conflict for published lesson ${PUBLISHED_LESSON_IDENTITY}`,
    );
    expect(await readFile(manifestPath, "utf8")).toBe(manifestBefore);
    expect(await readFile(registryPath, "utf8")).toBe(registryBefore);
  });

  it.each([
    ["framework", ["lesson", "frameworkVersionId"], "unknown-framework"],
    ["competency", ["lesson", "targetCompetencyId"], "unknown-competency"],
    ["stage", ["lesson", "targetWorkingStage"], "Leading"],
    ["R.O.I.", ["lesson", "primaryRoiPillar"], "Unknown"],
    ["semantic version", ["lesson", "version"], "v1"],
    ["publication status", ["lesson", "status"], "draft"],
    ["fallback", ["lesson", "localePolicy", "fallback"], "en"],
    ["lesson key", ["lesson", "key"], "unknown-lesson"],
    ["content owner", ["lesson", "contentOwnerRef"], "Not A Stable Reference"],
  ] as const)("rejects invalid %s metadata", async (_label, path, nextValue) => {
    const contentRoot = await copyContent();
    await updateJson(contentRoot, "lesson.meta.json", (value) => setAt(value, path, nextValue));
    await expect(compileContent({ contentRoot })).rejects.toThrow(
      "Content publication validation failed",
    );
  });

  it("rejects missing review metadata", async () => {
    const contentRoot = await copyContent();
    await updateJson(contentRoot, "lesson.meta.json", (value) => {
      delete objectAt(value, ["lesson"]).reviewerRef;
    });
    await expect(compileContent({ contentRoot })).rejects.toThrow("reviewer reference");
  });

  it("rejects non-string, empty and structurally mismatched localized copy", async () => {
    const nonStringRoot = await copyContent();
    await updateJson(nonStringRoot, "lesson.meta.json", (value) => {
      setAt(value, ["localized", "th", "metadata", "title"], 42);
      setAt(value, ["localized", "en", "metadata", "title"], 42);
    });
    await expect(compileContent({ contentRoot: nonStringRoot })).rejects.toThrow(
      "non-string localized copy",
    );

    const emptyRoot = await copyContent();
    await updateJson(emptyRoot, "practice.json", (value) => {
      setAt(value, ["localized", "th", "practice", "heading"], " ");
    });
    await expect(compileContent({ contentRoot: emptyRoot })).rejects.toThrow(
      "empty localized copy",
    );

    const mismatchRoot = await copyContent();
    await updateJson(mismatchRoot, "proof.json", (value) => {
      delete objectAt(value, ["localized", "en", "proof"]).heading;
    });
    await expect(compileContent({ contentRoot: mismatchRoot })).rejects.toThrow(
      "localized structure must match",
    );
  });

  it("rejects missing locales, structural mismatch and duplicate component IDs", async () => {
    const missingLocaleRoot = await copyContent();
    await rm(bundlePath(missingLocaleRoot, "locales/en/lesson.mdx"));
    await expect(compileContent({ contentRoot: missingLocaleRoot })).rejects.toThrow(
      "bundle file inventory",
    );

    const mismatchedRoot = await copyContent();
    const englishPath = bundlePath(mismatchedRoot, "locales/en/lesson.mdx");
    await writeFile(
      englishPath,
      (await readFile(englishPath, "utf8")).replace(
        '<ConceptList id="source-verification-concepts" />',
        '<ConceptList id="source-verification-concepts" />\n\n<ConceptList id="duplicate" />',
      ),
      "utf8",
    );
    await expect(compileContent({ contentRoot: mismatchedRoot })).rejects.toThrow(
      "Thai and English MDX structures",
    );

    expect(() =>
      parseTrustedMdx(
        '<Scenario id="duplicate" sourceId="source" />\n\n<ConceptList id="duplicate" />\n',
      ),
    ).toThrow("duplicate component ID");
  });

  it("rejects broken practice, rubric and proof links and duplicate contract IDs", async () => {
    const cases: Array<[string, string, (value: MutableJsonObject) => void]> = [
      [
        "practice.json",
        "practice rubric",
        (value) => setAt(value, ["practice", "rubricVersionId"], "other"),
      ],
      [
        "rubric.json",
        "rubric practice",
        (value) => setAt(value, ["rubric", "practiceId"], "other"),
      ],
      ["proof.json", "proof ID", (value) => setAt(value, ["proof", "id"], "other-proof")],
      [
        "practice.json",
        "practice option IDs",
        (value) => {
          const options = arrayAt(value, ["practice", "options"]);
          objectAt(options[1], []).id = objectAt(options[0], []).id;
        },
      ],
    ];
    for (const [file, message, mutate] of cases) {
      const contentRoot = await copyContent();
      await updateJson(contentRoot, file, mutate);
      await expect(compileContent({ contentRoot })).rejects.toThrow(message);
    }
  });

  it("rejects incomplete and expired external evidence while preserving explicit synthetic provenance", async () => {
    const canonical = await compileContent();
    expect(JSON.stringify(canonical.registry)).toContain('"sourceClassification":"synthetic"');

    const incompleteRoot = await copyContent();
    await updateJson(incompleteRoot, "sources.json", (value) => {
      const sourceSet = objectAt(value, ["sourceSet"]);
      value.sourceSet = { id: sourceSet.id, classification: "external" };
    });
    await expect(compileContent({ contentRoot: incompleteRoot })).rejects.toThrow(
      "external evidence directUrl",
    );

    const expiredRoot = await copyContent();
    await updateJson(expiredRoot, "sources.json", (value) => {
      const sourceSet = objectAt(value, ["sourceSet"]);
      value.sourceSet = {
        id: sourceSet.id,
        classification: "external",
        directUrl: "https://example.test/direct-source",
        publisher: "Synthetic publisher for rejection testing",
        publicationDate: "2020-01-01",
        geographyContext: "Synthetic test context",
        limitation: "Synthetic test record only",
        lastVerifiedDate: "2020-01-02",
        reviewExpiryDate: "2020-02-01",
      };
    });
    await expect(compileContent({ contentRoot: expiredRoot })).rejects.toThrow(
      "external evidence is expired",
    );
  });

  it.each([
    ["ESM import", 'import value from "./unsafe.js"\n'],
    ["ESM export", "export const value = 1\n"],
    ["flow expression", "{globalThis.__risePalsContentExecuted = true}\n"],
    ["text expression", "A {process.env.CLERK_SECRET_KEY} value\n"],
    ["raw HTML", "<div>unsafe</div>\n"],
    ["unsafe link", "[unsafe](javascript:alert(1))\n"],
    ["scheme-relative link", "[unsafe](//example.test/path)\n"],
    ["encoded traversal link", "[unsafe](/safe/%2e%2e/private)\n"],
    ["image", "![unsafe](https://example.test/image.png)\n"],
    ["unknown component", '<RemoteWidget id="unknown" />\n'],
    ["spread props", "<Scenario {...props} />\n"],
    ["event handler", '<Scenario id="safe" sourceId="source" onClick="run" />\n'],
    ["expression prop", '<Scenario id={process.env.SECRET} sourceId="source" />\n'],
    ["path traversal", '<PracticeMount id="../escape" practiceId="safe" />\n'],
    ["absolute path", '<PracticeMount id="C:/escape" practiceId="safe" />\n'],
  ])("rejects non-declarative or unsafe MDX: %s", (_label, source) => {
    delete (globalThis as Record<string, unknown>).__risePalsContentExecuted;
    expect(() => parseTrustedMdx(source, "unsafe.mdx")).toThrow();
    expect((globalThis as Record<string, unknown>).__risePalsContentExecuted).toBeUndefined();
  });

  it("accepts only the reviewed Markdown and safe-link subset", () => {
    const plan = parseTrustedMdx(
      "## Heading\n\nParagraph with **strong**, *emphasis*, `code`, and [safe](/en).\n\n> Note\n\n- One\n- Two\n",
      "safe.mdx",
    );
    expect(plan.map((node) => node.type)).toEqual(["heading", "paragraph", "blockquote", "list"]);
  });

  it("rejects unsupported files, ambiguous bundle directories and symlinks", async () => {
    const unsupportedRoot = await copyContent();
    await writeFile(bundlePath(unsupportedRoot, "unexpected.txt"), "unexpected\n", "utf8");
    await expect(compileContent({ contentRoot: unsupportedRoot })).rejects.toThrow(
      "bundle file inventory",
    );

    const ambiguousRoot = await copyContent();
    const sourceBundle = bundlePath(ambiguousRoot, "");
    await cp(sourceBundle, join(ambiguousRoot, "lessons", "other-key", "1.0.0"), {
      recursive: true,
    });
    await expect(compileContent({ contentRoot: ambiguousRoot })).rejects.toThrow(
      "bundle lesson key directory",
    );

    const symlinkRoot = await copyContent();
    const localeDirectory = join(
      symlinkRoot,
      "lessons",
      "source-verification-practice",
      "1.0.0",
      "locales",
      "en",
    );
    const targetDirectory = join(symlinkRoot, "symlink-target");
    await cp(localeDirectory, targetDirectory, { recursive: true });
    await rm(localeDirectory, { recursive: true });
    await symlink(targetDirectory, localeDirectory, "junction");
    await expect(compileContent({ contentRoot: symlinkRoot })).rejects.toThrow(
      "symlinks are prohibited",
    );
  });
});
