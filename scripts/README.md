# Helper Scripts

This directory contains utility scripts for development, benchmarking, and CI environments.

## tool_versions.cr

A Crystal script to detect and display the versions of core tooling used in the `cr-xxhash` project. All `.cr` helper scripts in `scripts/` include a shebang and are executable so they can be run directly.

### Usage

```bash
# Run directly (shebang + executable)
./tool_versions.cr

# Or use crystal run
crystal run ./tool_versions.cr -- --tools crystal,llvm-config

# Generate JSON for CI artifacts
crystal run ./tool_versions.cr -- --json --output tooling.json
```

### Notes

- All `.cr` scripts in `scripts/` now include `#!/usr/bin/env crystal` and are executable.
- Use `./scripts/<script>.cr` to run them directly, or `crystal run` if you need to pass Crystal flags.
