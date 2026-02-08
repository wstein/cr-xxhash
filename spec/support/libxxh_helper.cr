# Spec helper: centralize FFI binding loading and provide small convenience wrappers
#
# This file centralizes requiring the project's FFI bindings for tests and exposes
# a `SpecFFI` module to keep test code concise and independent from direct FFI details.

require "./bindings"

module SpecFFI
  def self.xxh32(input : Bytes, seed : UInt32 = 0_u32)
    LibXXH.XXH32(input.to_unsafe, input.size, seed)
  end

  def self.xxh64(input : Bytes, seed : UInt64 = 0_u64)
    LibXXH.XXH64(input.to_unsafe, input.size, seed)
  end

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

  def self.xxh3_128_stream_digest(input : Bytes)
    st = LibXXH.XXH3_createState
    LibXXH.XXH3_128bits_reset(st)
    LibXXH.XXH3_128bits_update(st, input.to_unsafe, input.size)
    got = LibXXH.XXH3_128bits_digest(st)
    LibXXH.XXH3_freeState(st)
    got
  end

  def self.xxh3_128_stream_digest_with_seed(input : Bytes, seed : UInt64)
    st = LibXXH.XXH3_createState
    LibXXH.XXH3_128bits_reset_withSeed(st, seed)
    LibXXH.XXH3_128bits_update(st, input.to_unsafe, input.size)
    got = LibXXH.XXH3_128bits_digest(st)
    LibXXH.XXH3_freeState(st)
    got
  end
end
