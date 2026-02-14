# Helper Scripts

This directory contains utility scripts for development, benchmarking, and CI environments.

## tool_versions.cr

A Ruby script to detect and display the versions of core tooling used in the `cr-xxhash` project. This is essential for ensuring reproducibility of benchmarks and technical audits.

### Usage

```bash
# Print a human-readable table of versions
./tool_versions.cr

# Filter for specific tools
crystal run ./tool_versions.cr -- --tools crystal,llvm-config

# Generate JSON for CI artifacts
crystal run ./tool_versions.cr -- --json --output tooling.json
```

### Dependencies

- **Ruby** (>= 2.5)
- **Standard Library**: `json`, `optparse`, `open3`
