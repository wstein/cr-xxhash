# cr-xxhash

High-performance Crystal implementation and migration study of Yann Collet's xxHash (C → Crystal). This project explores achieving near-native throughput using LLVM intrinsics, pointer arithmetic, and SIMD unrolling within the Crystal Language ecosystem.

## Mission Highlights

* [ ] Port the streaming and one-shot XXH32/XXH64/XXH3 APIs to idiomatic Crystal.
* [ ] Maintain bit-identical outputs to the upstream C99 implementation across endianness modes.
* [ ] Deliver SIMD-accelerated LLVM paths that approach native C performance for modern CPUs.
* [ ] Document the architectural trade-offs in an arc42-style migration paper.

## Migration Paper

For architectural depth, see the **[Migration Study: C99 → Crystal](papers/MIGRATION.adoc)** which maps each arc42 view to the Crystal implementation.

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
```

### CLI Tool

The included `xxhsum` binary provides a command-line interface compatible with the xxHash reference implementation:

```bash
# Build the CLI
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
./bin/xxhsum -b           # Benchmark all algorithms (sample: 100 KB)
./bin/xxhsum -b0          # Benchmark all vendor benchmark IDs (alias: -b29, -b77)
./bin/xxhsum -b3          # Benchmark XXH64 (vendor benchmark id 3)
./bin/xxhsum -b11         # Benchmark XXH128 (vendor benchmark id 11)

Note: `-b#` uses vendor benchmark IDs (1-28). Use a comma-separated list `-b1,3,5` to run specific variants. IDs 0, 29 and larger, and `-b77` expand to "benchmark all" per vendor behavior.
See `BENCHMARK_ID_BEHAVIOR.md` for a Crystal vs C99 feature comparison and the vendor ID mapping.
Sample output (example):
 1#XXH32                         :     102400 ->   128640 it/s (12562.5 MB/s)
 3#XXH64                         :     102400 ->   258604 it/s (25254.3 MB/s)
 5#XXH3_64b                      :     102400 ->   496518 it/s (48488.1 MB/s)
11#XXH128                        :     102400 ->   483088 it/s (47176.6 MB/s)

See `PERFORMANCE_OPTIMIZATIONS.md` for details and measured throughput on Apple M4 (~45–49 GB/s).
```

#### Verified Test Results ✅

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

**Basic Variants (1–6, 11–12)**

* 1–2: `XXH32` (aligned/unaligned)
* 3–4: `XXH64` (aligned/unaligned)
* 5–6: `XXH3_64b` (aligned/unaligned)
* 11–12: `XXH128` (aligned/unaligned)

**Seeded Variants (7–8, 13–14, 23–24, 27–28)**

* 7–8: `XXH3_64b w/seed` (aligned/unaligned)
* 13–14: `XXH128 w/seed` (aligned/unaligned)
* 23–24: `XXH3_stream w/seed` (aligned/unaligned)
* 27–28: `XXH128_stream w/seed` (aligned/unaligned)

**Secret Variants (9–10, 15–16)**

* 9–10: `XXH3_64b w/secret` (aligned/unaligned)
* 15–16: `XXH128 w/secret` (aligned/unaligned)

**Streaming Variants (17–28)**

* 17–18: `XXH32_stream` (aligned/unaligned)
* 19–20: `XXH64_stream` (aligned/unaligned)
* 21–22: `XXH3_stream` (aligned/unaligned)
* 25–26: `XXH128_stream` (aligned/unaligned)

### Usage

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

```
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

## Development

See the [Scripts README](scripts/README.md) for tooling help. Contributors should review the [Contributing Guidelines](papers/CONTRIBUTING.adoc).

## Third-party components

This repository is based on the outstanding work of Yann Collet and the xxHash project. Portions of the implementation are vendored from `xxHash` and are included under the **BSD 2‑Clause** License — see `vendor/xxHash/LICENSE` for the original license text and attribution.

## Contributors

* [Werner Stein](https://github.com/wstein) - creator and maintainer (<werner.stein@gmail.com>)
