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

## Vendor benchmark behavior (xxhsum -b)

The upstream C99 `xxhsum` benchmark mode uses **benchmark IDs** (not the `-H` algorithm IDs). These IDs map to specific function variants and are run in **aligned + unaligned** pairs (unaligned = buffer offset +3). The `-b77` shorthand triggers the full 1–28 sweep.

**ID groups (C99 reference):**

* **Basic (1–8)**
  * 1–2: `XXH32` / `XXH32 unaligned`
  * 3–4: `XXH64` / `XXH64 unaligned`
  * 5–6: `XXH3_64b` / `XXH3_64b unaligned`
  * 7–8: `XXH128` / `XXH128 unaligned`
* **Seeded (9–14)**
  * 9–10: `XXH3_64b w/seed` / unaligned
  * 13–14: `XXH128 w/seed` / unaligned
* **Secret (11–16)**
  * 11–12: `XXH3_64b w/secret` / unaligned
  * 15–16: `XXH128 w/secret` / unaligned
* **Streaming (17–28)**
  * 17–18: `XXH32_stream` / unaligned
  * 19–20: `XXH64_stream` / unaligned
  * 21–22: `XXH3_stream` / unaligned
  * 23–24: `XXH3_stream w/seed` / unaligned
  * 25–26: `XXH128_stream` / unaligned
  * 27–28: `XXH128_stream w/seed` / unaligned

**Output format (C99 reference):**

`{id}#{name:<28} : {size:>10} -> {iters:>8} it/s ({mbps:>7.1f} MB/s)`

Notes:

* `-H0..-H3` select hash algorithms for **hashing**, while `-b#` selects **benchmark IDs**.
* Vendor `-b77` expands to the full 1–28 set.
* Seeded/secret variants vary the seed/secret to prevent the optimizer from removing work.

## Development

See the [Scripts README](scripts/README.md) for tooling help. Contributors should review the [Contributing Guidelines](papers/CONTRIBUTING.adoc).

## Third-party components

This repository is based on the outstanding work of Yann Collet and the xxHash project. Portions of the implementation are vendored from `xxHash` and are included under the **BSD 2‑Clause** License — see `vendor/xxHash/LICENSE` for the original license text and attribution.

## Contributors

* [Werner Stein](https://github.com/wstein) - creator and maintainer (<werner.stein@gmail.com>)
