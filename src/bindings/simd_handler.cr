# SIMD Variant Handler
#
# After the xxhash-wrapper refactor:
# - Each SIMD variant is compiled with specific CPU flags in separate translation units
# - All variants are exported unconditionally (but may require CPU support at runtime)
# - Signal handling (SIGILL on unsupported CPU) is used to gracefully skip unsupported variants
#
# For the Crystal consumer, this module provides:
# 1. Information about available SIMD variants at compile-time
# 2. Utilities for working with variant selection
#
# Note: Crystal doesn't have C-style setjmp/longjmp signal recovery.
# Runtime CPU feature detection is the responsibility of the caller.

module XXHashSIMD
  # Returns array of SIMD backends available at compile-time for this platform.
  # All backends are compiled unconditionally; actual CPU support is checked at runtime if needed.
  def self.available_backends : Array(String)
    {% if flag?(:x86_64) %}
      ["scalar", "sse2", "avx2", "avx512"]
    {% elsif flag?(:aarch64) %}
      ["scalar", "neon", "sve"]
    {% else %}
      ["scalar"]
    {% end %}
  end

  # Check if a SIMD backend name is recognized for this platform.
  # This only checks compile-time availability; actual CPU support is a runtime concern.
  def self.backend_available?(variant_name : String) : Bool
    available_backends.includes?(variant_name)
  end
end
