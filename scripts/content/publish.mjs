import { publishContent } from "./pipeline.mjs";

try {
  const result = await publishContent();
  console.log(
    `Published ${result.lessonCount} lesson version(s); aggregate SHA-256 ${result.aggregateDigest}.`,
  );
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}
