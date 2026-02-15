xxhsum — Crystal example (minimal MVP)

This directory contains a minimal Crystal example CLI demonstrating how to use the `cr-xxhash` library. It implements MVP (Minimum Viable Product) features:

**Supported Features:**

- Algorithm selection: `-H0` (XXH32), `-H1` (XXH64, default), `-H2` (XXH128), `-H3` (XXH3_64)
- File hashing: `./bin/xxhsum [options] file1 [file2 ...]`
- stdin support: `echo "data" | ./bin/xxhsum` or `./bin/xxhsum -`
- Output formats:
  - GNU (default): `<hash>  <filename>`
  - BSD (--tag): `<algo> (<filename>) = <hash>`
- Seeding: `-s SEED` or `--seed SEED` (decimal or 0xHEX format)
- Version & help: `--version`, `-h`, `--help`

**Build & Run:**

  cd examples/xxhsum
  shards install
  shards build xxhsum --release
  ./bin/xxhsum README.md           # Hash a file
  echo "test" | ./bin/xxhsum       # Hash from stdin
  ./bin/xxhsum -H3 file.txt        # Use XXH3_64 algorithm
  ./bin/xxhsum --tag file.txt      # BSD format output
  ./bin/xxhsum -s 12345 file.txt   # Seeded hash

**Format Parity:**

Output format matches the official vendor `xxhsum` for all P0 features:

- GNU format, BSD format, algorithm prefixes (XXH3_) all compatible
- Multi-file support works identically

**Architecture:**

- `src/options.cr` — command-line argument parsing (OptionParser)
- `src/hasher.cr` — delegates to `XXH::*` library APIs (uses streaming/file APIs)
- `src/formatter.cr` — output formatting (GNU/BSD modes, algorithm prefixes)
- `src/xxhsum.cr` — main entry point and CLI orchestration

**Note:**

This example deliberately uses the public `XXH::*` module APIs, not `LibXXH.*` FFI. This demonstrates the proper usage pattern for library consumers.
