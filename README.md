# cr-xxhash

[![Crystal CI - Fast (PR smoke)](https://github.com/wstein/cr-xxhash/actions/workflows/ci-fast.yml/badge.svg)](https://github.com/wstein/cr-xxhash/actions/workflows/ci-fast.yml)
[![Verify generated vendor vectors](https://github.com/wstein/cr-xxhash/actions/workflows/check-generated-vectors.yml/badge.svg)](https://github.com/wstein/cr-xxhash/actions/workflows/check-generated-vectors.yml)

High-performance Crystal implementation and migration study of Yann Collet's xxHash (C → Crystal). This project explores achieving near-native throughput using LLVM intrinsics, pointer arithmetic, and SIMD unrolling within the Crystal Language ecosystem.

## Mission Highlights

* [ ] Port the streaming and one-shot XXH32/XXH64/XXH3 APIs to idiomatic Crystal.
* [ ] Maintain bit-identical outputs to the upstream C99 implementation across endianness modes.
* [ ] Deliver SIMD-accelerated LLVM paths that approach native C performance for modern CPUs.
* [ ] Document the architectural trade-offs in an arc42-style migration paper.

## ⚠️ Important: C bindings (FFI) available / hybrid default

This shard now ships and exposes full `LibXXH` C99 bindings (vendored `vendor/xxhash-wrapper`) and uses the C implementation for core one-shot paths by default (hybrid approach). Small Crystal helpers and streaming states remain available in Crystal.

```crystal
# Recommended: public Crystal API (C-backed for one-shot)
XXH::XXH32.hash(data)        # 32-bit — now calls vendored C
XXH::XXH64.hash(data)        # 64-bit (default) — C-backed
XXH::XXH3.hash(data)         # Modern 64-bit — C-backed

# Direct FFI usage also available (exported in `src/vendor/bindings.cr`)
LibXXH.XXH32(ptr, len, seed)
LibXXH.XXH64(ptr, len, seed)
LibXXH.XXH3_64bits(ptr, len)
```

Notes:

* `vendor/xxhash-wrapper` is built automatically in `shards install` via Meson/Ninja (see `postinstall`).
* Streaming/State APIs remain implemented in Crystal for parity and low-overhead streaming; we can switch those to C on request.

**CLI SIMD Control**: Use `--simd BACKEND` flag to select a specific SIMD variant:

```bash
./bin/xxhsum --simd scalar   # Force scalar (no SIMD, always works)
./bin/xxhsum --simd neon     # Force ARM NEON (aarch64, requires CPU support)
./bin/xxhsum --simd sve      # Force ARM SVE (aarch64, requires CPU support)
./bin/xxhsum --simd sse2     # Force x86 SSE2 (x86_64, requires CPU support)
./bin/xxhsum --simd avx2     # Force x86 AVX2 (x86_64, requires CPU support)
./bin/xxhsum --simd avx512   # Force x86 AVX-512 (x86_64, requires CPU support)
```

**Note**: After the xxhash-wrapper refactor, SIMD variants are compiled unconditionally with platform-specific CPU flags. If your CPU doesn't support the requested variant, the process will raise `SIGILL`. Always use `--simd scalar` if CPU support is unknown, or use a high-level API that hides variant selection.

## Native Implementation Roadmap

**Status**: ✅ **Project Complete** — All algorithms (XXH32, XXH64, XXH3 64-bit and 128-bit) have complete native implementations with benchmark parity. The project concluded that **LLVM auto-vectorization** (using `StaticArray` and `@AlwaysInline`) provides a maintainable 30 GB/s for XXH3, while XXH32/XXH64 achieve near-native performance with `-O3` optimizations. No further handwritten SIMD assembly is planned.

**Final Findings:**

* **Auto-Vectorization vs. Manual SIMD**: LLVM successfully auto-vectorizes the 8-lane accumulator loops in XXH3 to ~30 GB/s (vs. ~50 GB/s for manual C SIMD).
* **Parity**: XXH32 and XXH64 performance in Crystal with `-O3` is virtually identical to the original C99 implementation on modern hardware.
* **Architecture**: The `StaticArray` + `@[AlwaysInline]` pattern proved sufficient for performance targets without the complexity of platform-specific intrinsics.

**Recent Updates (Session 6–8 + Refactoring Phase 1):**

* **Session 6 (Phase 2) — Micro optimizations:**
  * Precomputed mask and reduced per-call u128 math in `XXH3` mixing (`mix16b`) (medium impact)
  * Replaced `to_u128` casts with wrapping 64-bit arithmetic in hot paths (`mult32to64_add64`, secret init loops) (medium impact)
  * Verified/reduced pointer arithmetic in inner loops where possible (`accumulate_scalar`, `hash_long_internal_loop`) (low→medium impact)

* **Session 7 (Phase 3) — LLVM Auto-Vectorization Foundation:**
  * ✅ Replaced heap-allocated `Array(UInt64)` with stack-allocated `StaticArray(UInt64, 8)` in all hot paths (`hash_long_*`, `accumulate_*`, `scramble_acc_*`)
  * ✅ Added `@[AlwaysInline]` annotations to accumulation functions for improved inlining in tight loops
  * ✅ Refactored `mix2accs` to handle StaticArray indexing properly
  * **Vectorization Readiness**: LLVM can now auto-vectorize accumulator operations because:
    * Stack-allocated fixed-size arrays trigger LLVM's loop vectorizer
    * Contiguous memory layout (no bounds checks) enables SIMD analysis
    * Removed pointer indirection for small fixed-size working sets
  * **Expected Improvements**: 20-40% throughput gains for long inputs (240B+) via 2x-4x SIMD unrolling
  * See [SIMD_OPTIMIZATION_STRATEGY.md](SIMD_OPTIMIZATION_STRATEGY.md) for detailed vectorization analysis

* **Session 8 (Phase 4) — Loop Unrolling & Prefetch:**
  * ✅ Implemented 2-stripe unroll in `xxh3.accumulate_scalar` with light prefetch (128B lookahead)
  * ✅ Implemented 2×32B unroll in `xxh64.consume_long` for instruction-level parallelism
  * ✅ Tuned XXH32 `consume_long` to 4×16B unroll (64B per iteration) → **~13 GB/s** (target met)
  * ✅ Final benchmarks: XXH32 ~12.98 GB/s, XXH64 ~25.7 GB/s, XXH3 ~28.6 GB/s, XXH128 ~30 GB/s
  * All 167 tests pass; zero regressions

* **Refactoring Phase 1 (Code Modularity):**
  * ✅ Created `src/xxh3/` subdirectory with 4 focused modules:
    * `xxh3_types.cr`: `UInt128` helpers (high/low accessors, canonical formatting)
    * `xxh3_base.cr`: 650+ lines of shared helpers, accumulation, scrambling, merging
    * `xxh3_64.cr`: 64-bit one-shot and long-input hashing
    * `xxh3_128.cr`: 128-bit one-shot and long-input hashing
  * ✅ Refactored main `xxh3.cr`: reduced from 1,036 → 280 lines (73% reduction)
  * ✅ Eliminated ~60% code duplication between 64-bit and 128-bit variants
  * ✅ All 167 tests passing; clean git history with atomic commit
  * **Next**: Phase 2 (Extract XXH32/XXH64 shared streaming base)

* **Refactoring Phase 2 (Streaming Consolidation):** ✅ **COMPLETED**
  * ✅ Consolidated streaming helpers into per-algorithm `state.cr` modules (e.g. `src/xxh3/state.cr`, `src/xxh32/state.cr`, `src/xxh64/state.cr`) — removed prior shared helper duplication
  * ✅ Refactored `XXH32::State.update_slice`: 60 → 30 lines (-50% duplication)
  * ✅ Refactored `XXH64::State.update_slice`: 60 → 30 lines (-50% duplication)
  * ✅ Eliminated ~64 lines of duplicated buffer management logic across both classes
  * ✅ Block delegation pattern retained where helpful; FFI-backed states used for streaming to ensure O(1) memory
  * ✅ All 167 tests passing; zero performance regression; 100% API compatibility
  * **Code Metrics**: XXH32::State 150→115 lines (-23%), XXH64::State 150→115 lines (-23%), Net -64 lines

* **Refactoring Phase 3 (XXH3 State/State128 Consolidation):** ✅ **COMPLETED** (2026-02-09)
  * ✅ Implemented shared streaming base in `src/xxh3/state.cr` (`XXH::XXH3::StreamingStateBase`)
  * ✅ Refactored `State` and `State128` to inherit from the shared base class
  * ✅ **Code Reduction**:

    | Before | After | Reduction |
    |--------|-------|-----------|
    | State: ~200 lines | State: ~45 lines | -155 lines |
    | State128: ~200 lines | State128: ~45 lines | -155 lines |
    | Duplicated: ~310 lines | Base + 2 subclasses: ~240 lines | ~23% reduction |

  * ✅ All 171 tests pass; zero regressions; API unchanged
  * ✅ Benefits: DRY, maintainable, extensible, backward compatible

* ✅ **Performance Optimizations Applied**: Implemented 8 high-impact scalar speedups:
  * Added `@[AlwaysInline]` to 9 XXH3 functions, 3 XXH64 functions, 3 XXH32 functions
  * Replaced iterator loops with `while` loops in hot paths
  * Optimized pointer arithmetic to use increments instead of multiplications per iteration
  * Precomputed `MASK64` constant to avoid expensive bit shifts
  * Replaced `.tdiv` with `/` where appropriate (with `.to_i` casts)
  * Expected gains: 20-30% for small inputs (0-16B), 15-25% for medium (17-240B), 10-15% for large (240B+)
  * See [SESSION_5_PERFORMANCE_OPTIMIZATIONS.md](SESSION_5_PERFORMANCE_OPTIMIZATIONS.md) for detailed breakdown

## Bindings Architecture

The project maintains a clear separation between FFI definitions and safe wrappers:

* `src/bindings/lib_xxh.cr` — **Low-level FFI bindings** (defines `lib LibXXH`; links to C object file)
* `src/bindings/safe.cr` — **Safe wrapper layer** (provides idiomatic Crystal APIs; delegates to FFI)

Each algorithm folder (`src/xxh32/`, `src/xxh64/`, `src/xxh3/`) then implements:
* `state.cr` — Streaming state classes (manages FFI state lifecycle)
* `hasher.cr` — Public one-shot API (delegates to safe bindings, accepts `Bytes`/`String`)
* `canonical.cr` — Canonical form conversions (optional)

### Bindings API Pattern

The safe bindings layer uses **explicit unseeded/seeded overloads** (no defaulted parameters):
  - `Bindings::XXH32.hash(data : Bytes)` — unseeded
  - `Bindings::XXH32.hash(data : Bytes, seed : UInt32)` — seeded
  - Similar pattern for XXH64, XXH3_64, XXH3_128

This avoids runtime branching and improves call-site clarity.

### Single-responsibility principle:
- **lib_xxh.cr**: "Map C to Crystal types"
- **safe.cr**: "Wrap unsafe pointers in safe APIs"
- **Algorithm modules**: "Implement the public API"

## Folder conventions (per-algorithm)

Each algorithm implementation follows a small, consistent folder schema to keep code easy to navigate and extend. Create new algorithm folders using this layout:

* `wrapper.cr` — Public API, one-shot helpers, and factory functions (always required)
* `state.cr` — Streaming State implementation (FFI-backed for vendor/state where applicable)
* `types.cr` — Optional small type definitions (now using native `UInt128` for 128-bit hashes) when needed

Example:

```
src/xxh3/
  ├── state.cr      # StreamingStateBase, State, State128
  ├── wrapper.cr    # public API: hash, hash_with_seed, new_state(...)
  └── types.cr      # Hash128 struct (optional)
```

Follow this convention for any future algorithm folders to ensure consistency and easy discovery.

* ✅ **Session 7 — SIMD Foundation**: Prepared the codebase for LLVM auto-vectorization by replacing heap-allocated accumulators with stack-allocated `StaticArray` buffers and adding aggressive inlining. See `papers/SIMD_OPTIMIZATION.adoc` for the full Session 7 report and verification guidance.

**Recent Fixes (Session 3):**

* ✅ Implemented XXH3 128-bit Phase 3 (240+B) native path: ported `hash_long_128b` and `finalize_long_128b` from vendor specification. Eliminates FFI fallback for all 128-bit input sizes.
* ✅ Fixed XXH3 128-bit Phase 1 (0–16B) simple path bug (Session 2): corrected dispatcher to include 1–3 byte inputs and used the correct `XXH64` avalanche.

**Phase 1 & 2 - Scalar Fundamentals** (COMPLETE ✅):

* ✅ **XXH32**: All 20/20 tests passing. Native implementation in use in CLI.
* ✅ **XXH64**: All 16/16 tests passing. Complete scalar implementation with streaming support.
  * One-shot hashing: Short (< 32B) and long (≥ 32B) paths
  * Streaming: Full State class with buffer management and 32-byte lane processing
  * Seeding: Full support for seeded variants
  * Tail processing: Proper handling of 8-byte, 4-byte, and single-byte chunks
* ✅ **XXH3 64-bit**: All 127/127 tests passing. Complete native implementation (0B–10000B+)
  * One-shot: All input sizes via phase dispatching (0–16B, 17–240B, 240B+)
  * Streaming: Full State class with buffer management and edge-case handling ✅
  * Seeding: Full support for seeded variants ✅
  * Edge cases: 104 tests + 23 comprehensive edge-case tests covering boundaries, chunks, resets ✅
* ✅ **XXH3 128-bit**: All 31/31 tests passing. Complete native implementation (0B–10000B+) ← **NEW Session 3**
  * Phase 1 (0–16B): Complete with all subpaths (0B empty, 1–3B, 4–8B, 9–16B) ✅
  * Phase 2a (17–128B): Complete stripe-based mixing ✅
  * Phase 2b (129–240B): Complete multi-stripe with avalanche ✅
  * Phase 3 (240B+): **NEW native `hash_long_128b` implementation** — eliminates FFI fallback ✨
  * Seeding: Full support for all phases with custom secret derivation ✅
  * Testing: 7 unseed tests + 3 seeded tests across all phases ✅
* ✅ CLI dispatch: SIMD flag (`--simd=auto|scalar|sse2|avx2|neon`) fully integrated. Framework ready for SIMD variants.
* ✅ Deprecation warnings: FFI bindings now show one-shot deprecation warning when used directly.

**Planned Phases** (Conclusion):

| Phase | Target | Algorithms | Performance | Status |
| --- | --- | --- | --- | --- |
| **P1** | Scalar fundamentals | XXH32, XXH64, XXH3 (all variants) | ~85% C throughput | ✅ **Complete** |
| **P1** | CPU dispatch | Detection + routing | N/A | ✅ **Complete** |
| **P2** | SIMD/Auto-vec | LLVM Optimization | 25–30 GB/s (XXH3) | ✅ **Complete (Final)** |
| **P2a** | ARM NEON | LLVM Auto-vec | ~25–30 GB/s | ✅ Reached via Auto-vec |
| **P2b** | x86 AVX2 | LLVM Auto-vec | ~25–30 GB/s | ✅ Reached via Auto-vec |
| **P3** | Fiber-based I/O | Parallel file processing | N/A | 🟦 Future/Out of scope |
| **P4** | x86 AVX-512 | LLVM Auto-vec | TBD | 🟦 Future/Out of scope |

**Implementation Details**: See [Migration Paper § 12: Native Implementation Strategy](papers/migration/12_native_implementation_strategy.adoc)

**Key Design Principles**:

* **Zero-copy**: Reusable static buffers, pointer arithmetic for hot paths
* **SIMD dispatch**: Runtime CPU detection with compile-time fallback selection
* **Idiomatic Crystal**: Public API remains safe; unsafe blocks internally documented
* **Bit-identical**: 100% test vector parity with vendor C implementation

**Getting Involved**:

* Interested in porting SIMD paths? See [papers/CONTRIBUTING.adoc](papers/CONTRIBUTING.adoc) for intrinsic patterns
* Want to benchmark? Run `./bin/xxhsum -b -Dnative` (future: switches to native when P1 complete)
* Found issues? Validate against the FFI baseline (`LibXXH.*`) for reference — the canonical FFI binding lives at `src/bindings/lib_xxh.cr`. If you need to update the FFI definitions, edit that file and rebuild `vendor/xxhash-wrapper` (e.g., `meson setup vendor/xxhash-wrapper/build --wipe && meson compile -C vendor/xxhash-wrapper/build`) before running specs. Prefer native implementation parity checks via the public `XXH::*` helpers.

## Migration Paper

For architectural depth, see the **[Migration Study: C99 → Crystal](papers/MIGRATION.adoc)** which maps each arc42 view to the Crystal implementation. Section 12 details the native implementation strategy, including SIMD dispatch, memory layout, and performance targets.

## Current Environment (Study Reference)

| Tool | Version / Platform |
| --- | --- |
| Crystal | 1.19.1 (installed via `crystal` 1.19.1) |
| LLVM | 21.1.8 (`llvm-config`) |
| Apple Clang | 17.0.0 |
| macOS | 26.2 (ARM64/Apple Silicon) |

## Requirements

* Crystal >= 1.19.1
* LLVM >= 10 with SIMD instruction support (AVX2/AVX-512, or NEON on ARM)
* macOS 12+ or equivalent Linux distribution (support for more platforms coming in future studies)

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  cr-xxhash:
    github: wstein/cr-xxhash
```

## Usage

### Library API

```crystal
require "cr-xxhash"

# One-shot hashing (unseeded)
hash64 = XXH3.hash64("hello world")
hash128 = XXH3.hash128("hello world")

# One-shot hashing (seeded)
hash64_s = XXH3.hash64("hello world", 42_u64)
hash128_s = XXH3.hash128("hello world", 42_u64)

puts "XXH3_64: #{hash64.to_s(16)}"
puts "XXH3_128: #{hash128.to_hex32}"

# Streaming example (128-bit)
state = XXH::XXH3.new_state128
state.update("hello")
state.update(" world")
h = state.digest
puts "XXH3_128 streaming: low=0x#{h.low64.to_s(16)}, high=0x#{h.high64.to_s(16)}"

# Reset with a seed (streaming with seed)
# You can initialize with a seed or call `reset(seed)` to reuse the state for a new seeded hash.
state = XXH::XXH3.new_state128(0_u64)
state.update("test")
puts "seeded (0) => #{XXH::XXH3.hash128("test", 0_u64).low64.to_s(16)}"
state.reset(42_u64)
state.update("test")
puts "seeded (42) => #{XXH::XXH3.hash128("test", 42_u64).low64.to_s(16)}"

# 64-bit equivalent reset usage
state64 = XXH::XXH3.new_state(0_u64)
state64.update("foo")
state64.reset(123_u64)
state64.update("bar")
puts "XXH3_64 streaming with seed: #{state64.digest.to_s(16)}"

# State copying: branch from one state to compute multiple hashes
state_base = XXH::XXH3::State64.new
state_base.update("common prefix")

# Create independent copy for branch 1
branch1 = state_base.copy
branch1.update(" branch 1 suffix")
hash1 = branch1.digest

# Create independent copy for branch 2
branch2 = state_base.copy
branch2.update(" branch 2 suffix")
hash2 = branch2.digest

puts "Branch 1: #{hash1.to_s(16)}"
puts "Branch 2: #{hash2.to_s(16)}"
# Both branches started from same state but produced different results

> Tip: `State#update` accepts both `String` and `Bytes` directly (`update(data : Bytes | String)`), so you can pass `String` values without calling `to_slice`.

### API overloads & examples — quick reference 🔧

- One-shot overloads (unseeded / seeded):
  - `XXH::XXH32.hash(data : Bytes)` / `XXH::XXH32.hash(data : Bytes, seed : UInt32)`
  - `XXH::XXH64.hash(data : Bytes)` / `XXH::XXH64.hash(data : Bytes, seed : UInt64)`
  - `XXH::XXH3.hash64(data : Bytes)` / `XXH::XXH3.hash64(data : Bytes, seed : UInt64)`
  - `XXH::XXH3.hash128(data : Bytes)` → returns `UInt128` / `XXH::XXH3.hash128(data : Bytes, seed : UInt64)`

- Convenience: all one-shot overloads also accept `String` (example):
  - `XXH::XXH3.hash64("hello")`
  - `XXH::XXH3.hash128("hello", 42_u64).to_hex32`

- Streaming / State usage:
  - `state = XXH::XXH3::State128.new` or `XXH::XXH3::State128.new(42_u64)`
  - `state.update("chunk")` accepts `String` or `Bytes`
  - `state.reset(seed)`, `state.digest` (returns `UInt128`)
  - `copy_state = state.copy` — creates an independent deep copy for branching workflows

- `UInt128` helpers:
  - `h = XXH::XXH3.hash128("x")` → accessors: `h.low64`, `h.high64`, `h.to_hex32`, `h.to_bytes`
  - Conversions: `UInt128.from_halves(high, low)`, `UInt128.from_c_hash(c_hash)`

> 💡 Style note: seeded and unseeded behaviors are explicit overloads (no runtime branching). This improves clarity and compile-time dispatch.
```
### CLI Tool

The included `xxhsum` binary provides a command-line interface compatible with the xxHash reference implementation:

```bash
# Build the CLI (automatically compiles vendored xxHash via postinstall hook)
shards build

# Hash a file (default: XXH3)
./bin/xxhsum README.md

# Specify algorithm: XXH32 (-H0), XXH64 (-H1), XXH128 (-H2), XXH3 (-H3)
./bin/xxhsum -H0 README.md
./bin/xxhsum -H1 README.md
./bin/xxhsum -H2 README.md
./bin/xxhsum -H3 README.md

# BSD format output
./bin/xxhsum --tag README.md

# Hash stdin
echo "test data" | ./bin/xxhsum

# Benchmark mode (100 KB sample by default)
./bin/xxhsum -b           # Benchmark default variants 1,3,5,11

# Aliases
The build creates convenient CLI aliases that default to their corresponding algorithms (same behavior as the C reference):

* `xxh32sum` -> XXH32 (equivalent to `xxhsum -H0`)
* `xxh64sum` -> XXH64 (equivalent to `xxhsum -H1`)
* `xxh128sum` -> XXH128 (equivalent to `xxhsum -H2`)
* `xxh3sum` -> XXH3 (equivalent to `xxhsum -H3`)

Examples:

Help and default algorithm are alias-aware. For example:

```bash
echo dfdf | ./bin/xxh32sum        # produces an XXH32 hash
./bin/xxh32sum -h                 # shows "-H# ... (default: 0)"
```

Usage examples:

```bash
./bin/xxh32sum README.md   # same as: ./bin/xxhsum -H0 README.md
./bin/xxh3sum README.md    # same as: ./bin/xxhsum -H3 README.md
```

./bin/xxhsum -b0          # Benchmark all 28 variants
./bin/xxhsum -b3          # Benchmark specific variant (XXH64)
./bin/xxhsum -b1,3,5,11   # Benchmark comma-separated list of variants
./bin/xxhsum --bench-all  # Benchmark all 28 variants (same as -b0)

### Custom sample size for benchmarking

./bin/xxhsum -b -B64K    # Benchmark with 64 KB sample
./bin/xxhsum -b -B256K   # Benchmark with 256 KB sample
./bin/xxhsum -b -B1M     # Benchmark with 1 MB sample

### Custom calibration iterations for benchmarks

./bin/xxhsum -b -i1      # Single calibration iteration (faster, less stable)
./bin/xxhsum -b -i5      # 5 calibration iterations (slower, more stable)

### Performance Reference (Apple M4)

**Build:** `shards build --release -O3 --mcpu=apple-m4`

```
Crystal port of xxhsum 0.8.3
Sample of 100.0 KB...
 1#XXH32                         :     102400 ->   133987 it/s (13084.7 MB/s)
 3#XXH64                         :     102400 ->   265927 it/s (25969.4 MB/s)
 5#XXH3_64b                      :     102400 ->   500763 it/s (48902.6 MB/s)
11#XXH128                        :     102400 ->   497193 it/s (48554.0 MB/s)
```

> **Note:** Throughput varies by input size, CPU, and build flags. Run `./bin/xxhsum -b` on your system for baseline.


<!-- BENCH_TABLE_START -->
# Nightly benchmark — long-input (XXH3, 64-bit)

**Latest run:** 2026-02-15 00:22:26 +01:00

This report converts `bench_long_input_results.csv` into a human-friendly table. The CSV is produced by `scripts/bench_long_input.cr` (oneshot vs streaming throughput measured in MB/s).

| Size | One-shot median (MB/s) | Streaming median (MB/s) | Streaming / One-shot (%) |
| ---: | ---: | ---: | ---: |
| 64 KB | 49581.7 | 19239.16 | 38.8% |
| 256 KB | 49006.31 | 19244.83 | 39.27% |
| 1024 KB | 48408.72 | 19395.49 | 40.07% |

**Summary (average across sizes):** one-shot ~ **48998.91 MB/s**, streaming ~ **19293.16 MB/s** (streaming ≈ **39.38%** of one-shot).

> Note: oneshot uses the public `XXH::XXH3.hash64` fast path; streaming measures `XXH::XXH3::State64` throughput. Values vary by CPU and build flags.

<!-- BENCH_TABLE_END -->


**Build Notes:**

* `shards build` automatically compiles the vendored C xxHash library via the postinstall hook
* Requires `make` and a C compiler (clang/gcc)
* LLVM optimizations enabled for maximum performance
* Aliases (`./bin/xxh32sum`, `./bin/xxh64sum`, `./bin/xxh128sum`, `./bin/xxh3sum`) are created by the postinstall hook and `./bin` is gitignored; to recreate aliases run `shards install` or execute the manual commands from the contributing guide.

## Nix Development (💡)

This repository includes a Nix development configuration to get a reproducible shell for building and testing the project.

### Regenerating vendor test vectors

* Vendor sanity vectors are imported from `vendor/xxhash-wrapper/vendor/xxHash/tests/sanity_test_vectors.h` and emitted to per-algorithm fixtures under `spec/fixtures/` (files named `vendor_vectors_xxh32.json`, `vendor_vectors_xxh64.json`, `vendor_vectors_xxh3.json`, `vendor_vectors_xxh128.json`, plus `vendor_vectors_meta.json`). The runtime loader `spec/support/vector_loader.cr` exposes the vectors to specs (lazy‑loaded to avoid compile‑time bloat).
* To regenerate after upstream updates run:

```bash
crystal scripts/generate_vectors.cr
```

The JSON fixture is consumed by `spec/support/vector_loader.cr` and used by `spec/vendor_generated_vectors_spec.cr` for algorithm parity checks.

## Usage

* Without flakes:

  * Enter the shell: `nix-shell`
  * Inside the shell run: `shards install && crystal spec`

## Notes

* `shard.yml` runs a Meson/Ninja build in `vendor/xxhash-wrapper/build` during `shards install` (see `postinstall`) so the dev shell includes `meson` and `ninja`.
* The `CRYSTAL_PATH` environment variable is set in the shell so the local sources are visible to Crystal.

### GitHub Actions Workflows ✅

**PR Smoke Tests** (`ci-fast.yml`):
- Runs on every PR and push to develop
- Fast unit tests only (~<1 minute)
- Verifies generated vectors are up-to-date
- Generator spec validation
- **Status**: [![Crystal CI - Fast (PR smoke)](https://github.com/wstein/cr-xxhash/actions/workflows/ci-fast.yml/badge.svg)](https://github.com/wstein/cr-xxhash/actions/workflows/ci-fast.yml)

**Vector Generation Check** (`check-generated-vectors.yml`):
- Ensures spec fixtures stay in sync
- Runs on PR and push to develop
- **Status**: [![Verify generated vendor vectors](https://github.com/wstein/cr-xxhash/actions/workflows/check-generated-vectors.yml/badge.svg)](https://github.com/wstein/cr-xxhash/actions/workflows/check-generated-vectors.yml)

**Nightly Benchmarking** (`nightly-bench.yml`):
- Performance regression baseline tracking
- Scheduled daily at 2 AM UTC
- Produces CSV and markdown reports

If you want additional CI matrices or specialized testing, open an issue. ✅

### Verified Test Results ✅

All algorithms validated against vendor xxHash implementation. **Current test suite: 350 examples, 0 failures, 0 errors**.

**Test Coverage (2026-02-15)**:
- ✅ Vendor vector parity (XXH32, XXH64, XXH3-64, XXH3-128)
- ✅ Canonical round-trip conversions (all algorithms)
- ✅ Endianness/byte-order determinism (big-endian validation, cross-platform)
- ✅ Alignment invariants (unaligned buffer handling, all size classes)
- ✅ SIMD path coverage (size-class transitions: 0-16B, 17-240B, 240B+)
- ✅ FFI memory-safety & state lifecycle (create/free cycles, GC interaction, stress testing)
- ✅ UInt128 helpers (high64/low64, canonical bytes, C-struct conversions — `UInt128.from_halves`, `UInt128.from_c_hash`, `#to_c_hash`, `#to_hex32`)
- ✅ Seed-boundary edge cases (0, max values)
- ✅ Streaming vs one-shot parity
- ✅ FFI safe wrapper reliability

**Test Categories**:
| Category | Status |
|----------|--------|
| Unit correctness (vectors, streaming, canonical) | ✅ |
| Endianness & cross-platform | ✅ |
| Alignment & SIMD paths | ✅ |
| FFI memory-safety & lifecycle | ✅ **NEW (2026-02-15)** |
| **Total** | **350** | **✅ All passing** |

Example hashes (README.md, 4.0 KB):

```bash
./bin/xxhsum -H0 README.md
# Output: 6a0ddf61  README.md

./bin/xxhsum -H1 README.md
# Output: a8fe69ba5ce06d72  README.md

./bin/xxhsum -H2 README.md
# Output: 4eda32e63c79e21da8fe69ba5ce06d72  README.md

./bin/xxhsum -H3 README.md
# Output: a8fe69ba5ce06d72  README.md
```

* XXH32: ✅ (all checks + endianness)
* XXH64: ✅ (all checks + endianness)
* XXH128: ✅ (all checks + endianness)
* XXH3: ✅ (all checks + endianness)

See [TODO.md](TODO.md) and [TODO_TESTS.md](TODO_TESTS.md) for planned features and testing roadmap.

## Benchmark Mode (xxhsum -b)

### Overview

The `xxhsum` benchmark mode tests hash throughput using **benchmark IDs 1-28** (different from the `-H0..-H3` algorithm IDs used for hashing). Each ID represents a specific variant combining an algorithm with properties like alignment, seeding, or streaming.

### Benchmark ID Mapping (1–28)

All variants test **aligned (offset +0)** and **unaligned (offset +3)** memory access:

#### Basic Variants (1–6, 11–12)

* 1–2: `XXH32` (aligned/unaligned)
* 3–4: `XXH64` (aligned/unaligned)
* 5–6: `XXH3_64b` (aligned/unaligned)
* 11–12: `XXH128` (aligned/unaligned)

#### Seeded Variants (7–8, 13–14, 23–24, 27–28)

* 7–8: `XXH3_64b w/seed` (aligned/unaligned)
* 13–14: `XXH128 w/seed` (aligned/unaligned)
* 23–24: `XXH3_stream w/seed` (aligned/unaligned)
* 27–28: `XXH128_stream w/seed` (aligned/unaligned)

#### Secret Variants (9–10, 15–16)

* 9–10: `XXH3_64b w/secret` (aligned/unaligned)
* 15–16: `XXH128 w/secret` (aligned/unaligned)

#### Streaming Variants (17–28)

* 17–18: `XXH32_stream` (aligned/unaligned)
* 19–20: `XXH64_stream` (aligned/unaligned)
* 21–22: `XXH3_stream` (aligned/unaligned)
* 25–26: `XXH128_stream` (aligned/unaligned)

### Benchmark Examples

```bash
# Benchmark all 28 variants with auto-tuned iterations
./bin/xxhsum -b

# Benchmark specific variant
./bin/xxhsum -b1          # Only XXH32 (variant 1)

# Multiple variants
./bin/xxhsum -b1,3,5,11   # XXH32, XXH64, XXH3_64b, XXH128

# With custom iteration count
./bin/xxhsum -b1,3,5 -i100

# Quiet mode (suppress version header)
./bin/xxhsum -q -b -i5

# Special aliases (benchmark all)
./bin/xxhsum -b0          # Benchmark all variants
./bin/xxhsum -b29         # Benchmark all variants
./bin/xxhsum -b77         # Benchmark all variants (vendor shorthand)
```

### Output Format

```text
ID#Name                       :   SizeBytes ->   Throughput (MB/s)
 1#XXH32                      :     102400 ->   100000 it/s (9765.6 MB/s)
 3#XXH64                      :     102400 ->   220000 it/s (21484.4 MB/s)
 5#XXH3_64b                   :     102400 ->   400000 it/s (39062.5 MB/s)
11#XXH128                     :     102400 ->   380000 it/s (37109.4 MB/s)
```

### Important Notes

* `-H0..-H3` select algorithms for **hashing**, while `-b#` selects **benchmark variant IDs** (1–28)
* Unaligned variants (IDs ending in even numbers) test performance with data offset by +3 bytes
* Seeded variants use a fixed seed (42) for reproducibility
* Secret variants use a generated secret buffer sized to the XXH3 minimum (`LibXXH::XXH3_SECRET_SIZE_MIN`, 136 bytes)
  * **Note:** The default secret (`XXH3_kSecret` / `LibXXH::XXH_SECRET_DEFAULT_SIZE`) is a hardcoded, static buffer in the vendor headers — keep it hardcoded; it never changes.
* Streaming variants use the streaming API (create state, update, digest, free)
* Auto-tuning (no `-i` flag) targets ~1 second per variant
* IDs 0, 29+, and `-b77` all expand to "benchmark all" (C99 vendor behavior)

For more details, see [BENCHMARK_ID_BEHAVIOR.md](BENCHMARK_ID_BEHAVIOR.md) for a detailed comparison with the C99 implementation. See also: [examples/xxhsum/BENCHMARK_ANALYSIS.md](examples/xxhsum/BENCHMARK_ANALYSIS.md), [examples/xxhsum/DESIGN_RATIONALE.md](examples/xxhsum/DESIGN_RATIONALE.md), [examples/xxhsum/VENDOR_PARITY.md](examples/xxhsum/VENDOR_PARITY.md).

## Future SIMD Architectures (Research Phase)

The following CPU instruction set extensions are candidates for future implementation:

| Architecture | ISA | Status | Notes |
| --- | --- | --- | --- |
| IBM POWER | VSX (Vector Scalar Extension) | 📋 Researching | Supported on IBM Power ISA for enterprise systems |
| ARM | SVE (Scalable Vector Extension) | 📋 Researching | Available on newer Graviton and NEOVERSE processors |
| LoongArch | LSX/LASX | 📋 Researching | LSX (128-bit) and LASX (256-bit) for LoongArch CPUs |
| RISC-V | RVV (Vector Extension) | 📋 Researching | Scalable RISC-V vector standard (0.10-1.0) |
| x86 | AVX-512 | 🔵 Planned | High-end x86-64 (Xeon, Core i9K series) |

These are placeholder entries for potential future support. Implementation priority depends on:

* Community demand and use cases
* Availability of testing hardware
* Crystal compiler support for architecture-specific intrinsics
* Maintainer bandwidth

**Interested in porting to a new architecture?** Please open an issue with:

1. Your target platform and CPU model
2. Proposed SIMD instruction set
3. Performance targets and use cases
4. Availability of testing hardware or CI infrastructure

## Development

See the [Scripts README](scripts/README.md) for tooling help. Contributors should review the [Contributing Guidelines](papers/CONTRIBUTING.adoc).

## Third-party components

This repository is based on the outstanding work of Yann Collet and the xxHash project. Portions of the implementation are vendored from `xxHash` via `vendor/xxhash-wrapper` and are included under the **BSD 2‑Clause** License — see `vendor/xxhash-wrapper/vendor/xxHash/LICENSE` for the original license text and attribution.

## Contributors

* [Werner Stein](https://github.com/wstein) - creator and maintainer (<werner.stein@gmail.com>)
