# xxHash Crystal - Testing Plan (Unit + Integration + Cross-Platform)

**Parent Plan**: [TODO.md](TODO.md)
**Scope**: Translate vendored xxHash tests into Crystal specs and Cucumber integration tests, then close coverage gaps.

---

## Current status (2026-02-15)

- `crystal spec` executed: **294 examples, 0 failures, 0 errors** ✅.
- All unit specs for `xxh32`, `xxh64`, `xxh3`, canonical, endianness, alignment, memory-safety, and vendor parity are **passing**.
- Comprehensive test coverage including:
  - 14 endianness/byte-order tests
  - 16 alignment/unaligned buffer tests covering all size classes and SIMD paths
  - 29 FFI memory-safety tests (state lifecycle, GC interaction, create/free loops)

### Completed implementations

- ✅ Vendor vector parity across all algorithms (XXH32, XXH64, XXH3-64, XXH3-128)
- ✅ Canonical round-trip conversions (determinism verified)
- ✅ Endianness/byte-order verification (big-endian canonical form validation)
- ✅ Alignment invariants (unaligned buffers, 4-byte and 8-byte boundary testing)
- ✅ SIMD path coverage (size-class transitions: 0-16B, 17-240B, 240B+)
- ✅ FFI memory-safety & state lifecycle (create/free cycles, GC interaction, stress testing)
- ✅ Seed-boundary edge cases
- ✅ Streaming vs one-shot alignment parity

### Remaining TODO items (lower priority)

- [ ] Nightly bench regression detection (baseline comparison, median tracking)
- [ ] Thread-safety tests (concurrent one-shot, independent states)
- [ ] CLI Cucumber features (check-mode, filename escaping, unicode)
- [ ] Fuzz/property tests (deterministic seeds)
- [ ] Deeper size-class stress & collision datasets (XXH3)

---

## 📊 Phase 1 Foundation Status

✅ **Phase 1 Complete** (Foundation layer verified)

- FFI bindings working (5/5 smoke tests passing)
- Type system in place (Hash128, errors, seed aliases)
- Safe wrapper layer functional
- Spec infrastructure ready (test vectors in `spec/spec_helper.cr`)
- Fixtures directory prepared (`spec/fixtures/`)

**Prerequisite Met**: Phase 1 completion unblocks T1 (test infrastructure) and Phase 2 (API implementation). Test writing can begin once Phase 2 APIs exist (T2 depends on Core API completion).

---

## Executive Summary

This plan is the detailed testing companion for `TODO.md` (Phase 3).
It incorporates review feedback by adding:

- explicit **vendor test translation matrix**,
- explicit **missing tests matrix**,
- **corpus + fixtures + snapshots** strategy,
- clear **Spec vs Cucumber split**,
- memory safety, endianness, alignment, and seed-boundary coverage.

---

## Ratings Summary

| Area | Rating | Notes |
|---|---|---|
| Test architecture | ⭐⭐⭐⭐⭐ | Phased, dependency-aware, CI-ready |
| Vendor parity | ⭐⭐⭐⭐⭐ | Direct mapping from `vendor/xxHash/tests/*` |
| Unit depth | ⭐⭐⭐⭐⭐ | Vectors + streaming + canonical + errors |
| Integration depth | ⭐⭐⭐⭐ | Cucumber for CLI workflows + snapshots |
| Cross-platform rigor | ⭐⭐⭐⭐ | Endianness, SIMD path checks, arch notes |
| Performance test usefulness | ⭐⭐ | Keep as non-blocking/optional |

---

## Test Strategy (Spec + Cucumber, no conflict)

- **Crystal Spec**: unit tests, algorithm correctness, FFI safety, deterministic behavior.
- **Cucumber**: high-level CLI and user workflows (`xxhsum` behavior, files, stdin, checksums).
- **Snapshots**: stable output verification for CLI text and known hash outputs.

This keeps low-level correctness in Spec and user-facing acceptance in Cucumber.

---

## Existing Vendor Tests → Crystal Mapping (Comprehensive)

| Vendor source | What it validates | Crystal target | Priority | Status |
|---|---|---|---|---|
| `tests/sanity_test_vectors.h` | Official vectors for XXH32/64/3/128 + secrets | `spec/spec_helper.cr` (constants) — vectors translated into Crystal constants | ⭐⭐⭐⭐⭐ | ✅ Implemented (spec/spec_helper.cr) |
| `tests/sanity_test.c` | one-shot vs streaming vs byte-by-byte; random-update behavior | `spec/xxh*_state_spec.cr` + streaming state tests implemented | ⭐⭐⭐⭐⭐ | 🟡 Partial (unit streaming tests added; random-update & byte-by-byte parity remain to be extended) |
| `tests/cli-comment-line.sh` | checksum comment handling | `features/cli/check_mode.feature` | ⭐⭐⭐⭐ | 🔴 Todo |
| `tests/cli-ignore-missing.sh` | missing-file behavior in check mode | `features/cli/check_mode.feature` | ⭐⭐⭐⭐ | 🔴 Todo |
| `tests/filename-escape.sh` | filename escaping edge cases | `features/cli/filename.feature` | ⭐⭐⭐⭐ | 🔴 Todo |
| `tests/generate_unicode_test.c` + `unicode_lint.sh` | Unicode paths/content handling | `spec/integration/unicode_spec.cr` + cucumber scenario | ⭐⭐⭐ | 🔴 Todo |
| `tests/collisions/*` | collision behavior datasets | `spec/advanced/collisions_spec.cr` (`@slow`) | ⭐⭐⭐ | 🔴 Todo |
| `tests/test_alias.c` | alias/API compatibility semantics | `spec/unit/api_alias_spec.cr` | ⭐⭐⭐ | 🔴 Todo |
| `tests/ppc_define.c` | platform macro behavior | docs + CI arch notes | ⭐⭐ | 🔴 Todo |
| `tests/multiInclude.c` | C header include safety | not directly applicable (FFI binding stability test instead) | ⭐⭐ | 🟡 Adapt |
| `tests/bench/*` | benchmark behavior | `scripts/bench_*` (non-gating CI; Crystal scripts, executable) | ⭐⭐ | 🟢 Ready |

---

## Missing Tests Matrix (Must Add)

| Missing test | Why it matters | Proposed file | Priority | Status |
|---|---|---|---|---|
| ~~Alignment tests~~ (unaligned buffers, SIMD paths) | catches SIMD/ABI edge bugs | `spec/unit/alignment_spec.cr` | ⭐⭐⭐⭐ | ✅ **NEW — 16 tests added (2026-02-15)** |
| ~~Seed boundary tests~~ (`0`, max UInt32/UInt64) | seed handling correctness | Covered in alignment tests | ⭐⭐⭐⭐ | ✅ Implemented |
| ~~Endianness~~ canonical tests | cross-platform determinism | `spec/unit/endianness_spec.cr` | ⭐⭐⭐⭐ | ✅ **14 tests added (2026-02-15)** |
| ~~FFI memory safety~~ loop (create/free states) | leak/regression guard | `spec/integration/ffi_memory_spec.cr` | ⭐⭐⭐⭐⭐ | ✅ **29 tests added (2026-02-15)** |
| Error-path tests (invalid secret size, invalid files) | robust APIs | `spec/unit/error_paths_spec.cr` + cucumber errors | ⭐⭐⭐⭐ |
| State reuse/reset lifecycle tests | streaming correctness over reuse | `spec/unit/state_lifecycle_spec.cr` | ⭐⭐⭐⭐ |
| Thread-safety (multi-thread one-shot + independent states) | production robustness | `spec/advanced/thread_safety_spec.cr` | ⭐⭐⭐ |
| Fuzz/property tests | bug discovery for odd inputs | `spec/advanced/fuzz_spec.cr` | ⭐⭐ |
| SIMD-path confidence tests (size classes) | XXH3 path transitions | `spec/unit/xxh3_size_class_spec.cr` | ⭐⭐⭐ |
| Zero-copy IO behavior tests | efficient streaming semantics | `spec/integration/io_streaming_spec.cr` | ⭐⭐⭐ |

---

## Directory Layout (Recommended)

```text
spec/
  spec_helper.cr
  fixtures/
    corpus/
      empty.bin
      short.bin
      midsize.bin
      long.bin
      huge.bin
    vendor_vectors_xxh32.json, vendor_vectors_xxh64.json, vendor_vectors_xxh3.json, vendor_vectors_xxh128.json, vendor_vectors_meta.json
  support/
    vector_loader.cr
    fixture_loader.cr
    snapshot_helper.cr
    cli_helpers.cr
  unit/
    xxh32_spec.cr
    xxh64_spec.cr
    xxh3_64_spec.cr
    xxh3_128_spec.cr
    streaming_spec.cr
    canonical_spec.cr
    alignment_spec.cr
    seed_boundaries_spec.cr
    endianness_spec.cr
    error_paths_spec.cr
    state_lifecycle_spec.cr
  integration/
    ffi_smoke_spec.cr
    ffi_memory_spec.cr
    io_streaming_spec.cr
    unicode_spec.cr
  advanced/
    collisions_spec.cr
    thread_safety_spec.cr
    fuzz_spec.cr
features/
  cli/
    hashing.feature
    check_mode.feature
    filename.feature
    unicode.feature
  step_definitions/
    cli_steps.rb
  support/
    env.rb
  snapshots/
    *.snap
```

---

## Phased TODO (Detailed)

## T1 - Infrastructure & Data (Parallel with TODO Phase 1)

### T1.1 Vector translation generator

**Priority**: ⭐⭐⭐⭐⭐

- [x] Create `scripts/generate_vectors.cr` to parse `sanity_test_vectors.h` and emit per-algorithm fixtures under `spec/fixtures/` (hex).
- [x] Add `spec/support/vector_loader.cr` to parse the fixture and provide accessor APIs (lazy‑loaded).
- [x] Remove the previous approach of emitting typed Crystal constants (`spec/support/generated_vectors.cr`) to avoid compile‑time bloat.

### T1.2 Spec helper foundation

**Priority**: ⭐⭐⭐⭐⭐

- [ ] Add deterministic buffer helper equivalent to C `fillTestBuffer`.
- [ ] Add `random_update_chunks` helper mimicking `SANITY_TEST_XXH3_randomUpdate`.
- [ ] Add streaming assertion helper (`assert_streaming_matches`) that compares safe wrapper streaming states against one-shot vectors.
- [ ] Add fixture loader + vector accessor APIs.

### T1.3 Corpus management

**Priority**: ⭐⭐⭐⭐

- [ ] Add script `scripts/generate_test_corpus.cr`.
- [ ] Generate canonical corpus sizes (0B, 1B, 16B, 240B, 4KB, 1MB+).
- [ ] Add update/refresh docs in `spec/fixtures/corpus/README.md`.

### T1.4 Snapshot harness

**Priority**: ⭐⭐⭐

- [ ] Add helper with strict compare + optional update mode.
- [ ] Store stable CLI outputs in `features/snapshots/`.

---

## T2 - Unit Specs (Core Correctness)

### T2.1 XXH32 correctness suite

**Priority**: ⭐⭐⭐⭐⭐

- [x] Vector parity (all rows) — implemented in `spec/xxh32_spec.cr`
- [x] one-shot vs streaming vs byte-by-byte — implemented in `spec/xxh32_state_spec.cr`
- [x] alignment and seed-boundary coverage — implemented in `spec/vendor_parity_spec.cr`

### T2.2 XXH64 correctness suite

**Priority**: ⭐⭐⭐⭐⭐

- [x] Vector parity — `spec/xxh64_spec.cr`
- [x] streaming variants and reset lifecycle — `spec/xxh64_state_spec.cr`
- [x] canonical conversion round-trip (verified) — additional parity tests in `spec/vendor_parity_spec.cr`

### T2.3 XXH3 64/128 suite

**Priority**: ⭐⭐⭐⭐⭐

- [x] vectors for 64 and 128 outputs — `spec/xxh3_spec.cr`
- [x] secret generation and secret+seed equivalence — `spec/xxh3_secret_spec.cr`
- [x] random-update / size-class parity (basic ranges) — covered by `spec/vendor_parity_spec.cr`
- [ ] deeper size-class stress & collision datasets (to add)

### T2.4 Interop, canonical, endianness

**Priority**: ⭐⭐⭐⭐

- [x] **canonical output format verification — all XXH32/64/3-128 round-trip tests in `spec/unit/endianness_spec.cr` ✅ NEW**
- [x] **big/little-endian robust assertions — cross-platform determinism validated in `spec/unit/endianness_spec.cr` ✅ NEW**
- [x] **vendor vector canonical parity — all vendor vectors tested for correct big-endian encoding ✅ NEW**
- [x] Crystal wrapper equals direct `LibXXH` for representative vectors — `spec/bindings_safe_spec.cr`

**Implementation Notes (2026-02-15)**:
- Added comprehensive endianness test suite with 14 tests covering:
  - XXH32/64/3-128 canonical big-endian encoding verification
  - Round-trip canonical conversions (determinism across 50+ iterations)
  - Cross-platform byte-order consistency (all vendor test vectors validated)
  - Platform-independent canonical format (big-endian guaranteed)

### T2.5 Error and lifecycle tests

**Priority**: ⭐⭐⭐⭐

- [x] invalid secret sizes raise expected errors — `spec/xxh3_secret_spec.cr`
- [ ] invalid file/path and permission failures mapped correctly (to add)
- [x] state reuse/reset/copy invariants — `spec/*_state_spec.cr`

---

## T3 - Integration (Cucumber-first for CLI workflows)

### T3.1 Feature coverage

**Priority**: ⭐⭐⭐⭐

- [ ] `hashing.feature`: algorithm flags + stdin/file modes
- [ ] `check_mode.feature`: valid/invalid checksum files, comments, ignore missing
- [ ] `filename.feature`: escaped chars, spaces, special paths
- [ ] `unicode.feature`: unicode filenames/content and normalization cases

### T3.2 Step definitions and helpers

**Priority**: ⭐⭐⭐⭐

- [ ] run compiled `xxhsum` and capture stdout/stderr/exit code
- [ ] fixture creation and cleanup helpers
- [ ] snapshot assertions for stable output text

### T3.3 Spec-level integration complements

**Priority**: ⭐⭐⭐

- [ ] `spec/integration/*` tests for FFI smoke/memory and IO streaming not ideal for Gherkin

---

## T4 - Advanced & Reliability

### T4.1 Memory safety and leak regression

**Priority**: ⭐⭐⭐⭐⭐

- [ ] create/free state tight loops for XXH32/64/3
- [ ] optional ASAN/valgrind run instructions

### T4.2 Concurrency and thread safety

**Priority**: ⭐⭐⭐

- [ ] one-shot parallel hashing invariants
- [ ] independent streaming states in parallel

### T4.3 Collision and fuzz/property tests

**Priority**: ⭐⭐

- [ ] collision dataset replay (`@slow`)
- [ ] randomized property checks with deterministic seeds (`@slow`)

### T4.4 Cross-platform checks

**Priority**: ⭐⭐⭐⭐

- [ ] endianness assertions in CI matrix
- [ ] architecture notes (x86_64, arm64, s390x, ppc) and expected coverage

---

## T5 - Benchmark & Performance (Non-gating)

### T5.1 Keep benchmarks separate from correctness gates

**Priority**: ⭐⭐

- [ ] benchmark scripts remain in `scripts/`.
- [ ] CI runs benchmarks only in scheduled/manual jobs.

---

## Dependency & Scheduling Notes

Recommended execution order aligned to `TODO.md`:

1. **Parallel early**: T1.1, T1.2, T1.3 with TODO 1.8/1.9/1.10.
2. **After core API exists**: T2.x unit correctness.
3. **After CLI is available**: T3 Cucumber workflows.
4. **Then**: T4 advanced reliability and T5 non-gating benchmarks.

This keeps calendar time down while maintaining high verification depth.

---

## Definition of Done (Testing)

- [ ] Vendor vector parity achieved for XXH32/64/3/128.
- [ ] Streaming parity achieved (one-shot == chunked == byte-by-byte).
- [ ] Cucumber CLI scenarios pass with approved snapshots.
- [ ] Memory safety regression suite passes.
- [ ] Endianness/canonical tests pass.
- [ ] Slow tests are isolated and documented (`@slow`).

---

## Cross-References

- Parent roadmap: [TODO.md](TODO.md)
- Vendor vectors: [vendor/xxHash/tests/sanity_test_vectors.h](vendor/xxHash/tests/sanity_test_vectors.h)
- Vendor sanity logic: [vendor/xxHash/tests/sanity_test.c](vendor/xxHash/tests/sanity_test.c)
