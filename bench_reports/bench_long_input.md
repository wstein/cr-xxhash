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
