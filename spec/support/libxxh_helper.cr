# Delegates SpecFFI helpers to the library-provided implementations so
# tests keep using the same `SpecFFI` API while the actual helpers live in
# `src/xxh/libxxh_helper.cr` (vendor convenience wrapper).
require "../../src/xxh/libxxh_helper"

# Keep the top-level `SpecFFI` symbol for backward compatibility in specs
SpecFFI = XXH::Vendor
