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
  publication-seal.json
  publication-manifest.json
  published-lessons.json
```

`publication-seal.json` is the independently Git-reviewed authorization for every published identity and canonical lesson digest. `content:publish` reads but never rewrites the seal. It rejects source mutation and any removed or altered sealed entry in either generated output before writing, so deleting or editing the manifest and registry cannot authorize an overwrite.

Run `npm run content:publish` after an intentional, separately reviewed source/version and seal change. It validates the complete source set, computes strict UTF-8/LF per-file and aggregate SHA-256 digests, and atomically writes deterministic tracked JSON only after seal and existing-output integrity pass. Run `npm run content:validate` for a read-only seal/stale/contract check. Build and aggregate checks run the validator automatically and never publish or rewrite content. External-evidence expiry is evaluated against the current UTC instant; tests inject an explicit validation instant without adding time-dependent generated fields.

MDX is declarative repository content, not code. The build-only parser creates an AST and accepts only the documented Markdown subset plus `Scenario`, `ConceptList`, `PracticeMount`, `RubricSummary`, `ProofPlaceholder` and `ReflectionPrompt`. The pipeline rejects executable syntax, raw HTML, unsafe URLs, unknown nodes/components, traversal, symlinks and unsupported files. Runtime code reads only `published-lessons.json` through a server-only registry.

`published` means available through this reviewed local registry for synthetic alpha. It does not mean externally validated, effective for learning, credential-bearing or production-ready. The current lesson remains `prototype-unvalidated`; its Bright River Operations case and source records are explicitly synthetic. Never add user data, secrets, uploads, proof artifacts, assessment responses or production telemetry here.
