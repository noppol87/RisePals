import { validatePublishedContent } from "./pipeline.mjs";

try {
  const result = await validatePublishedContent();
  console.log(
    `Validated ${result.lessonCount} published lesson version(s); aggregate SHA-256 ${result.aggregateDigest}.`,
  );
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}
