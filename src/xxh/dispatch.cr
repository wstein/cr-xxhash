# Simplified dispatch: native SIMD implementations removed.
# All hashing delegates to the vendored `LibXXH` FFI implementation.

require "../ffi/bindings"

module XXH::Dispatch
  # One-shot wrappers (delegate to LibXXH)
  def self.hash_xxh32(input : Bytes, seed : UInt32 = 0_u32) : UInt32
    XXH::FFI.show_deprecation_warning
    XXH.XXH32(input, seed)
  end

  def self.hash_xxh64(input : Bytes, seed : UInt64 = 0_u64) : UInt64
    # Prefer native Crystal implementation when available
    XXH::XXH64.hash(input, seed)
  end

  def self.hash_xxh3(input : Bytes, seed : UInt64 = 0_u64) : UInt64
    XXH::FFI.show_deprecation_warning
    if seed == 0_u64
      LibXXH.XXH3_64bits(input.to_unsafe, input.size)
    else
      LibXXH.XXH3_64bits_withSeed(input.to_unsafe, input.size, seed)
    end
  end

  def self.hash_xxh128(input : Bytes, seed : UInt64 = 0_u64) : Tuple(UInt64, UInt64)
    XXH::FFI.show_deprecation_warning
    result = if seed == 0_u64
               LibXXH.XXH3_128bits(input.to_unsafe, input.size)
             else
               LibXXH.XXH3_128bits_withSeed(input.to_unsafe, input.size, seed)
             end
    {result.low64, result.high64}
  end
end
