# Test Fixtures for XXHash Crystal Library

This directory contains binary test data files used by the test suite.

## Files

- **vendor_vectors_xxh32.json / vendor_vectors_xxh64.json / vendor_vectors_xxh3.json / vendor_vectors_xxh128.json**
  - Auto-generated (hex) from `vendor/xxHash/tests/sanity_test_vectors.h`
  - Each file contains `vectors` plus `sanity_buffer_max_len` (so no separate meta file is required)
  - Regenerate with: `crystal scripts/generate_vectors.cr`
  - Consumed by `spec/support/vector_loader.cr` and `spec/vendor_generated_vectors_spec.cr` for parity checks

- **empty.bin** (0 bytes)
  - Empty file used to test edge case: zero-length input
  - Expected XXH32: 0x02cc5d05
  - Expected XXH64: 0xef46db3751d8e999

- **small.bin** (128 bytes)
  - Random data for small input test
  - Used to verify hash stability across updates

- **medium.bin** (4,096 bytes)
  - Larger random data block
  - Tests streaming API with multiple update calls

- **large.bin** (1,048,576 bytes = 1 MB)
  - Large file for performance regression tests
  - Generated with incremental pattern (0, 1, 2, ..., 255, 0, 1, ...)
  - Used in non-blocking benchmarks

## Generation

Fixtures are generated during CI setup. They are committed to the repo to ensure:

- Deterministic tests (same hash every run)
- No network/random dependencies
- Fast CI startup

## Stability

Hash values for these fixtures are tracked in `spec/spec_helper.cr`:

- See `TEST_VECTORS_*` constants for official values
- If fixtures are modified, update vector constants and document the change
