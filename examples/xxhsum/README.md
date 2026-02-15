xxhsum — Crystal example (minimal MVP)

This directory contains a minimal Crystal example CLI demonstrating how to use the `cr-xxhash` library. It implements MVP (Minimum Viable Product) features:

**Supported Features:**

- Algorithm selection: `-H0` (XXH32), `-H1` (XXH64, default), `-H2` (XXH128), `-H3` (XXH3_64)
- File hashing: `./bin/xxhsum [options] file1 [file2 ...]`
- stdin support: `echo "data" | ./bin/xxhsum` or `./bin/xxhsum -`
- Output formats:
  - GNU (default): `<hash>  <filename>`
  - BSD (--tag): `<algo> (<filename>) = <hash>`
- Seeding: `-s SEED` or `--seed SEED` (decimal or 0xHEX format)
- Version & help: `--version`, `-h`, `--help`

**Build & Run:**

  cd examples/xxhsum
  shards install
  shards build xxhsum --release
  ./bin/xxhsum README.md           # Hash a file
  echo "test" | ./bin/xxhsum       # Hash from stdin
  ./bin/xxhsum -H3 file.txt        # Use XXH3_64 algorithm
  ./bin/xxhsum --tag file.txt      # BSD format output
  ./bin/xxhsum -s 12345 file.txt   # Seeded hash

**Format Parity:**

Output format matches the official vendor `xxhsum` for all P0 features:

- GNU format, BSD format, algorithm prefixes (XXH3_) all compatible
- Multi-file support works identically

**Architecture:**

- `src/options.cr` — command-line argument parsing (OptionParser)
- `src/hasher.cr` — delegates to `XXH::*` library APIs (uses streaming/file APIs)
- `src/formatter.cr` — output formatting (GNU/BSD modes, algorithm prefixes)
- `src/xxhsum.cr` — main entry point and CLI orchestration

**Note:**

This example deliberately uses the public `XXH::*` module APIs, not `LibXXH.*` FFI. This demonstrates the proper usage pattern for library consumers.

**Testing:**

The CLI includes comprehensive cucumber-style BDD tests with fixture/corpus/snapshot pattern:

```bash
cd examples/xxhsum
crystal spec -v
```

Test infrastructure:

- `spec/corpus/cli_cases.json` — Scenario corpus metadata with test parameters
- `spec/fixtures/` — Test data (small text files, checksum files). Canonical originals are committed in `spec/fixtures/originals/`; runtime `.orig` backups are ignored.
- `spec/snapshots/` — Expected stdout/stderr outputs for each scenario
- `spec/support/cli_corpus_helper.cr` — Fixture restoration, corpus loader, snapshot assertions

**Test Scenarios (19 total):**

- **Hashing**: Default algorithm, XXH3, piped stdin
- **Help/UX**: No-args with TTY, version flag
- **Verification**: File checksums, piped checksums, both GNU and BSD formats
- **Errors**: Malformed checksum lines (default skip, --strict fail)
- **Mutations** (4 scenarios): Single file modification, batch corruption, algorithm auto-detection via stdin
- **Flag matrix**: `-q` (quiet) and `--ignore-missing` combinations for missing/mixed checksum entries (added to catch UX regressions)

Each test runs via `XXHSum::CLI.run(args, stdin, stdout, stderr, stdin_tty)` — no shell subprocess wrapper.

Fixtures are isolated between test cases and restored to original state after all tests complete.

To update snapshots after intentional output changes:

```bash
UPDATE_SNAPSHOTS=1 crystal spec
```

Contributing — updating fixtures & snapshots

- Update committed canonical fixtures in `spec/fixtures/originals/` when you change test data.
- Regenerate snapshots for the example only (safer and faster):

  ```bash
  cd examples/xxhsum
  UPDATE_SNAPSHOTS=1 crystal spec spec/cli_corpus_spec.cr -v
  ```

- Run the full test suite and verify before committing:

  ```bash
  cd /path/to/cr-xxhash
  crystal spec -v
  ```

- Commit the canonical originals and the updated `spec/snapshots/` files. Do NOT commit runtime backup files (`.*.orig`) — they are ignored by `.gitignore`.

Contributing (short)

- Open an issue describing the change or bug you plan to fix.
- Add/modify a corpus case in `spec/corpus/cli_cases.json` and the corresponding `spec/snapshots/*` entries.
- If test data changes, update committed canonical fixtures in `spec/fixtures/originals/`.
- Regenerate snapshots for the example and verify locally:

  ```bash
  cd examples/xxhsum
  UPDATE_SNAPSHOTS=1 crystal spec spec/cli_corpus_spec.cr -v
  ```

- Run the full repository test suite and include the failing-to-passing diff in your PR description:

  ```bash
  crystal spec -v
  ```

- PR checklist: tests added/updated, `spec/fixtures/originals/` updated when needed, snapshots regenerated, no runtime `.*.orig` files committed.

Behavior matrix — `-q` (quiet) and `--ignore-missing`

| Scenario | no flags | `-q` | `--ignore-missing` | `--ignore-missing -q` |
|---|---:|---:|---:|---:|
| Missing-only (checksums_missing.txt) | stderr: missing + WARNING; exit 1 | same | stdout: `no file was verified`; exit 1 | same |
| Mixed (present + missing) | stdout: `OK` + stderr: missing + WARNING; exit 1 | OK suppressed; stderr: missing + WARNING; exit 1 | stdout: `OK` only; exit 0 | OK suppressed; no stderr; exit 0 |

Notes: table documents vendor-parity behavior covered by the new corpus tests in `spec/corpus/cli_cases.json` (flag-matrix cases).

Golden snapshot normalization helper (CRLF + trailing-space)

- Use `NORMALIZE_EOL=1` when running specs on CI across mixed OS agents to normalize EOLs and trim trailing whitespace before comparing snapshots.
- Normalizer rules applied when enabled:
  - Convert CRLF / CR → LF
  - Trim trailing spaces/tabs at end of lines
  - Preserve original trailing-newline state

- Example (CI):

  ```bash
  NORMALIZE_EOL=1 crystal spec spec/cli_corpus_spec.cr -v
  ```

- The normalizer is optional and applied only when the environment toggle is set; it preserves strict snapshot matching by default.
