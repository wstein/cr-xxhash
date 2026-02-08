# Simplified dispatch: native SIMD implementations removed.
# All hashing delegates to the vendored `LibXXH` FFI implementation.

module XXH::Dispatch
  # One-shot wrappers (delegate to LibXXH)
  def self.hash_xxh32(input : Bytes, seed : UInt32 = 0_u32) : UInt32
    # Use native implementation
    XXH::XXH32.hash(input, seed)
  end

  def self.hash_xxh64(input : Bytes, seed : UInt64 = 0_u64) : UInt64
    # Prefer native Crystal implementation when available
    XXH::XXH64.hash(input, seed)
  end

  def self.hash_xxh3(input : Bytes, seed : UInt64 = 0_u64) : UInt64
    # Use native implementation when possible
    if seed == 0_u64
      XXH::XXH3.hash(input)
    else
      XXH::XXH3.hash_with_seed(input, seed)
    end
  end

  def self.hash_xxh128(input : Bytes, seed : UInt64 = 0_u64) : Tuple(UInt64, UInt64)
    # Use native implementation when available, fall back to FFI for very long inputs
    if seed == 0_u64
      h = XXH::XXH3.hash128(input)
    else
      h = XXH::XXH3.hash128_with_seed(input, seed)
    end
    {h.low64, h.high64}
  end
end
