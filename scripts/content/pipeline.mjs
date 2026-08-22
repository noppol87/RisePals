import { createHash } from "node:crypto";
import { lstat, mkdir, readFile, readdir, rename, rm, writeFile } from "node:fs/promises";
import { dirname, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { unified } from "unified";
import remarkMdx from "remark-mdx";
import remarkParse from "remark-parse";

export const CONTENT_SOURCE_SCHEMA_VERSION = "rise-pals-lesson-source-v1";
export const PUBLICATION_SEAL_SCHEMA_VERSION = "rise-pals-publication-seal-v1";
export const PUBLICATION_MANIFEST_SCHEMA_VERSION = "rise-pals-publication-manifest-v1";
export const PUBLISHED_REGISTRY_SCHEMA_VERSION = "rise-pals-published-lessons-v1";
export const PUBLISHED_LESSON_IDENTITY = "source-verification-practice@1.0.0";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const defaultContentRoot = join(repositoryRoot, "content");
const sealFileName = "publication-seal.json";
const manifestFileName = "publication-manifest.json";
const registryFileName = "published-lessons.json";
const sourceFileNames = [
  "lesson.meta.json",
  "locales/en/lesson.mdx",
  "locales/th/lesson.mdx",
  "practice.json",
  "proof.json",
  "rubric.json",
  "sources.json",
];
const requiredLocales = ["th", "en"];
const allowedComponents = new Map([
  ["Scenario", ["id", "sourceId"]],
  ["ConceptList", ["id"]],
  ["PracticeMount", ["id", "practiceId"]],
  ["RubricSummary", ["id", "rubricId"]],
  ["ProofPlaceholder", ["id", "proofId"]],
  ["ReflectionPrompt", ["id", "proofId"]],
]);
const expectedRenderComponents = [
  ["Scenario", "source-verification-scenario"],
  ["ConceptList", "source-verification-concepts"],
  ["RubricSummary", "source-verification-rubric"],
  ["PracticeMount", "source-verification-practice"],
  ["ProofPlaceholder", "source-verification-proof"],
  ["ReflectionPrompt", "source-verification-reflection"],
];
const expectedCriterionIds = ["evidence-traceability", "claim-source-fit", "safe-next-action"];
const expectedProofFieldIds = [
  "claim",
  "source-reference",
  "fit-check",
  "corrected-wording",
  "safe-next-action",
];
const expectedOptionIds = [
  "trace-claim-to-source-map",
  "trace-trust-ai-link-list",
  "trace-remove-source-notes",
  "fit-narrow-to-supported-teams",
  "fit-keep-all-team-claim",
  "fit-convert-to-broad-average",
  "safe-hold-and-resolve-gaps",
  "safe-publish-with-small-note",
  "safe-ask-ai-for-confidence",
];
const rawHtmlPattern = /<\/?(?:script|style|iframe|object|embed|img|[a-z][\w-]*)(?:\s|>|\/)/i;
const semanticVersionPattern = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;
const stableReferencePattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

export async function compileContent({ contentRoot = defaultContentRoot, validationDate = new Date() } = {}) {
  const root = resolve(contentRoot);
  const validationInstant = parseValidationInstant(validationDate);
  const bundleDirectories = await discoverBundleDirectories(root);
  const identities = new Set();
  const compiledLessons = [];

  for (const bundleDirectory of bundleDirectories) {
    const compiled = await compileBundle(root, bundleDirectory, validationInstant);
    if (identities.has(compiled.identity)) {
      fail(`duplicate published lesson identity: ${compiled.identity}.`);
    }
    identities.add(compiled.identity);
    compiledLessons.push(compiled);
  }

  compiledLessons.sort((left, right) => left.identity.localeCompare(right.identity));
  const aggregateDigest = sha256(
    compiledLessons.map(({ identity, digest }) => `${identity}\0${digest}\n`).join(""),
  );
  const manifest = {
    schemaVersion: PUBLICATION_MANIFEST_SCHEMA_VERSION,
    aggregateDigest,
    lessons: compiledLessons.map(({ identity, key, version, digest, sourceFiles }) => ({
      identity,
      key,
      version,
      digest,
      sourceFiles,
    })),
  };
  const registry = {
    schemaVersion: PUBLISHED_REGISTRY_SCHEMA_VERSION,
    aggregateDigest,
    lessons: compiledLessons.map(
      ({ identity, digest, sourceFiles, publication, renderPlans, definition }) => ({
        identity,
        digest,
        sourceFiles,
        publication,
        renderPlans,
        definition,
      }),
    ),
  };

  return {
    aggregateDigest,
    lessonCount: compiledLessons.length,
    manifest,
    manifestBytes: stableJson(manifest),
    registry,
    registryBytes: stableJson(registry),
  };
}

export async function validatePublishedContent({
  contentRoot = defaultContentRoot,
  validationDate = new Date(),
} = {}) {
  const root = resolve(contentRoot);
  const compiled = await compileContent({ contentRoot: root, validationDate });
  const seal = await readPublicationSeal(root);
  const manifestPath = join(root, manifestFileName);
  const registryPath = join(root, registryFileName);
  const currentManifest = await readTrackedOutput(manifestPath, manifestFileName);
  const currentRegistry = await readTrackedOutput(registryPath, registryFileName);

  assertPublicationSealMatchesCompiled(seal, compiled.manifest);
  assertPublishedOutputIntegrity(
    currentManifest,
    compiled.manifest,
    seal,
    PUBLICATION_MANIFEST_SCHEMA_VERSION,
    manifestFileName,
  );
  assertPublishedOutputIntegrity(
    currentRegistry,
    compiled.registry,
    seal,
    PUBLISHED_REGISTRY_SCHEMA_VERSION,
    registryFileName,
  );
  if (currentManifest !== compiled.manifestBytes) {
    fail(`${manifestFileName} is stale; run npm run content:publish.`);
  }
  if (currentRegistry !== compiled.registryBytes) {
    fail(`${registryFileName} is stale; run npm run content:publish.`);
  }

  return compiled;
}

export async function publishContent({
  contentRoot = defaultContentRoot,
  validationDate = new Date(),
} = {}) {
  const root = resolve(contentRoot);
  const compiled = await compileContent({ contentRoot: root, validationDate });
  const seal = await readPublicationSeal(root);
  const manifestPath = join(root, manifestFileName);
  const registryPath = join(root, registryFileName);
  const existingManifest = await readOptionalUtf8(manifestPath);
  const existingRegistry = await readOptionalUtf8(registryPath);

  if (existingManifest === null || existingRegistry === null) {
    fail("both tracked publication outputs must exist before publishing; restore them from Git.");
  }
  assertPublicationSealMatchesCompiled(seal, compiled.manifest);
  assertPublishedOutputIntegrity(
    existingManifest,
    compiled.manifest,
    seal,
    PUBLICATION_MANIFEST_SCHEMA_VERSION,
    manifestFileName,
  );
  assertPublishedOutputIntegrity(
    existingRegistry,
    compiled.registry,
    seal,
    PUBLISHED_REGISTRY_SCHEMA_VERSION,
    registryFileName,
  );

  await atomicWritePair([
    [manifestPath, compiled.manifestBytes],
    [registryPath, compiled.registryBytes],
  ]);
  return compiled;
}

async function discoverBundleDirectories(contentRoot) {
  const lessonsRoot = join(contentRoot, "lessons");
  await assertDirectoryInside(contentRoot, lessonsRoot, "lesson source root");
  const lessonEntries = await sortedDirectoryEntries(lessonsRoot);
  const directories = [];

  for (const lessonEntry of lessonEntries) {
    assertSafePathSegment(lessonEntry.name, "lesson key");
    if (!lessonEntry.isDirectory() || lessonEntry.isSymbolicLink()) {
      fail(`unsupported entry in content/lessons: ${lessonEntry.name}.`);
    }
    const lessonDirectory = join(lessonsRoot, lessonEntry.name);
    for (const versionEntry of await sortedDirectoryEntries(lessonDirectory)) {
      assertSafePathSegment(versionEntry.name, "lesson version");
      if (!versionEntry.isDirectory() || versionEntry.isSymbolicLink()) {
        fail(`unsupported entry in ${slash(relative(contentRoot, lessonDirectory))}.`);
      }
      directories.push(join(lessonDirectory, versionEntry.name));
    }
  }

  if (directories.length === 0) fail("at least one lesson bundle is required.");
  return directories;
}

async function compileBundle(contentRoot, bundleDirectory, validationInstant) {
  await assertNoSymlinks(contentRoot, bundleDirectory);
  const actualFiles = await listRelativeFiles(bundleDirectory);
  assertExactArray(actualFiles, sourceFileNames, "bundle file inventory");

  const sourceFiles = [];
  const sourceText = new Map();
  for (const relativePath of sourceFileNames) {
    const absolutePath = resolveInside(bundleDirectory, relativePath);
    const text = await readStrictSource(absolutePath, relativePath);
    sourceText.set(relativePath, text);
    sourceFiles.push({
      path: slash(relative(contentRoot, absolutePath)),
      sha256: sha256(text),
    });
  }
  sourceFiles.sort((left, right) => left.path.localeCompare(right.path));
  const digest = sha256(sourceFiles.map(({ path, sha256 }) => `${path}\0${sha256}\n`).join(""));

  const metadata = parseJson(sourceText.get("lesson.meta.json"), "lesson.meta.json");
  const practiceSource = parseJson(sourceText.get("practice.json"), "practice.json");
  const rubricSource = parseJson(sourceText.get("rubric.json"), "rubric.json");
  const proofSource = parseJson(sourceText.get("proof.json"), "proof.json");
  const sourcesSource = parseJson(sourceText.get("sources.json"), "sources.json");

  validateMetadata(metadata, bundleDirectory);
  validatePractice(practiceSource);
  validateRubric(rubricSource);
  validateProof(proofSource);
  validateSources(sourcesSource, validationInstant);
  validateCrossReferences(metadata, practiceSource, rubricSource, proofSource, sourcesSource);

  const renderPlans = {};
  for (const locale of requiredLocales) {
    renderPlans[locale] = parseTrustedMdx(
      sourceText.get(`locales/${locale}/lesson.mdx`),
      `${locale}/lesson.mdx`,
    );
  }
  if (structureSignature(renderPlans.th) !== structureSignature(renderPlans.en)) {
    fail("Thai and English MDX structures must match exactly.");
  }
  validateExpectedRenderPlan(renderPlans.th);
  validateExpectedRenderPlan(renderPlans.en);

  const definition = buildDefinition(
    metadata,
    practiceSource,
    rubricSource,
    proofSource,
    sourcesSource,
  );
  const identity = `${metadata.lesson.key}@${metadata.lesson.version}`;
  return {
    identity,
    key: metadata.lesson.key,
    version: metadata.lesson.version,
    digest,
    sourceFiles,
    publication: {
      status: metadata.lesson.status,
      validationStatus: metadata.lesson.validationStatus,
      contentOwnerRef: metadata.lesson.contentOwnerRef,
      reviewerRef: metadata.lesson.reviewerRef,
      contentReviewedAt: metadata.lesson.contentReviewedAt,
      publicationRecordedAt: metadata.lesson.publicationRecordedAt,
      provenance: metadata.lesson.provenance,
      sourceSetId: sourcesSource.sourceSet.id,
      sourceClassification: sourcesSource.sourceSet.classification,
      sourceLimitation: sourcesSource.sourceSet.limitation,
    },
    renderPlans,
    definition,
  };
}

function validateMetadata(value, bundleDirectory) {
  assertObject(value, "lesson metadata");
  assertEqual(value.schemaVersion, CONTENT_SOURCE_SCHEMA_VERSION, "lesson metadata schema");
  assertEqual(value.contractVersionId, "lesson-local-prototype-contract-v1", "lesson contract");
  assertObject(value.lesson, "lesson metadata lesson");
  const lesson = value.lesson;
  assertEqual(lesson.key, "source-verification-practice", "lesson key");
  assertEqual(lesson.versionId, "lesson-source-verification-practice-v1", "lesson version ID");
  assertString(lesson.version, "lesson semantic version");
  if (!semanticVersionPattern.test(lesson.version))
    fail("lesson version must be semantic versioning.");
  assertEqual(lesson.status, "published", "publication status");
  assertEqual(lesson.validationStatus, "prototype-unvalidated", "validation status");
  assertEqual(lesson.frameworkVersionId, "framework-rise-pals-8-plus-2-v2", "framework version");
  assertEqual(lesson.targetCompetencyId, "critical-thinking-fact-checking", "target competency");
  assertEqual(lesson.targetWorkingStage, "Practicing", "working stage");
  assertEqual(lesson.primaryRoiPillar, "Intelligent Risk & Governance", "R.O.I. pillar");
  assertEqual(lesson.practiceId, "source-verification-decision-v1", "practice reference");
  assertEqual(lesson.rubricVersionId, "source-verification-rubric-v1", "rubric reference");
  assertEqual(lesson.proofId, "source-verification-note-placeholder-v1", "proof reference");
  assertEqual(
    lesson.provenance,
    "git-reviewed-content-publication-pipeline",
    "publication provenance",
  );
  assertExactArray(lesson.locales, requiredLocales, "lesson locales");
  assertObject(lesson.localePolicy, "locale policy");
  assertExactArray(lesson.localePolicy.requiredLocales, requiredLocales, "required locales");
  assertEqual(lesson.localePolicy.fallback, "none", "locale fallback policy");
  if (!Number.isInteger(lesson.estimatedActiveMinutes) || lesson.estimatedActiveMinutes !== 8) {
    fail("estimated active minutes must equal 8.");
  }
  assertExactArray(lesson.prerequisites, [], "lesson prerequisites");
  assertStableReference(lesson.contentOwnerRef, "content owner reference");
  assertStableReference(lesson.reviewerRef, "reviewer reference");
  assertTimestamp(lesson.contentReviewedAt, "content review timestamp");
  assertTimestamp(lesson.publicationRecordedAt, "publication timestamp");
  const directoryParts = slash(bundleDirectory).split("/");
  assertEqual(directoryParts.at(-2), lesson.key, "bundle lesson key directory");
  assertEqual(directoryParts.at(-1), lesson.version, "bundle version directory");
  validateLocalizedMap(value.localized, "lesson localized metadata");
  for (const locale of requiredLocales) {
    assertObject(value.localized[locale], `${locale} lesson content`);
    validateStringTree(value.localized[locale], `${locale} lesson content`);
  }
  assertLocalizedParity(value.localized, "lesson localized structure");
  assertObject(value.xpRule, "XP rule");
  assertEqual(value.xpRule.versionId, "source-verification-xp-preview-v1", "XP version");
  assertEqual(value.xpRule.viewingPreviewXp, 0, "viewing XP");
  assertEqual(value.xpRule.incompletePreviewXp, 0, "incomplete XP");
  assertEqual(value.xpRule.demonstratedPreviewXp, 20, "demonstrated XP");
  assertEqual(value.xpRule.accumulation, "replace-not-add", "XP accumulation");
  assertEqual(value.xpRule.persisted, false, "XP persistence");
}

function validatePractice(value) {
  assertObject(value, "practice source");
  assertEqual(value.schemaVersion, "rise-pals-practice-source-v1", "practice schema");
  assertObject(value.practice, "practice");
  const practice = value.practice;
  assertEqual(practice.id, "source-verification-decision-v1", "practice ID");
  assertEqual(practice.version, "1.0.0", "practice version");
  assertEqual(practice.rubricVersionId, "source-verification-rubric-v1", "practice rubric link");
  assertExactArray(practice.criterionIds, expectedCriterionIds, "practice criteria");
  if (!Array.isArray(practice.options) || practice.options.length !== 9) {
    fail("practice must contain exactly nine options.");
  }
  assertUnique(
    practice.options.map((option) => option?.id),
    "practice option IDs",
  );
  assertExactArray(
    practice.options.map((option) => option.id),
    expectedOptionIds,
    "practice option IDs",
  );
  for (const option of practice.options) {
    assertObject(option, "practice option");
    if (!expectedCriterionIds.includes(option.criterionId))
      fail("practice option has unknown criterion.");
    if (typeof option.meetsCriterion !== "boolean") fail("practice option result must be boolean.");
  }
  const optionCounts = expectedCriterionIds.map(
    (criterionId) => practice.options.filter((option) => option.criterionId === criterionId).length,
  );
  assertExactArray(optionCounts, [3, 3, 3], "practice option distribution");
  validateLocalizedMap(value.localized, "localized practice");
  for (const locale of requiredLocales)
    validateStringTree(value.localized[locale], `${locale} practice`);
  assertLocalizedParity(value.localized, "practice localized structure");
}

function validateRubric(value) {
  assertObject(value, "rubric source");
  assertEqual(value.schemaVersion, "rise-pals-rubric-source-v1", "rubric schema");
  assertObject(value.rubric, "rubric");
  const rubric = value.rubric;
  assertEqual(rubric.versionId, "source-verification-rubric-v1", "rubric ID");
  assertEqual(rubric.version, "1.0.0", "rubric version");
  assertEqual(rubric.practiceId, "source-verification-decision-v1", "rubric practice link");
  assertEqual(rubric.demonstratedRequires, "all-criteria-met", "rubric demonstrated rule");
  if (!Array.isArray(rubric.criteria) || rubric.criteria.length !== 3) {
    fail("rubric must contain exactly three criteria.");
  }
  assertUnique(
    rubric.criteria.map((criterion) => criterion?.id),
    "rubric criterion IDs",
  );
  assertExactArray(
    rubric.criteria.map((criterion) => criterion.practiceCriterionId),
    expectedCriterionIds,
    "rubric practice links",
  );
  validateLocalizedMap(value.localized, "localized rubric");
  for (const locale of requiredLocales)
    validateStringTree(value.localized[locale], `${locale} rubric`);
  assertLocalizedParity(value.localized, "rubric localized structure");
}

function validateProof(value) {
  assertObject(value, "proof source");
  assertEqual(value.schemaVersion, "rise-pals-proof-source-v1", "proof schema");
  assertObject(value.proof, "proof");
  const proof = value.proof;
  assertEqual(proof.id, "source-verification-note-placeholder-v1", "proof ID");
  assertEqual(proof.version, "1.0.0", "proof version");
  assertEqual(proof.status, "placeholder", "proof status");
  assertEqual(proof.artifactType, "source-verification-note", "proof artifact type");
  assertExactArray(proof.fieldIds, expectedProofFieldIds, "proof field IDs");
  assertEqual(proof.capturesInput, false, "proof input capture");
  validateLocalizedMap(value.localized, "localized proof");
  for (const locale of requiredLocales)
    validateStringTree(value.localized[locale], `${locale} proof`);
  assertLocalizedParity(value.localized, "proof localized structure");
}

function validateSources(value, validationInstant) {
  assertObject(value, "source records");
  assertEqual(value.schemaVersion, "rise-pals-sources-v1", "source schema");
  assertObject(value.sourceSet, "source set");
  assertStableReference(value.sourceSet.id, "source-set ID");
  assertString(value.sourceSet.classification, "source classification");
  if (value.sourceSet.classification === "synthetic") {
    assertEqual(value.sourceSet.externalEvidence, false, "synthetic external-evidence flag");
    assertString(value.sourceSet.limitation, "synthetic source limitation");
  } else if (value.sourceSet.classification === "external") {
    assertExternalEvidence(value.sourceSet, validationInstant);
  } else {
    fail("source classification must be synthetic or external.");
  }
  validateLocalizedMap(value.localized, "localized sources");
  for (const locale of requiredLocales)
    validateStringTree(value.localized[locale], `${locale} sources`);
  assertLocalizedParity(value.localized, "source localized structure");
  for (const locale of requiredLocales) {
    const records = value.localized[locale]?.sourceRecords;
    if (!Array.isArray(records) || records.length === 0)
      fail(`${locale} source records are required.`);
    assertUnique(
      records.map((record) => record?.id),
      `${locale} source record IDs`,
    );
  }
}

function assertExternalEvidence(sourceSet, validationInstant) {
  for (const key of [
    "directUrl",
    "publisher",
    "publicationDate",
    "geographyContext",
    "limitation",
    "lastVerifiedDate",
    "reviewExpiryDate",
  ]) {
    assertString(sourceSet[key], `external evidence ${key}`);
  }
  let parsedUrl;
  try {
    parsedUrl = new URL(sourceSet.directUrl);
  } catch {
    fail("external evidence URL must be a direct HTTPS URL.");
  }
  if (parsedUrl.protocol !== "https:") fail("external evidence URL must use HTTPS.");
  const expiry = parseDate(sourceSet.reviewExpiryDate, "external evidence review expiry date");
  const publication = parseDate(sourceSet.publicationDate, "external evidence publication date");
  const verified = parseDate(sourceSet.lastVerifiedDate, "external evidence verification date");
  if (verified < publication) fail("external evidence verification cannot predate publication.");
  if (expiry <= verified) {
    fail("external evidence review expiry date must be later than verification date.");
  }
  if (expiry <= validationInstant) fail("external evidence is expired.");
}

function validateCrossReferences(metadata, practice, rubric, proof, sources) {
  assertEqual(metadata.lesson.practiceId, practice.practice.id, "lesson practice reference");
  assertEqual(metadata.lesson.rubricVersionId, rubric.rubric.versionId, "lesson rubric reference");
  assertEqual(metadata.lesson.proofId, proof.proof.id, "lesson proof reference");
  assertEqual(
    practice.practice.rubricVersionId,
    rubric.rubric.versionId,
    "practice rubric reference",
  );
  assertEqual(rubric.rubric.practiceId, practice.practice.id, "rubric practice reference");
  assertEqual(
    sources.sourceSet.id,
    "bright-river-operations-synthetic-source-pack-v1",
    "scenario source reference",
  );
}

function buildDefinition(metadata, practice, rubric, proof, sources) {
  const content = {};
  for (const locale of requiredLocales) {
    content[locale] = {
      locale,
      ...metadata.localized[locale],
      scenario: sources.localized[locale],
      ...practice.localized[locale],
      rubric: rubric.localized[locale],
      ...proof.localized[locale],
    };
  }
  return {
    contractVersionId: metadata.contractVersionId,
    lesson: {
      key: metadata.lesson.key,
      versionId: metadata.lesson.versionId,
      version: metadata.lesson.version,
      status: metadata.lesson.status,
      validationStatus: metadata.lesson.validationStatus,
      frameworkVersionId: metadata.lesson.frameworkVersionId,
      targetCompetencyId: metadata.lesson.targetCompetencyId,
      targetWorkingStage: metadata.lesson.targetWorkingStage,
      primaryRoiPillar: metadata.lesson.primaryRoiPillar,
      estimatedActiveMinutes: metadata.lesson.estimatedActiveMinutes,
      provenance: metadata.lesson.provenance,
      locales: metadata.lesson.locales,
      practiceId: metadata.lesson.practiceId,
      rubricVersionId: metadata.lesson.rubricVersionId,
      proofId: metadata.lesson.proofId,
    },
    practice: practice.practice,
    rubric: rubric.rubric,
    proof: proof.proof,
    xpRule: metadata.xpRule,
    content,
  };
}

export function parseTrustedMdx(source, label = "lesson.mdx") {
  let tree;
  try {
    tree = unified().use(remarkParse).use(remarkMdx).parse(source);
  } catch (error) {
    fail(`${label} is invalid MDX: ${error instanceof Error ? error.message : String(error)}`);
  }
  const componentIds = new Set();
  return normalizeChildren(tree.children, label, componentIds);
}

function normalizeChildren(children, label, componentIds) {
  return children.map((node) => normalizeNode(node, label, componentIds));
}

function normalizeNode(node, label, componentIds) {
  switch (node.type) {
    case "text":
      assertString(node.value, `${label} text`);
      return { type: "text", value: node.value };
    case "paragraph":
    case "strong":
    case "emphasis":
    case "blockquote":
    case "listItem":
      return { type: node.type, children: normalizeChildren(node.children, label, componentIds) };
    case "heading":
      if (node.depth < 2 || node.depth > 4) fail(`${label} headings must use levels 2 through 4.`);
      return {
        type: "heading",
        depth: node.depth,
        children: normalizeChildren(node.children, label, componentIds),
      };
    case "list":
      return {
        type: "list",
        ordered: Boolean(node.ordered),
        children: normalizeChildren(node.children, label, componentIds),
      };
    case "inlineCode":
      assertString(node.value, `${label} inline code`);
      return { type: "inlineCode", value: node.value };
    case "link":
      assertSafeLink(node.url, label);
      return {
        type: "link",
        url: node.url,
        children: normalizeChildren(node.children, label, componentIds),
      };
    case "mdxJsxFlowElement":
      return normalizeComponent(node, label, componentIds);
    case "mdxjsEsm":
      fail(`${label} cannot contain import or export statements.`);
      break;
    case "mdxFlowExpression":
    case "mdxTextExpression":
      fail(`${label} cannot contain JavaScript or MDX expressions.`);
      break;
    case "html":
      fail(`${label} cannot contain raw HTML.`);
      break;
    case "image":
    case "imageReference":
      fail(`${label} cannot contain image nodes.`);
      break;
    default:
      fail(`${label} contains unsupported node type ${node.type}.`);
  }
}

function normalizeComponent(node, label, componentIds) {
  if (typeof node.name !== "string" || !allowedComponents.has(node.name)) {
    fail(`${label} contains unknown component ${String(node.name)}.`);
  }
  if (node.children.length !== 0)
    fail(`${node.name} must be self-closing and cannot contain children.`);
  const allowedAttributes = allowedComponents.get(node.name);
  const props = {};
  for (const attribute of node.attributes) {
    if (attribute.type !== "mdxJsxAttribute") fail(`${node.name} cannot use spread attributes.`);
    if (typeof attribute.name !== "string" || /^on/i.test(attribute.name)) {
      fail(`${node.name} cannot use event-handler attributes.`);
    }
    if (!allowedAttributes.includes(attribute.name))
      fail(`${node.name} has unknown attribute ${attribute.name}.`);
    if (typeof attribute.value !== "string" || attribute.value.trim().length === 0) {
      fail(`${node.name}.${attribute.name} must be a literal non-empty string.`);
    }
    if (Object.hasOwn(props, attribute.name))
      fail(`${node.name} has duplicate attribute ${attribute.name}.`);
    props[attribute.name] = attribute.value;
  }
  assertExactArray(
    Object.keys(props).sort(),
    [...allowedAttributes].sort(),
    `${node.name} attributes`,
  );
  assertStableReference(props.id, `${node.name} component ID`);
  if (componentIds.has(props.id)) fail(`duplicate component ID: ${props.id}.`);
  componentIds.add(props.id);
  return { type: "component", name: node.name, props: sortedObject(props) };
}

function validateExpectedRenderPlan(plan) {
  const components = plan.filter((node) => node.type === "component");
  if (components.length !== plan.length)
    fail("the accepted lesson MDX must contain only component mounts.");
  assertExactArray(
    components.map((node) => [node.name, node.props.id]),
    expectedRenderComponents,
    "lesson component plan",
  );
  const byName = Object.fromEntries(components.map((node) => [node.name, node]));
  assertEqual(
    byName.Scenario.props.sourceId,
    "bright-river-operations-synthetic-source-pack-v1",
    "scenario source mount",
  );
  assertEqual(
    byName.PracticeMount.props.practiceId,
    "source-verification-decision-v1",
    "practice mount",
  );
  assertEqual(byName.RubricSummary.props.rubricId, "source-verification-rubric-v1", "rubric mount");
  assertEqual(
    byName.ProofPlaceholder.props.proofId,
    "source-verification-note-placeholder-v1",
    "proof mount",
  );
  assertEqual(
    byName.ReflectionPrompt.props.proofId,
    "source-verification-note-placeholder-v1",
    "reflection proof mount",
  );
}

function structureSignature(value) {
  if (Array.isArray(value)) return `[${value.map(structureSignature).join(",")}]`;
  if (value === null || typeof value !== "object") return typeof value;
  return `{${Object.keys(value)
    .sort()
    .map((key) => `${key}:${key === "value" ? "copy" : structureSignature(value[key])}`)
    .join(",")}}`;
}

async function listRelativeFiles(directory, current = directory) {
  const files = [];
  for (const entry of await sortedDirectoryEntries(current)) {
    if (entry.isSymbolicLink())
      fail(`symlinks are prohibited: ${slash(relative(directory, join(current, entry.name)))}.`);
    const absolutePath = join(current, entry.name);
    if (entry.isDirectory()) files.push(...(await listRelativeFiles(directory, absolutePath)));
    else if (entry.isFile()) files.push(slash(relative(directory, absolutePath)));
    else fail(`unsupported filesystem entry: ${slash(relative(directory, absolutePath))}.`);
  }
  return files.sort();
}

async function sortedDirectoryEntries(directory) {
  try {
    return (await readdir(directory, { withFileTypes: true })).sort((a, b) =>
      a.name.localeCompare(b.name),
    );
  } catch (error) {
    fail(
      `cannot read content directory ${slash(directory)}: ${error instanceof Error ? error.message : error}`,
    );
  }
}

async function assertNoSymlinks(root, target) {
  const relativePath = relative(root, target);
  let current = root;
  for (const segment of relativePath.split(sep)) {
    current = join(current, segment);
    if ((await lstat(current)).isSymbolicLink())
      fail(`symlinks are prohibited: ${slash(relative(root, current))}.`);
  }
}

async function assertDirectoryInside(root, directory, label) {
  resolveInside(root, relative(root, directory));
  const stats = await lstat(directory).catch(() => null);
  if (!stats?.isDirectory() || stats.isSymbolicLink()) fail(`${label} must be a real directory.`);
}

function resolveInside(root, relativePath) {
  if (
    typeof relativePath !== "string" ||
    relativePath.includes("\0") ||
    relativePath.includes("\\")
  ) {
    fail("content paths must use safe repository-relative separators.");
  }
  const target = resolve(root, relativePath);
  const prefix = `${resolve(root)}${sep}`;
  if (target !== resolve(root) && !target.startsWith(prefix))
    fail(`path traversal is prohibited: ${relativePath}.`);
  return target;
}

function assertSafePathSegment(value, label) {
  if (!stableReferencePattern.test(value) && !semanticVersionPattern.test(value)) {
    fail(`${label} contains an unsafe path segment.`);
  }
}

async function readStrictSource(path, label) {
  const bytes = await readFile(path);
  if (bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf)
    fail(`${label} must not contain a UTF-8 BOM.`);
  let text;
  try {
    text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    fail(`${label} must be strict UTF-8.`);
  }
  if (text.includes("\r")) fail(`${label} must use LF line endings.`);
  if (text.length === 0 || !text.endsWith("\n"))
    fail(`${label} must be non-empty and end with LF.`);
  return text;
}

function parseJson(text, label) {
  try {
    return JSON.parse(text);
  } catch (error) {
    fail(`${label} must be valid JSON: ${error instanceof Error ? error.message : String(error)}`);
  }
}

function validateLocalizedMap(value, label) {
  assertObject(value, label);
  assertExactArray(Object.keys(value), requiredLocales, `${label} locales`);
}

function validateStringTree(value, label) {
  if (typeof value === "string") {
    if (value.trim().length === 0) fail(`${label} contains empty localized copy.`);
    if (rawHtmlPattern.test(value)) fail(`${label} contains raw HTML.`);
    return;
  }
  if (Array.isArray(value)) {
    if (value.length === 0) fail(`${label} contains an empty localized list.`);
    for (const child of value) validateStringTree(child, label);
    return;
  }
  if (value !== null && typeof value === "object") {
    const keys = Object.keys(value);
    if (keys.length === 0) fail(`${label} contains an empty localized object.`);
    for (const child of Object.values(value)) validateStringTree(child, label);
    return;
  }
  fail(`${label} contains non-string localized copy.`);
}

function assertLocalizedParity(localized, label) {
  if (localizedStructure(localized.th) !== localizedStructure(localized.en)) {
    fail(`${label} must match between Thai and English.`);
  }
}

function localizedStructure(value) {
  if (typeof value === "string") return "string";
  if (Array.isArray(value)) return `[${value.map(localizedStructure).join(",")}]`;
  if (value !== null && typeof value === "object") {
    return `{${Object.keys(value)
      .map((key) => `${key}:${localizedStructure(value[key])}`)
      .join(",")}}`;
  }
  return typeof value;
}

function assertSafeLink(url, label) {
  assertString(url, `${label} link URL`);
  if (url.startsWith("/")) {
    if (url.startsWith("//") || url.includes("..") || /%2e|%5c/i.test(url) || url.includes("\\")) {
      fail(`${label} contains an unsafe relative link.`);
    }
    return;
  }
  let parsed;
  try {
    parsed = new URL(url);
  } catch {
    fail(`${label} links must be HTTPS or same-origin absolute paths.`);
  }
  if (
    parsed.protocol !== "https:" ||
    parsed.username !== "" ||
    parsed.password !== "" ||
    /^(?:localhost|127(?:\.\d{1,3}){3}|\[?::1\]?)$/i.test(parsed.hostname)
  ) {
    fail(`${label} links must use reviewed public HTTPS destinations.`);
  }
}

function assertObject(value, label) {
  if (value === null || typeof value !== "object" || Array.isArray(value))
    fail(`${label} must be an object.`);
}

function assertString(value, label) {
  if (typeof value !== "string" || value.trim().length === 0)
    fail(`${label} must be a non-empty string.`);
}

function assertStableReference(value, label) {
  assertString(value, label);
  if (!stableReferencePattern.test(value)) fail(`${label} must be a stable non-secret reference.`);
}

function assertTimestamp(value, label) {
  assertString(value, label);
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:\d{2})$/.test(value)) {
    fail(`${label} must be an explicit ISO 8601 timestamp.`);
  }
  if (Number.isNaN(Date.parse(value))) fail(`${label} must be a valid timestamp.`);
}

function parseDate(value, label) {
  assertString(value, label);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) fail(`${label} must use YYYY-MM-DD.`);
  const [yearText, monthText, dayText] = value.split("-");
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  const parsed = new Date(Date.UTC(year, month - 1, day));
  if (
    parsed.getUTCFullYear() !== year ||
    parsed.getUTCMonth() + 1 !== month ||
    parsed.getUTCDate() !== day
  ) {
    fail(`${label} must be a valid calendar date.`);
  }
  return parsed;
}

function parseValidationInstant(value) {
  if (!(value instanceof Date) || Number.isNaN(value.valueOf())) {
    fail("validation date must be a valid Date instance.");
  }
  return new Date(value.valueOf());
}

function assertUnique(values, label) {
  if (values.some((value) => typeof value !== "string" || value.length === 0))
    fail(`${label} must be strings.`);
  if (new Set(values).size !== values.length) fail(`${label} must be unique.`);
}

function assertExactArray(actual, expected, label) {
  if (!Array.isArray(actual) || stableJsonValue(actual) !== stableJsonValue(expected)) {
    fail(`${label} must equal ${JSON.stringify(expected)}.`);
  }
}

function assertEqual(actual, expected, label) {
  if (actual !== expected) fail(`${label} must equal ${JSON.stringify(expected)}.`);
}

function sortedObject(value) {
  return Object.fromEntries(
    Object.entries(value).sort(([left], [right]) => left.localeCompare(right)),
  );
}

function stableJson(value) {
  return `${stableJsonValue(value)}\n`;
}

function stableJsonValue(value) {
  if (Array.isArray(value)) return `[${value.map(stableJsonValue).join(",")}]`;
  if (value !== null && typeof value === "object") {
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${stableJsonValue(value[key])}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}

function sha256(value) {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

function slash(value) {
  return value.replaceAll("\\", "/");
}

async function readOptionalUtf8(path) {
  try {
    return await readFile(path, "utf8");
  } catch (error) {
    if (error && typeof error === "object" && error.code === "ENOENT") return null;
    throw error;
  }
}

async function readTrackedOutput(path, label) {
  const value = await readOptionalUtf8(path);
  if (value === null) fail(`${label} is missing; run npm run content:publish.`);
  return value;
}

async function readPublicationSeal(contentRoot) {
  const sealText = await readTrackedOutput(join(contentRoot, sealFileName), sealFileName);
  let seal;
  try {
    seal = JSON.parse(sealText);
  } catch {
    fail(`${sealFileName} is invalid.`);
  }
  assertObject(seal, "publication seal");
  assertExactArray(
    Object.keys(seal).sort(),
    ["lessons", "schemaVersion"],
    "publication seal fields",
  );
  assertEqual(seal.schemaVersion, PUBLICATION_SEAL_SCHEMA_VERSION, "publication seal schema");
  if (!Array.isArray(seal.lessons) || seal.lessons.length === 0) {
    fail("publication seal must contain at least one reviewed lesson identity.");
  }
  assertUnique(
    seal.lessons.map((lesson) => lesson?.identity),
    "publication seal identities",
  );
  for (const lesson of seal.lessons) {
    assertObject(lesson, "publication seal lesson");
    assertExactArray(
      Object.keys(lesson).sort(),
      ["digest", "identity"],
      "publication seal lesson fields",
    );
    assertString(lesson.identity, "publication seal lesson identity");
    if (!/^[a-z0-9]+(?:-[a-z0-9]+)*@(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.test(lesson.identity)) {
      fail("publication seal lesson identity must use a stable key and semantic version.");
    }
    assertString(lesson.digest, "publication seal lesson digest");
    if (!/^[a-f0-9]{64}$/.test(lesson.digest)) {
      fail("publication seal lesson digest must be a lowercase SHA-256 value.");
    }
  }
  assertExactArray(
    seal.lessons.map((lesson) => lesson.identity),
    seal.lessons.map((lesson) => lesson.identity).toSorted(),
    "publication seal identity order",
  );
  if (sealText !== stableJson(seal)) {
    fail(`${sealFileName} must use canonical JSON and cannot be rewritten by content:publish.`);
  }
  return seal;
}

function assertPublicationSealMatchesCompiled(seal, compiledManifest) {
  const sealedIdentities = seal.lessons.map((lesson) => lesson.identity);
  assertExactArray(
    compiledManifest.lessons.map((lesson) => lesson.identity),
    sealedIdentities,
    "compiled lesson identities authorized by the publication seal",
  );
  const compiledByIdentity = new Map(
    compiledManifest.lessons.map((lesson) => [lesson.identity, lesson]),
  );
  for (const sealedLesson of seal.lessons) {
    const compiled = compiledByIdentity.get(sealedLesson.identity);
    if (compiled.digest !== sealedLesson.digest) {
      fail(
        `digest conflict for published lesson ${sealedLesson.identity}; the independently reviewed publication seal requires a new semantic version for modified source.`,
      );
    }
  }
}

function assertPublishedOutputIntegrity(existingText, compiledDocument, seal, schemaVersion, label) {
  let existing;
  try {
    existing = JSON.parse(existingText);
  } catch {
    fail(`${label} is invalid and cannot authorize an overwrite.`);
  }
  if (existing.schemaVersion !== schemaVersion || !Array.isArray(existing.lessons)) {
    fail(`${label} has an unsupported schema.`);
  }
  assertUnique(
    existing.lessons.map((lesson) => lesson?.identity),
    `${label} identities`,
  );
  const sealedIdentities = seal.lessons.map((lesson) => lesson.identity);
  assertExactArray(
    existing.lessons.map((lesson) => lesson.identity),
    sealedIdentities,
    `${label} identities required by the publication seal`,
  );
  const sealedByIdentity = new Map(seal.lessons.map((lesson) => [lesson.identity, lesson]));
  const compiledByIdentity = new Map(
    compiledDocument.lessons.map((lesson) => [lesson.identity, lesson]),
  );
  for (const lesson of existing.lessons) {
    const sealed = sealedByIdentity.get(lesson.identity);
    if (lesson.digest !== sealed.digest) {
      fail(
        `${label} digest conflicts with the independently reviewed publication seal for ${lesson.identity}.`,
      );
    }
    const compiled = compiledByIdentity.get(lesson.identity);
    if (stableJsonValue(lesson) !== stableJsonValue(compiled)) {
      fail(`${label} entry differs from the sealed compiled lesson ${lesson.identity}.`);
    }
  }
  if (existing.aggregateDigest !== compiledDocument.aggregateDigest) {
    fail(`${label} aggregate digest differs from the sealed compiled publication.`);
  }
}

async function atomicWritePair(entries) {
  const backups = [];
  const temporaryPaths = [];
  try {
    for (const [path, contents] of entries) {
      await mkdir(dirname(path), { recursive: true });
      const temporaryPath = `${path}.tmp-${process.pid}`;
      temporaryPaths.push(temporaryPath);
      await writeFile(temporaryPath, contents, { encoding: "utf8", flag: "wx" });
    }
    for (const [path] of entries) {
      const current = await readOptionalUtf8(path);
      backups.push([path, current]);
    }
    for (let index = 0; index < entries.length; index += 1) {
      await rename(temporaryPaths[index], entries[index][0]);
    }
  } catch (error) {
    for (const temporaryPath of temporaryPaths)
      await rm(temporaryPath, { force: true }).catch(() => {});
    for (const [path, contents] of backups) {
      if (contents === null) await rm(path, { force: true }).catch(() => {});
      else await writeFile(path, contents, "utf8").catch(() => {});
    }
    throw error;
  }
}

function fail(message) {
  throw new Error(`Content publication validation failed: ${message}`);
}
