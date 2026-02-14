# xxHash Crystal Implementation - Test Plan & TODO

**Parent Project**: [TODO.md](TODO.md)
**Goal**: Comprehensive test suite matching official xxHash test vectors and CLI behavior.

This plan details the translation of vendor C tests (`vendor/xxHash/tests/`) into idiomatic Crystal specs and Cucumber integration tests.

---

## 📊 Test Coverage Overview

| Component | Type | Status | Source |
|-----------|------|--------|--------|
| **Vectors** | Fixtures | 🔴 Todo | `sanity_test_vectors.h` |
| **XXH32** | Unit | 🔴 Todo | `sanity_test.c` |
| **XXH64** | Unit | 🔴 Todo | `sanity_test.c` |
| **XXH3** | Unit | 🔴 Todo | `sanity_test.c` |
| **Streaming**| Unit | 🔴 Todo | `sanity_test.c` (Random Update) |
| **CLI** | Integration | 🔴 Todo | `cli-test.sh`, `xxhsum` |
| **Edge Cases**| Unit | 🔴 Todo | Collisions, Zero-length, Seeds |

---

## 🛠 Phase T1: Test Infrastructure (Critical)

### T1.1 Test Vector Extraction

**Priority**: ⭐⭐⭐⭐⭐ | **Source**: `vendor/xxHash/tests/sanity_test_vectors.h`

- [ ] Create script `scripts/generate_vectors.cr` to parse C header
- [ ] Generate `spec/fixtures/vectors.json` containing:
  - XXH32 vectors (input, seed, result)
  - XXH64 vectors
  - XXH3/128 vectors
  - Secret samples

### T1.2 Spec Helper Setup

**Priority**: ⭐⭐⭐⭐⭐

- [ ] Update `spec/spec_helper.cr`:
  - Load `vectors.json`
  - Helpers for deterministic random data (`fillTestBuffer` equivalent)
  - Byte-by-byte streaming helpers

---

## 🧪 Phase T2: Unit Specifications (Core)

### T2.1 XXH32 Specs (`spec/xxh32_spec.cr`)

**Priority**: ⭐⭐⭐⭐⭐

- [ ] **Sanity Checks**: Verify all vectors from `vectors.json`
- [ ] **One-shot**: Verify `hash(data, seed)`
- [ ] **Streaming**:
  - Verify `update()` chunks matches one-shot
  - Verify byte-by-byte update matches
- [ ] **Edge Cases**: Empty string, null pointer (handled by Crystal), large inputs

### T2.2 XXH64 Specs (`spec/xxh64_spec.cr`)

**Priority**: ⭐⭐⭐⭐⭐

- [ ] **Sanity Checks**: Verify all vectors
- [ ] **Streaming Tests**: Chunked vs Byte-by-byte vs One-shot

### T2.3 XXH3 Specs (`spec/xxh3_spec.cr`)

**Priority**: ⭐⭐⭐⭐⭐

- [ ] **64-bit Vectors**: Verify standard test vectors
- [ ] **128-bit Vectors**: Verify high/low 64-bit split
- [ ] **Secret Management**:
  - Verify `withSecret` matches standard output
  - Verify `generateSecret` creates valid entropy
  - Verify `generateSecret_fromSeed` reproducibility
- [ ] **Streaming**:
  - `reset_withSecret`, `reset_withSeed`
  - Randomized update lengths (mimic `SANITY_TEST_XXH3_randomUpdate`)

### T2.4 Canonical & Interop (`spec/canonical_spec.cr`)

**Priority**: ⭐⭐⭐⭐

- [ ] Validate Big-Endian canonical output format
- [ ] Round-trip tests (Hash -> Canonical -> Hash)

---

## 🥒 Phase T3: Integration Tests (Cucumber)

### T3.1 CLI Feature Definitions

**Priority**: ⭐⭐⭐⭐

- [ ] Create `features/cli.feature`:
  - **Basic Hashing**: `xxhsum file`
  - **Algorithms**: `-H0`, `-H1`, `-H2`, `-H3`
  - **Check Mode**: `-c` with valid/invalid checksum files
  - **Benchmark**: `-b` (smoke test only)
  - **Input Sources**: Stdin vs File arguments

### T3.2 Step Definitions

**Priority**: ⭐⭐⭐⭐

- [ ] Create `features/step_definitions/cli_steps.rb` (or Crystal equivalent):
  - Steps to run `bin/xxhsum`
  - Output strict matching
  - Exit code verification

### T3.3 Snapshots

**Priority**: ⭐⭐⭐

- [ ] Create `features/snapshots/`:
  - Expected output for help text
  - Expected output for specific file hashes

---

## 🔍 Phase T4: Advanced & Edge Cases

### T4.1 Collision Tests (`spec/collisions_spec.cr`)

**Priority**: ⭐⭐⭐

- [ ] Port logic from `vendor/xxHash/tests/collisions/`
- [ ] Verify known collision resistance for small inputs

### T4.2 Unicode & Filenames

**Priority**: ⭐⭐⭐

- [ ] Verify handling of Emoji/Unicode filenames
- [ ] Verify handling of special chars in paths (spaces, newlines)

### T4.3 FFI Smoke Tests

**Priority**: ⭐⭐⭐⭐

- [ ] Direct `LibXXH` calls (verify no segfaults on raw pointer usage)
- [ ] Memory leak checks (looping create/free state)

---

## 📉 Phase T5: Performance & Benchmarks

### T5.1 Comparison Benchmarks

**Priority**: ⭐⭐

- [ ] `bench/compare.cr`: Compare pure Crystal vs Bindings (if applicable)
- [ ] Compare XXH32 vs XXH64 vs XXH3

---

## 🔗 Cross-References

- **Implementation Plan**: See [TODO.md](TODO.md) Phase 3
- **Test Data Source**: [sanity_test_vectors.h](vendor/xxHash/tests/sanity_test_vectors.h)
