# xxhsum Example — TODO & Progress

## ✅ Completed

### MVP Features (Phase 1)

- [x] Algorithm selection (-H0, -H1, -H2, -H3)
- [x] File hashing (single and multiple files)
- [x] stdin support (piping, explicit `-`)
- [x] Binary file mode fix in library
- [x] Output formats (GNU default, BSD --tag)
- [x] Algorithm prefixes (XXH3_ for H3)
- [x] Seeding support (-s/--seed with decimal and 0xHEX)
- [x] Help/version flags (--help, --version)
- [x] No-args interactive help when TTY
- [x] Little-endian output format (--little-endian)
  - [x] Byte-reversed hex output with `_LE` suffix
  - [x] Works with all algorithms (XXH32, XXH64, XXH3, XXH128)
  - [x] GNU and BSD output format support
  - [x] Checksum verification with LE format parsing
  - [x] All 49 tests passing (no regressions)

### Benchmark Enhancements (recent)

- [x] Benchmark mode (-b / -b# / -i# / -B#)
- [x] Comma-separated benchmark IDs (-b1,3,5,11)
- [x] Range benchmark selector (-b1-3)
- [x] Compact `-biN` form (vendor-style `-bi1`)
- [x] Live-progress updates during calibration (live-update)
- [x] Calibration target increased to ~1s per variant (more stable timings)
- [x] Size-suffix policy: all common suffixes (K/KB/M/MB/G/GB and IEC forms) are 1024-based
- [x] Added `--bench-all` alias (runs all 28 variants, equivalent to -b0)
- [x] Added specs to verify:
  - [x] Live-update carriage-return behavior
  - [x] Comma-separated benchmark ID parsing and execution
- [x] Smoke test mode for fast CI/spec runs (BENCHMARK_SMOKE=1)
  - [x] Environment variable controls timing constants without CLI changes
  - [x] Reduces benchmark exec time from ~60s → ~2-3s for full spec suite
  - [x] All integration tests wrapped with BENCHMARK_SMOKE in setup/teardown
  - [x] Benchmarks still execute fully (all variants, calibration, output) — only timing reduced

### Check Mode (Phase 2)

- [x] Verify checksums from file (-c file)
- [x] Verify checksums from stdin (-c with piped input)
- [x] GNU checksum format parsing
- [x] BSD checksum format parsing
- [x] Algorithm auto-detection from hash length
- [x] Algorithm prefix detection (XXH3_)
- [x] Missing file handling (error by default, skip with --ignore-missing)
- [x] Bad format line handling (skip by default, error with --strict)
- [x] Warn mode (--warn) — print warnings for improperly formatted lines but do not fail
- [x] Comment support (# lines)
- [x] Quiet mode (-q, --quiet)
- [x] Status-only mode (--status - no output, exit code only)
  - [x] Suppresses all output (OK, FAILED, errors, summary)
  - [x] Maintains correct exit codes (0 on success, 1 on failure/missing files/format errors)
  - [x] Works in both verify_stdin() and verify() code paths
  - [x] Vendor parity: matches C xxhsum behavior
- [x] Filelist mode (--filelist FILE - generate hashes for listed files)
  - [x] Read filenames from file, one per line
  - [x] Support filelist from stdin
  - [x] Respects all flags (algorithm, BSD format, little-endian, seeding)
  - [x] Error handling for missing files (reports but continues)
  - [x] Vendor parity: matches C xxhsum behavior
- [x] Exit codes (vendor parity: 0=ok, 1=check failures/strict format errors)
- [x] Cross-platform compatibility (vendor xxhsum interop)

### Testing Infrastructure (Phase 3)

- [x] Refactor CLI for injectable IO (non-global stdin/stdout/stderr)
- [x] Separate executable entrypoint from reusable CLI module
- [x] Cucumber-style corpus-driven tests
- [x] Fixture management with backup restoration (committed originals in `spec/fixtures/originals/`)
- [x] Snapshot assertions (expected stdout/stderr per scenario)
- [x] Base scenarios (hashing, verification, help, errors)
- [x] **Mutation scenarios** (file modification detection)
  - [x] Single file corruption
  - [x] Batch file corruption
  - [x] Algorithm auto-detection with mutations
  - [x] H3 stdin verification with partial corruption
- [x] Fixture teardown (auto-restore after test suite)
- [x] 19 passing test scenarios (added quiet/--ignore-missing matrix cases)
- [x] Golden snapshot normalization helper (CRLF + trailing-space toggle via NORMALIZE_EOL=1)
- [x] **Snapshot auto-review system** (UPDATE_SNAPSHOTS=1 with diff output)
  - [x] Move snapshots to `spec/snapshots/expected/` (golden/canonical directory)
  - [x] Show unified diffs before updating (first 20 lines of changes)
  - [x] Two-phase update workflow (review → commit → verify)
  - [x] Documentation of snapshot maintenance strategy
  - [x] **Vendor CLI analysis & architectural comparison**
    - [x] Analyzed vendor xxhsum C implementation (1676 LOC, monolithic)
    - [x] Analyzed cr-xxhash Crystal example (380 LOC, modular)
    - [x] Created detailed architectural comparison table
    - [x] Documented behavioral parity for quiet, ignore-missing, strict modes
    - [x] Identified design advantages: testability, type safety, modularity
    - [x] Documented design patterns: dependency injection, separation of concerns
    - [x] Added recommendations for when to use C vs. Crystal for CLI tools
  - [x] Two-phase update workflow (review → commit → verify)
  - [x] Documentation of snapshot maintenance strategy
  - [x] Vendor CLI analysis & architectural comparison document

### Code Quality & Refactoring

- [x] Refactor `options.cr` to use idiomatic Crystal `OptionParser.parse` block
  - [x] Eliminated duplicate parser definitions (one in `help_text`, one in `parse`)
  - [x] Implemented pointer-based `Options` mutation pattern for struct value semantics
  - [x] Enabled `gnu_optional_args: true` for correct compact flag handling (-b3, -i5, -B100K)
  - [x] Updated flag declarations to match vendor help style (`-H [ALGORITHM]`, `-b [VARIANTS]`, etc.)
  - [x] Lowercased `--simd` help entry (`--simd [BACKEND]`), validation placeholder unchanged
  - [x] All 305 repository tests passing (45 xxhsum specs + 17 vendor parity cases)
- [x] Refactor `benchmark.cr` to align with codebase conventions
  - [x] Fixed module structure: `XXHSum::Benchmark::Benchmark` → `XXHSum::CLI::Benchmark`
  - [x] Renamed `BenchmarkVariant` → `Benchmark::Variant` for clearer namespacing (now a `record` with `kind : Symbol`)
  - [x] Added benchmark tuning constants: `TARGET_SECONDS`, `MIN_SECONDS`, `FIRST_MBPS`, `DEFAULT_VARIANT_IDS`
  - [x] Optimized data generation: avoid intermediate Array allocations, generate Bytes directly
  - [x] Optimized secret buffer: stack-allocated (136 bytes), unsafe pointer access
  - [x] Added API doc comments for `Benchmark::Variant` record
  - [x] Aligned Options field names: `benchmark_variants` → `benchmark_ids`, `iterations` → `benchmark_iterations`, `sample_size` → `benchmark_size`
  - [x] Added IO parameter for testability: `run(options : Options, io : IO = STDOUT) : Int32`
  - [x] Fixed Algorithm enum references: `Algorithm::XXH3` → `Algorithm::XXH3_64`
  - [x] Corrected XXH API calls: Use `XXH::XXH3.hash64()`, `XXH::XXH3.hash128()`, `XXH::XXH3::State64.new()`
  - [x] Fixed constant references: `XXH::Constants::XXH3_SECRET_SIZE_MIN` → `LibXXH::XXH3_SECRET_SIZE_MIN`
  - [x] All 49 tests passing

## 📋 Future Work (Prioritized)

### P1 — Quality & Completeness

- [x] Add quiet/ignore-missing flag matrix scenarios
- [ ] Add multi-file mutation edge cases
- [ ] Vendor parity corpus lane (test against official xxhsum outputs)
- [x] Golden snapshot normalization helper (optional CRLF + trailing-space toggle via `NORMALIZE_EOL`)

### P2 — Features (Optional)

- [x] Benchmark mode & --bench-all alias
- [ ] Programmatic completion generator (DRY) — needs investigation
  - [ ] Design single source-of-truth for options/metadata (used by OptionParser + completion generator)
  - [ ] Investigate packaging as separate tool/shard or rubygem-like distribution for broader reuse
  - [ ] Implement `--completions [SHELL]` to emit completion scripts (bash, zsh, fish)
  - [ ] Add tests and snapshots for generated completion output
  - [ ] Document install instructions for bash/zsh/fish
- [ ] Secret support for XXH3 (--secret flag)
- [ ] Filename escaping for special characters
- [ ] Multiple checksum file support in --check mode

### P3 — Advanced

- [ ] Performance regression testing
- [ ] Extended metadata (file size, permissions)
- [ ] Recursive directory hashing (-r flag)
- [ ] Output to file (-o flag)
- [ ] Checksum comparison modes (--compare)

## 🐛 Known Issues / Gaps

- No automated vendor binary comparison (P1 candidate)
- Snapshot maintenance requires manual UPDATE_SNAPSHOTS=1 (acceptable for now)

## 🔧 Implementation Notes

### Fixture Isolation Pattern

- Each corpus case calls `restore_all_fixtures()` before test execution
- Mutations applied after restoration ensures clean baseline
- `after_all` hook in corpus spec restores all fixtures after suite completion
- Committed canonical originals stored in `spec/fixtures/originals/` (tests restore from these; runtime `.orig` backups are ignored).

### Snapshot Updating

```bash
UPDATE_SNAPSHOTS=1 crystal spec  # Create/update all snapshots
```

This overwrites snapshots, so review diffs before committing.

### Running Specific Test

```bash
crystal spec -v --match "detects modified"
```

### Test Architecture Decision

- Corpus: JSON file listing scenarios with args, expected exit code, snapshot paths
- Corpus Case Struct: name, args, stdin_fixture, stdin_tty, mutations[], exit_code, snapshots
- Helper: Loads corpus, manages fixtures, runs CLI.run(), asserts snapshots
- CLI.run: Accepts injected stdin/stdout/stderr + stdin_tty flag for deterministic testing

This avoids shell subprocess testing and keeps assertions fast and reliable.
