# Trusted content publication source

Git-reviewed files under `content/lessons/` are the only pilot authoring source. RP-TURN-014 publishes one immutable bilingual synthetic-alpha lesson version:

```text
content/
  lessons/source-verification-practice/1.0.0/
    lesson.meta.json
    practice.json
    rubric.json
    proof.json
    sources.json
    locales/th/lesson.mdx
    locales/en/lesson.mdx
  publication-manifest.json
  published-lessons.json
```

Run `npm run content:publish` after an intentional source edit. It validates the complete source set, computes strict UTF-8/LF per-file and aggregate SHA-256 digests, rejects mutation under an already published key/version and atomically writes deterministic tracked JSON. Run `npm run content:validate` for a read-only stale/contract check. Build and aggregate checks run the validator automatically and never publish or rewrite content.

MDX is declarative repository content, not code. The build-only parser creates an AST and accepts only the documented Markdown subset plus `Scenario`, `ConceptList`, `PracticeMount`, `RubricSummary`, `ProofPlaceholder` and `ReflectionPrompt`. The pipeline rejects executable syntax, raw HTML, unsafe URLs, unknown nodes/components, traversal, symlinks and unsupported files. Runtime code reads only `published-lessons.json` through a server-only registry.

`published` means available through this reviewed local registry for synthetic alpha. It does not mean externally validated, effective for learning, credential-bearing or production-ready. The current lesson remains `prototype-unvalidated`; its Bright River Operations case and source records are explicitly synthetic. Never add user data, secrets, uploads, proof artifacts, assessment responses or production telemetry here.
