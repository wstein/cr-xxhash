require "spec"
require "../src/xxh"
require "./support/vector_loader.cr"

# Official test vectors from vendored xxHash repository
# Source: vendor/xxhash-wrapper/vendor/xxHash/tests/sanity_test_vectors.h

# XXH32 test vectors: (input, seed) => expected_hash
TEST_VECTORS_XXH32 = {
  {"", 0_u32}                                                               => 0x02cc5d05_u32,
  {"", 0x9e3779b1_u32}                                                      => 0x36b78ae7_u32,
  {"a", 0_u32}                                                              => 0x550d7456_u32,
  {"abc", 0_u32}                                                            => 0x32d153ff_u32,
  {"message digest", 0_u32}                                                 => 0x7c948494_u32,
  {"abcdefghijklmnopqrstuvwxyz", 0_u32}                                     => 0x63a14d5f_u32,
  {"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", 0_u32} => 0x9c285e64_u32,
}

# XXH64 test vectors: (input, seed) => expected_hash
TEST_VECTORS_XXH64 = {
  {"", 0_u64}                                                               => 0xef46db3751d8e999_u64,
  {"", 0x9e3779b185ebca87_u64}                                              => 0x6ec6d05f61c7e7a7_u64,
  {"a", 0_u64}                                                              => 0xd24ec4f1a98c6e5b_u64,
  {"abc", 0_u64}                                                            => 0x44bc2cf5ad770999_u64,
  {"message digest", 0_u64}                                                 => 0x066ed728fceeb3be_u64,
  {"abcdefghijklmnopqrstuvwxyz", 0_u64}                                     => 0xcfe1f278fa89835c_u64,
  {"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", 0_u64} => 0xaaa46907d3047814_u64,
}

# XXH3-64bit test vectors: (input, seed) => expected_hash
TEST_VECTORS_XXH3_64 = {
  {"", 0_u64}                                                               => 0x2d06800538d394c2_u64,
  {"a", 0_u64}                                                              => 0xe6c632b61e964e1f_u64,
  {"abc", 0_u64}                                                            => 0x78af5f94892f3950_u64,
  {"message digest", 0_u64}                                                 => 0x160d8e9329be94f9_u64,
  {"abcdefghijklmnopqrstuvwxyz", 0_u64}                                     => 0x810f9ca067fbb90c_u64,
  {"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", 0_u64} => 0x643542bb51639cb2_u64,
}

# XXH3-128bit test vectors: (input, seed) => (high64, low64)
TEST_VECTORS_XXH3_128 = {
  {"", 0_u64}  => {0x99aa06d3014798d8_u64, 0x6001c324468d497f_u64},
  {"a", 0_u64} => {0xa96faf705af16834_u64, 0xe6c632b61e964e1f_u64},
}

# Generate n random bytes
def random_bytes(size : Int32) : Bytes
  raise ArgumentError.new("size must be >= 0") if size < 0
  Random.new.random_bytes(size)
end

# Generate n incremental bytes (0, 1, 2, ..., 255, 0, 1, ...)
def incremental_bytes(size : Int32) : Bytes
  raise ArgumentError.new("size must be >= 0") if size < 0
  Bytes.new(size) { |i| (i % 256).to_u8 }
end

# Generate repeated pattern of n-byte chunks
def pattern_bytes(pattern : Bytes, count : Int32) : Bytes
  raise ArgumentError.new("count must be >= 0") if count < 0
  Bytes.new(pattern.size * count) { |i| pattern[i % pattern.size] }
end
