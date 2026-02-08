# cr-xxhash

High-performance Crystal implementation and migration study of Yann Collet's xxHash (C → Crystal). This project explores achieving near-native throughput using LLVM intrinsics, pointer arithmetic, and SIMD unrolling within the Crystal Language ecosystem.

## Mission Highlights

* [ ] Port the streaming and one-shot XXH32/XXH64/XXH3 APIs to idiomatic Crystal.
* [ ] Maintain bit-identical outputs to the upstream C99 implementation across endianness modes.
* [ ] Deliver SIMD-accelerated LLVM paths that approach native C performance for modern CPUs.
* [ ] Document the architectural trade-offs in an arc42-style migration paper.

## ⚠️ Important: FFI Bindings Deprecation

The current FFI bindings to the vendored C implementation are **deprecated**. For new code, use the native Crystal implementations:

```crystal
# Recommended: Native Crystal implementations
XXH::XXH32.hash(data)        # 32-bit
XXH::XXH64.hash(data)        # 64-bit (default)
XXH::XXH3.hash(data)         # Modern 64-bit

# Deprecated: FFI bindings (backward compatibility only)
LibXXH.XXH32(ptr, len, seed) # Use XXH::XXH32 instead
LibXXH.XXH64(ptr, len, seed) # Use XXH::XXH64 instead
LibXXH.XXH3_64bits(ptr, len) # Use XXH::XXH3 instead
```

**CLI SIMD Control**: Use `--simd=MODE` flag to select implementation:

```bash
./bin/xxhsum --simd=auto     # Auto-detect (default)
./bin/xxhsum --simd=scalar   # Force scalar (no SIMD)
./bin/xxhsum --simd=neon     # Force ARM NEON (Apple Silicon, etc)
./bin/xxhsum --simd=avx2     # Force x86 AVX2
./bin/xxhsum --simd=sse2     # Force x86 SSE2
```

## Native Implementation Roadmap

**Status**: ✅ **Scalar Phase Complete** — All algorithms (XXH32, XXH64, XXH3 64-bit and 128-bit) have complete native implementations for all input sizes (0B–10000B+) with comprehensive test coverage (167/167 tests passing). SIMD dispatch framework is wired in the CLI with the `--simd` flag. **Next phase: SIMD acceleration** (ARM NEON, x86 AVX2, x86 SSE2).

**Streaming Update**: `State128` streaming class implemented and validated (see `spec/xxh3_state_128_spec.cr` — 9 tests). Short unseeded streaming still defers to FFI for parity with existing 64-bit `State` behavior.

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

**Planned Phases** (Next: SIMD Acceleration):

| Phase | Target | Algorithms | Performance | Status |
| --- | --- | --- | --- | --- |
| **P1** | Scalar fundamentals | XXH32, XXH64, XXH3 (all variants) | ~85% C throughput | ✅ **Complete** |
| **P1** | CPU dispatch | Detection + routing | N/A | ✅ **Complete** |
| **P2** | SIMD paths | ARM NEON, x86 AVX2/SSE2 | 15–30 GB/s | 🔵 **Next Priority** |
| **P2a** | ARM NEON | Apple Silicon M1/M4 | ~15–20 GB/s | 🔵 Planned |
| **P2b** | x86 AVX2 | Intel/AMD modern CPUs | ~25–30 GB/s | 🔵 Planned |
| **P2c** | x86 SSE2 | Baseline x86 SIMD | ~10–12 GB/s | 🔵 Planned |
| **P3** | Fiber-based I/O | Parallel file processing | N/A | 🔵 Future |
| **P4** | x86 AVX-512 | High-end x86 (future) | >60 GB/s | 🔵 Backlog |
| **Future** | IBM POWER VSX | Power ISA vector ext | TBD | 📋 Researching |
| **Future** | ARM SVE | Scalable vector ext | TBD | 📋 Researching |
| **Future** | LoongArch LSX/LASX | LoongArch SIMD | TBD | 📋 Researching |
| **Future** | RISC-V RVV | RISC-V vectors | TBD | 📋 Researching |

**Implementation Details**: See [Migration Paper § 12: Native Implementation Strategy](papers/migration/12_native_implementation_strategy.adoc)

**Key Design Principles**:

* **Zero-copy**: Reusable static buffers, pointer arithmetic for hot paths
* **SIMD dispatch**: Runtime CPU detection with compile-time fallback selection
* **Idiomatic Crystal**: Public API remains safe; unsafe blocks internally documented
* **Bit-identical**: 100% test vector parity with vendor C implementation

**Getting Involved**:

* Interested in porting SIMD paths? See [papers/CONTRIBUTING.adoc](papers/CONTRIBUTING.adoc) for intrinsic patterns
* Want to benchmark? Run `./bin/xxhsum -b -Dnative` (future: switches to native when P1 complete)
* Found issues? Please validate against FFI baseline first

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

# One-shot hashing
hash64 = XXH3.hash64("hello world")
hash128 = XXH3.hash128("hello world")

puts "XXH3_64: #{hash64.to_s(16)}"
puts "XXH3_128: #{hash128.to_s(16)}"

# Streaming example (128-bit)
state = XXH::XXH3.new_state128
state.update("hello".to_slice)
state.update(" world".to_slice)
h = state.digest
puts "XXH3_128 streaming: low=0x#{h.low64.to_s(16)}, high=0x#{h.high64.to_s(16)}"

# Reset with a seed (streaming with seed)
# You can initialize with a seed or call `reset(seed)` to reuse the state for a new seeded hash.
state = XXH::XXH3.new_state128(0_u64)
state.update("test".to_slice)
puts "seeded (0) => #{XXH::XXH3.hash128_with_seed("test".to_slice, 0_u64).low64.to_s(16)}"
state.reset(42_u64)
state.update("test".to_slice)
puts "seeded (42) => #{XXH::XXH3.hash128_with_seed("test".to_slice, 42_u64).low64.to_s(16)}"

# 64-bit equivalent reset usage
state64 = XXH::XXH3.new_state(0_u64)
state64.update("foo".to_slice)
state64.reset(123_u64)
state64.update("bar".to_slice)
puts "XXH3_64 streaming with seed: #{state64.digest.to_s(16)}"
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

Sample output (example):

```text
 1#XXH32                         :     102400 ->   128640 it/s (12562.5 MB/s)
 3#XXH64                         :     102400 ->   258604 it/s (25254.3 MB/s)
 5#XXH3_64b                      :     102400 ->   496518 it/s (48488.1 MB/s)
11#XXH128                        :     102400 ->   483088 it/s (47176.6 MB/s)
```

**Build Notes:**

* `shards build` automatically compiles the vendored C xxHash library via the postinstall hook
* Requires `make` and a C compiler (clang/gcc)
* LLVM optimizations enabled for maximum performance
* Aliases (`./bin/xxh32sum`, `./bin/xxh64sum`, `./bin/xxh128sum`, `./bin/xxh3sum`) are created by the postinstall hook and `./bin` is gitignored; to recreate aliases run `shards install` or execute the manual commands from the contributing guide.

### Verified Test Results ✅

All algorithms validated against vendor xxHash implementation:

```bash
# Example hashes (README.md, 4.0 KB)
./bin/xxhsum -H0 README.md
# Output: 6a0ddf61  README.md

./bin/xxhsum -H1 README.md
# Output: a8fe69ba5ce06d72  README.md

./bin/xxhsum -H2 README.md
# Output: 4eda32e63c79e21da8fe69ba5ce06d72  README.md

./bin/xxhsum -H3 README.md
# Output: a8fe69ba5ce06d72  README.md
```

**Integration Test Status**: 99/99 passing (expanded test matrix)

Matrix: 3 files (README.md, LICENSE, shard.yml) × 4 algorithms × 5 test types (basic, BSD, stdin, check, little-endian) = **60** cases,
plus 39 flag/benchmark validations = **99** total

* XXH32: ✅ (all checks)
* XXH64: ✅ (all checks)
* XXH128: ✅ (all checks)
* XXH3: ✅ (all checks)

See [TODO.md](TODO.md) for planned features and known issues.

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
* Secret variants use a generated 136-byte secret buffer
* Streaming variants use the streaming API (create state, update, digest, free)
* Auto-tuning (no `-i` flag) targets ~1 second per variant
* IDs 0, 29+, and `-b77` all expand to "benchmark all" (C99 vendor behavior)

For more details, see [BENCHMARK_ID_BEHAVIOR.md](BENCHMARK_ID_BEHAVIOR.md) for a detailed comparison with the C99 implementation.

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

This repository is based on the outstanding work of Yann Collet and the xxHash project. Portions of the implementation are vendored from `xxHash` and are included under the **BSD 2‑Clause** License — see `vendor/xxHash/LICENSE` for the original license text and attribution.

## Contributors

* [Werner Stein](https://github.com/wstein) - creator and maintainer (<werner.stein@gmail.com>)
