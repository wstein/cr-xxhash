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

```crystal
require "cr-xxhash"

# One-shot hashing
hash = XXH3.hash64("hello world")
puts "XXH3_64: #{hash}"
```

## Development

See the [Scripts README](scripts/README.md) for tooling help. Contributors should review the [Contributing Guidelines](papers/CONTRIBUTING.adoc).

## Third-party components

This repository is based on the outstanding work of Yann Collet and the xxHash project. Portions of the implementation are vendored from `xxHash` and are included under the **BSD 2‑Clause** License — see `vendor/xxHash/LICENSE` for the original license text and attribution.

## Contributors

* [Werner Stein](https://github.com/wstein) - creator and maintainer (<werner.stein@gmail.com>)
