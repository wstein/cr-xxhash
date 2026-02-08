# Spec support: central FFI helper for tests
#
# Purpose:
#   - Centralize requiring the FFI bindings so individual specs don't need to require
#     `src/ffi/bindings.cr` directly.
#   - Provide convenience helper wrappers (optional) to call LibXXH functions in specs.
#
# Usage:
#   - Included automatically via `spec/spec_helper.cr` which loads this file.
#   - Specs can reference `LibXXH` directly (the binding is available) or use the
#     `SpecFFI` helper methods for common operations like `SpecFFI.xx3_128(input)`.

require "../../src/ffi/bindings"

# Convenience helpers for specs
module SpecFFI
  def self.xxh3_64(input : Bytes)
    LibXXH.XXH3_64bits(input.to_unsafe, input.size)
  end

  def self.xxh3_64_with_seed(input : Bytes, seed : UInt64)
    LibXXH.XXH3_64bits_withSeed(input.to_unsafe, input.size, seed)
  end

  def self.xxh3_128(input : Bytes)
    LibXXH.XXH3_128bits(input.to_unsafe, input.size)
  end

  def self.xxh3_128_with_seed(input : Bytes, seed : UInt64)
    LibXXH.XXH3_128bits_withSeed(input.to_unsafe, input.size, seed)
  end
end
