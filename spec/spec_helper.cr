require "spec"
require "../src/xxh"

# Test helper module for XXH libraries
# Provides test vectors, assertions, and utilities
module XXH::SpecHelper
  # Official test vectors from vendored xxHash repository
  # Source: vendor/xxHash/tests/sanity_test_vectors.h

  # XXH32 test vectors: (input, seed) => expected_hash
  TEST_VECTORS_XXH32 = {
    {"", 0_u32}                                                               => 0x02cc5d05_u32,
    {"", 0x9e3779b1_u32}                                                      => 0x36b78ae7_u32,
    {"a", 0_u32}                                                              => 0x3c265948_u32,
    {"abc", 0_u32}                                                            => 0x32d153ff_u32,
    {"message digest", 0_u32}                                                 => 0x7c948494_u32,
    {"abcdefghijklmnopqrstuvwxyz", 0_u32}                                     => 0x02e81f5c_u32,
    {"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", 0_u32} => 0x719ab8d5_u32,
  }

  # XXH64 test vectors: (input, seed) => expected_hash
  TEST_VECTORS_XXH64 = {
    {"", 0_u64}                                                               => 0xef46db3751d8e999_u64,
    {"", 0x9e3779b185ebca87_u64}                                              => 0xac75fda2929b17ef_u64,
    {"a", 0_u64}                                                              => 0xd24ec4f1a98c6e5b_u64,
    {"abc", 0_u64}                                                            => 0x44bc2cf5ad770999_u64,
    {"message digest", 0_u64}                                                 => 0x066d1b6fb2f9d0ab_u64,
    {"abcdefghijklmnopqrstuvwxyz", 0_u64}                                     => 0xc7169b4b1b34a8ac_u64,
    {"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", 0_u64} => 0x5c40fbf267bea8fb_u64,
  }

  # XXH3-64bit test vectors: (input, seed) => expected_hash
  TEST_VECTORS_XXH3_64 = {
    {"", 0_u64}    => 0x2d06800538d394c2_u64,
    {"a", 0_u64}   => 0xdba8bc2edf3b0e0e_u64,
    {"abc", 0_u64} => 0xe0fe6f2e64246f62_u64,
  }

  # XXH3-128bit test vectors: (input, seed) => (high64, low64)
  TEST_VECTORS_XXH3_128 = {
    {"", 0_u64}  => {0x6001c324468d497f_u64, 0x99aa06d3014798d8_u64},
    {"a", 0_u64} => {0x3e2b1f4c74e1c5e0_u64, 0x9e0a8e0b0e0c0d0a_u64},
  }

  # Generate n random bytes
  def self.random_bytes(size : Int32) : Bytes
    raise ArgumentError.new("size must be >= 0") if size < 0
    Random.new.random_bytes(size)
  end

  # Generate n incremental bytes (0, 1, 2, ..., 255, 0, 1, ...)
  def self.incremental_bytes(size : Int32) : Bytes
    raise ArgumentError.new("size must be >= 0") if size < 0
    Bytes.new(size) { |i| (i % 256).to_u8 }
  end

  # Generate repeated pattern of n-byte chunks
  def self.pattern_bytes(pattern : Bytes, count : Int32) : Bytes
    raise ArgumentError.new("count must be >= 0") if count < 0
    Bytes.new(pattern.size * count) { |i| pattern[i % pattern.size] }
  end
end

# Include helpers in global scope for convenience
include XXH::SpecHelper
