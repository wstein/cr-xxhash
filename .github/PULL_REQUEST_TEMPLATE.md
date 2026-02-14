## Description

Please include a summary of the change and which issue is fixed. Also include relevant motivation and context.

## Checklist

- [ ] I have run the unit test suite: `crystal spec`
- [ ] I have run the generator and committed any updated fixtures: `crystal scripts/generate_vectors.cr`
- [ ] I have added/updated docs where relevant (README, CONTRIBUTING, TODOs)
- [ ] Benchmark results included (if performance change)
- [ ] CI passes (including `Verify generated vendor vectors`)

## Notes for reviewers

- Regenerating vendor vectors: run `crystal scripts/generate_vectors.cr` and commit the files under `spec/fixtures/` (the PR CI will fail if fixtures change after generation). See `papers/CONTRIBUTING.adoc` → "Regenerating vendor test vectors" for full instructions and CI expectations.
