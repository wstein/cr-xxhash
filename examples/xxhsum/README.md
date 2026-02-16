xxhsum — Crystal example (minimal MVP)

This directory contains a minimal Crystal example CLI demonstrating how to use the `cr-xxhash` library. It implements MVP (Minimum Viable Product) features:

**Supported Features:**

- Algorithm selection: `-H0` (XXH32), `-H1` (XXH64, default), `-H2` (XXH128), `-H3` (XXH3_64)
- File hashing: `./bin/xxhsum [options] file1 [file2 ...]`
- stdin support: `echo "data" | ./bin/xxhsum` or `./bin/xxhsum -`
- Filelist mode: `--filelist FILE` (generate hashes for files listed in FILE, one per line)
- Output formats:
  - GNU (default): `<hash>  <filename>`
  - BSD (--tag): `<algo> (<filename>) = <hash>`
  - Little-endian (--little-endian): `<algo>_LE_<reversed_hash>` with byte reversal
- Checksum verification: `-c file` or `-c` with piped checksums
- Verification flags:
  - Quiet mode (`-q`, `--quiet`): Suppress per-file OK messages
  - Warn mode (`--warn`): Print warnings for improperly formatted checksum lines (do not fail)
  - Status-only mode (`--status`): No output, exit code only (useful for scripts)
  - Ignore missing files: `--ignore-missing`
  - Strict mode: `--strict` (non-zero exit on format errors)
- Seeding: `-s SEED` or `--seed SEED` (decimal or 0xHEX format)
- Version & help: `--version`, `-h`, `--help`
- Benchmark mode: `-b`, `-b#`, `-i#`, `-B#`

**Build & Run:**

  cd examples/xxhsum
  shards install
  shards build xxhsum --release
  ./bin/xxhsum README.md                          # Hash a file
  echo "test" | ./bin/xxhsum                      # Hash from stdin
  ./bin/xxhsum -H3 file.txt                       # Use XXH3_64 algorithm
  ./bin/xxhsum --tag file.txt                     # BSD format output
  ./bin/xxhsum --little-endian file.txt           # Little-endian (byte-reversed) output
  ./bin/xxhsum -s 12345 file.txt                  # Seeded hash
  echo -e "file1.txt\nfile2.txt" | ./bin/xxhsum --filelist  # Filelist from stdin
  ./bin/xxhsum --filelist myfiles.txt             # Filelist from file
  ./bin/xxhsum -c checksums.txt                   # Verify checksums
  ./bin/xxhsum -b -i1 -B64K                       # Run benchmark (default variants)
  ./bin/xxhsum -b1-3 -i1 -B64K                     # Run benchmark variants 1 through 3 (range)
  ./bin/xxhsum -bi1 -B64K                          # Compact form: -b with iterations (vendor-style -bi1)
  ./bin/xxhsum -b7 -i3 -B1M                       # Run one benchmark variant

**Format Parity:**

Output format matches the official vendor `xxhsum` for all P0 features:

- GNU format, BSD format, algorithm prefixes (XXH3_) all compatible
- Multi-file support works identically

**Architecture:**

- `src/options.cr` — command-line argument parsing (OptionParser)
- `src/cli.cr` — main CLI orchestration and mode routing
- `src/hasher.cr` — delegates to `XXH::*` library APIs (uses streaming/file APIs)
- `src/formatter.cr` — output formatting (GNU/BSD modes, algorithm prefixes)
- `src/checker.cr` — checksum verification mode implementation
- `src/benchmark.cr` — benchmark mode implementation (28 variants with time-based calibration). Exposes `Benchmark::Variant` record (`kind : Symbol`) for variant metadata. Optimized for zero-copy data generation and stack-allocated secret buffers.
- `src/xxhsum.cr` — main entry point

**Note:**

This example deliberately uses the public `XXH::*` module APIs, not `LibXXH.*` FFI. This demonstrates the proper usage pattern for library consumers.

**Vendor Compatibility Validation**

This Crystal implementation has achieved **100% behavioral parity with the official C vendor implementation** (xxhsum v0.8.3). The validation includes:

- **17/17 corpus test cases** passing with identical exit codes, stdout, and stderr
- **Output formats**: GNU and BSD modes match exactly
- **Error handling**: Same error messages, summary format, and missing file behavior
- **Modes**: Quiet mode, ignore-missing, strict mode, seeding all confirmed compatible
- **All 354 tests passing**: main library (305) + example CLI (49) including 17 vendor parity cases

See [VENDOR_PARITY.md](VENDOR_PARITY.md) for the detailed compatibility report.

**Benchmark Mode (Vendor-Compatible IDs)**

- `-b` run benchmark with vendor default variants: `1, 3, 5, 11`
- `-b#` run selected benchmark variant(s), e.g. `-b7`, `-b1,3,5,11` — accepts `comma-separated` lists or `ranges` such as `-b1-3`
- `-bi#` compact vendor-style form to set iterations together with `-b` (e.g. `-bi1` behaves like `-b -i1`)
- `-b0` (or IDs `>=29`) runs all 28 variants (vendor-compatible behavior)
- `-i#` number of timing iterations (default: `3`)
- `-B#` sample size with suffixes (`K/KB/M/MB/G/GB` — 1024-based)

Output format follows vendor style:

- `ID#Name : Size -> it/s (MB/s)`

**Benchmark Smoke Test Mode (for CI/Tests)**

For faster benchmark testing, benchmark specs automatically enable smoke test mode during test runs via `spec_helper.cr`:

```bash
# All benchmark specs run in ~7 seconds (smoke mode auto-enabled)
crystal spec

# Manual smoke test benchmark (explicit ENV var for CLI use)
BENCHMARK_SMOKE=1 ./bin/xxhsum -b -i1 -B10K
```

When enabled, timing targets are reduced 10x:

- `target_seconds: 1.0 → 0.1` (100ms per variant)
- `min_seconds: 0.001 → 0.00001` (10μs minimum)

This enables realistic benchmark validation without the overhead of full measurements. All benchmark variant logic, algorithm dispatch, and output formatting remain unchanged—only timing calibration is reduced.

**Implementation**: `Benchmark#target_seconds` and `Benchmark#min_seconds` are runtime methods that check the `BENCHMARK_SMOKE` env var, enabling seamless test acceleration without code duplication or per-test setup/teardown.

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
UPDATE_SNAPSHOTS=1 crystal spec spec/cli_corpus_spec.cr -v
```

The snapshot system now supports **auto-review mode** with unified diff output:

- Snapshots are stored in `spec/snapshots/expected/` (golden/canonical directory)
- When running with `UPDATE_SNAPSHOTS=1`, each changed snapshot shows a diff before updating
- Diff output is limited to first 20 lines of changes for readability
- This allows developers to review output format changes incrementally as they make code changes

Example auto-review output:

```
  📝 Snapshot updated: hash_default.stdout.snap
  --- expected
  +++ actual
  - "abc123  file.txt\n"
  + "abc123def  file.txt\n"
```

Snapshot Maintenance Strategy
---

**Problem:** When CLI output format evolves, golden snapshots need updating. Manual review process is tedious without diffs.

**Solution:** Two-phase update workflow

1. **Phase 1: Auto-Review (UPDATE_SNAPSHOTS=1)** — Developer sees diffs of what changed
   - Each snapshot shows before/after (first 20 lines of changes)
   - `spec/snapshots/expected/*.snap` files are updated
   - Safe to iterate: review → adjust code → re-run

2. **Phase 2: Commit & Verify** — Full test suite validates

   ```bash
   # After adjusting code and reviewing diffs:
   UPDATE_SNAPSHOTS=1 crystal spec spec/cli_corpus_spec.cr -v  # See diffs
   crystal spec -v                                              # Full validation
   # Commit spec/snapshots/expected/* files
   ```

**Benefits:**

- Output format changes are visible (not silent rewrites)
- Easy to catch accidental regressions in snapshot updates
- Maintainability rating: 8/10 (improves when format evolves frequently)

Vendor vs. cr-xxhash CLI Analysis
---

### Architectural Pattern Comparison

**Vendor xxhsum (C, 1676 LOC, xxhash.c)**

Structure:

- Monolithic function-based: `XSUM_usage()`, `XSUM_checkFile()`, `XSUM_parseFileArg()` in single source
- Check mode: `XSUM_checkFile()` and `XSUM_checkStdin()` are separate code paths (87 lines each)
- Global state: `g_defaultAlgo`, `XSUM_logLevel`, etc.
- Flags as integers: `bench`, `quiet`, `ignoreMissing`, `warn`, `algoBitmask` passed as separate parameters
- Output via `XSUM_log()` macro (wraps printf with log-level filtering)

Verification logic highlights:

- **Quiet mode semantics**: `if (!quiet) fprintf(out, "OK")` suppresses per-file status, warnings always print  
- **Ignore-missing behavior**: Tracks `matched_in_file` counter; when 0 and `--ignore-missing`, prints `"<file>: no file was verified"` and exits non-zero (lines 1104-1107)  
- **Strict mode**: Optional by default, enabled via `--strict` flag; fails on improperly formatted lines  
- **Algorithm detection**: Infers from hash length (64-bit vs 128-bit) when not explicitly supplied

**cr-xxhash example (Crystal, ~380 LOC, modular)**

Structure:

- Modular design: `cli.cr` (58 LOC), `options.cr` (88 LOC), `hasher.cr` (40 LOC), `formatter.cr` (45 LOC), `checker.cr` (289 LOC)
- Check mode: `Checker.verify_stdin()` and `Checker.verify()` share code via `compute_hash()` helper  
- Options struct: `Options` with typed properties (Algorithm enum, boolean flags, seed)  
- Dependency injection: `stdin:`, `out_io:`, `err_io:` parameters for testability  
- Output via crystal `IO#puts` (flexible: supports mock IO for testing)

Verification logic highlights:

- **Quiet mode semantics**: Identical — `unless options.quiet` guards only per-file OK lines (line 45 in checker.cr)  
- **Ignore-missing behavior**: Identical vendor parity — tracks `matched_in_file`, prints vendor message when 0 docs all edge cases  
- **Strict mode**: Optional, tracks `total_bad_format` error counter  
- **Algorithm detection**: `infer_algorithm_from_hash()` helper infers from hash length  

### Key Design Differences

| Aspect | Vendor (C) | cr-xxhash (Crystal) |
|---|:---:|:---:|
| **CLI Framework** | Manual OptionParser (hand-rolled) | Crystal `OptionParser` (standard library) |
| **State Management** | Global variables + parameter passing | Struct `Options` with properties |
| **Code Organization** | Single file (1676 LOC) | Modular (5 files, ~380 LOC) |
| **Testability** | Shell subprocess wrapper required | Direct `CLI.run(argv, stdin, stdout)` call |
| **Output Abstraction** | Macro wrapper (`XSUM_log`) with log-level filtering | Direct `IO#puts` (client chooses IO implementation) |
| **Error Handling** | Exit codes + fprintf(stderr) | Typed `Int32` return codes + IO abstraction |
| **Type Safety** | Primitive types (int, char*) | Enum `Algorithm`, struct `Options` |

### Behavioral Parity Achieved

Both implementations are **bit-for-bit identical** for these critical behaviors:

1. **Output format**: GNU (`<hash>  <file>`) and BSD (`<ALGO> (<file>) = <hash>`) match exactly
2. **Quiet mode**: Only suppresses per-file OK status, warnings/errors always visible
3. **Ignore-missing**: Shows `"<file>: no file was verified"` when no checksums matched (vendor parity from C lines 1104-1107)
4. **Strict mode**: Fails on malformed checksum lines when enabled
5. **Algorithm inference**: Both auto-detect from hash length when not explicitly specified in checksum file
6. **Exit codes**: 0 on success, 1 on checksum mismatch/file error, 2 on usage error

### Testing Parity Verification

The corpus of 18 test cases validates all parity points:

- 8 flag-matrix cases (quiet × ignore-missing × missing|mixed) ensure UX semantics match
- Each case explicitly specifies expected_exit_code and expected stderr/stdout
- Vendor-parity behavior (`no file was verified` message) is snapshot-tested
- Cross-platform normalized EOL mode ensures Windows/macOS equivalence

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

Behavior matrix — `-q` (quiet), `--status`, and `--ignore-missing`

| Output Type | no flags | `-q` | `--status` | With `--ignore-missing` |
|---|---:|---:|---:|---:|
| Per-file OK message | ✅ Print | ❌ Skip | ❌ Skip | `--ignore-missing` with `-q/--status`: same suppression |
| Per-file FAILED message | ✅ Print | ✅ Print | ❌ Skip | Same as above |
| Format error message | ✅ Print (strict) | ✅ Print (strict) | ❌ Skip | Same as above |
| Missing file error | ✅ Print | ✅ Print | ❌ Skip | Same as above |
| Summary message | ✅ Print | ✅ Print | ❌ Skip | ❌ Skip (no summary) |
| Exit Code (on failure) | 1 | 1 | 1 | Depends on ignore-missing |
| **Use Case** | Default behavior | Reduce output noise | Scripts that only care about exit code | Skip missing files, combined with flags above |

**Key Differences**:

- `-q` (quiet): Suppresses OK messages only, shows errors and summary
- `--status`: Suppresses all output (OK, errors, summary), exit code only—useful for scripts where you only check `$?`
- Combined: `-q --status` is equivalent to `--status` (status takes precedence for complete suppression)

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

Architectural Recommendations & Design Patterns
---

### Why Crystal Modular > Monolithic C

**Maintainability**: The cr-xxhash CLI demonstrates advantages of modular design:

1. **Testing**: Direct `CLI.run(args, stdin, stdout)` calls eliminate shell subprocess overhead. No need for integration-test wrapper scripts; unit tests can simulate edge cases directly.

2. **Code Organization**: Five small modules (≤90 LOC each) vs. one 1676-line file. Cognitive load for understanding any single module is minimal.

3. **Extensibility**: Adding algorithm or flag isn't scattered across multiple functions; changes are localized to `options.cr` or specific module.

4. **Type Safety**: Enum `Algorithm` (4 values) and struct `Options` (booleans, nullable fields) eliminate parameter-passing bugs that plague C's integer flags.

5. **Error Handling**: Crystal's `rescue`/`raise` vs. C's return-code checking is cleaner and harder to forget.

### Design Principles Demonstrated

**Dependency Injection**: `CLI.run()` accepts injectable `stdin`, `stdout`, `stderr` parameters. This enables:

- Testability: mock IO without touching global state
- Flexibility: caller controls output destination (file, buffer, socket)
- Composability: CLI can be embedded in larger applications

**Separation of Concerns**:

- `options.cr` — argument parsing (doesn't know about hashing)
- `hasher.cr` — hashing (doesn't know about CLI)
- `formatter.cr` — output formatting (pure function)
- `checker.cr` — verification logic (isolated from CLI)
- `cli.cr` — orchestration (glues together)

**Testing Strategy**: Fixtures + Corpus + Snapshots enables:

- Scenario-driven: JSON corpus lists test cases (readable, maintainable)
- Golden snapshots: Expected outputs are committed, reviewed in version control
- Mutation testing: Files modified between test phases to catch regressions
- Isolation: Fixtures restored before each test (no test interdependencies)

### Known Limitations & Future Directions

**Current Scope (MVP)**

- Single-threaded, blocking I/O
- No progress bar or verbose output (--verbose not implemented)
- Secretary support plan: `--secret` flag for XXH3 custom secret input

**Scalability Considerations**

- For large directory trees (`xxhsum *.txt`), could parallelize hashing across cores
- For checksum files with thousands of entries, could stream-process to avoid loading all in memory
- Both achievable in Crystal with fiber-based concurrency (minimal refactoring)

**Crystal vs. C Trade-offs**

- **pro**: Safer (no buffer overflows, null pointer bugs), faster to write, easier to maintain
- **con**: Slightly longer process startup/shutdown because Crystal runs with a runtime and garbage collector; larger binary (~15–20MB). In our measurements on macOS the example `xxhsum` started in ~14 ms vs vendor `xxhsum` at ~8 ms, and the example binary size is ~881K vs vendor ~106K — still well under 1 MB.
- **use C when**: tight memory budgets, nanosecond-level performance critical
- **use Crystal when**: velocity, correctness, testability matter more than raw speed
