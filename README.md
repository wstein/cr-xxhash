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
./bin/xxhsum -b3          # Benchmark XXH3 variant (vendor id 5)
./bin/xxhsum -b11         # Benchmark XXH128 (vendor id 11)

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

**Integration Test Status**: 60/60 passing (expanded test matrix)

Matrix: 3 files (README.md, LICENSE, shard.yml) × 4 algorithms × 5 test types (basic, BSD, stdin, check, little-endian) = **60** cases

* XXH32: ✅ (all checks)
* XXH64: ✅ (all checks)
* XXH128: ✅ (all checks)
* XXH3: ✅ (all checks)

See [TODO.md](TODO.md) for planned features and known issues.

## Development

See the [Scripts README](scripts/README.md) for tooling help. Contributors should review the [Contributing Guidelines](papers/CONTRIBUTING.adoc).

## Third-party components

This repository is based on the outstanding work of Yann Collet and the xxHash project. Portions of the implementation are vendored from `xxHash` and are included under the **BSD 2‑Clause** License — see `vendor/xxHash/LICENSE` for the original license text and attribution.

## Contributors

* [Werner Stein](https://github.com/wstein) - creator and maintainer (<werner.stein@gmail.com>)
