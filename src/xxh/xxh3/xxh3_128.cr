require "./xxh3_types"
require "./xxh3_base"

module XXH::XXH3
  # ============================================================================
  # 128-bit One-Shot Hashing: Small Input Paths (0..16 bytes)
  # ============================================================================

  def self.len_1to3_128b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : Hash128
    c1 = ptr[0]
    c2 = ptr[len >> 1]
    c3 = ptr[len - 1]
    combinedl = ((c1.to_u32 << 16) | (c2.to_u32 << 24) | c3.to_u32 | (len.to_u32 << 8))
    combinedh = XXH::Primitives.rotl32(XXH::Primitives.bswap32(combinedl), 13_u32)

    # NOTE: The XOR is done on 32-bit reads, then the result is extended to 64-bit
    bitflipl = ((XXH::Primitives.read_u32_le(secret_ptr) ^ XXH::Primitives.read_u32_le(secret_ptr + 4)).to_u64) &+ seed
    bitfliph = ((XXH::Primitives.read_u32_le(secret_ptr + 8) ^ XXH::Primitives.read_u32_le(secret_ptr + 12)).to_u64) &- seed

    keyed_lo = combinedl.to_u64 ^ bitflipl
    keyed_hi = combinedh.to_u64 ^ bitfliph

    Hash128.new(XXH::XXH64.avalanche(keyed_lo), XXH::XXH64.avalanche(keyed_hi))
  end

  def self.len_4to8_128b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : Hash128
    seed_mod = seed ^ ((XXH::Primitives.bswap32((seed & 0xFFFFFFFF_u64).to_u32).to_u64) << 32)
    input_lo = XXH::Primitives.read_u32_le(ptr)
    input_hi = XXH::Primitives.read_u32_le(ptr + (len - 4))
    input_64 = input_lo.to_u64 | (input_hi.to_u64 << 32)
    bitflip = (XXH::Primitives.read_u64_le(secret_ptr + 16) ^ XXH::Primitives.read_u64_le(secret_ptr + 24)) &+ seed_mod
    keyed = input_64 ^ bitflip

    m128 = mult64to128(keyed, XXH::Constants::PRIME64_1 &+ (len.to_u64 << 2))

    m128.high64 &+= (m128.low64 << 1)
    m128.low64 ^= (m128.high64 >> 3)

    m128.low64 = xorshift64(m128.low64, 35)
    m128.low64 &*= XXH::Constants::PRIME_MX2
    m128.low64 = xorshift64(m128.low64, 28)
    m128.high64 = XXH::XXH3.xx3_avalanche(m128.high64)

    m128
  end

  @[AlwaysInline]
  def self.mult32to64_len9to16(lhs : UInt32, rhs : UInt32) : UInt64
    (lhs.to_u64 * rhs.to_u64) & ((1_u128 << 64) - 1)
  end

  def self.len_9to16_128b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : Hash128
    bitflipl = (XXH::Primitives.read_u64_le(secret_ptr + 32) ^ XXH::Primitives.read_u64_le(secret_ptr + 40)) &- seed
    bitfliph = (XXH::Primitives.read_u64_le(secret_ptr + 48) ^ XXH::Primitives.read_u64_le(secret_ptr + 56)) &+ seed

    input_lo = XXH::Primitives.read_u64_le(ptr)
    input_hi = XXH::Primitives.read_u64_le(ptr + (len - 8))

    m128 = XXH::XXH3.mult64to128(input_lo ^ input_hi ^ bitflipl, XXH::Constants::PRIME64_1)

    m128.low64 &+= ((len - 1).to_u64 << 54)
    input_hi ^= bitfliph

    # 64-bit version:
    m128.high64 &+= input_hi &+ XXH::XXH3.mult32to64_len9to16((input_hi & 0xFFFFFFFF_u64).to_u32, XXH::Constants::PRIME32_2 &- 1)

    m128.low64 ^= XXH::Primitives.bswap64(m128.high64)

    h128 = XXH::XXH3.mult64to128(m128.low64, XXH::Constants::PRIME64_2)
    h128.high64 &+= m128.high64 &* XXH::Constants::PRIME64_2

    h128.low64 = XXH::XXH3.xx3_avalanche(h128.low64)
    h128.high64 = XXH::XXH3.xx3_avalanche(h128.high64)

    h128
  end

  def self.len_0to16_128b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : Hash128
    if len > 8
      return len_9to16_128b(ptr, len, secret_ptr, seed)
    elsif len >= 4
      return len_4to8_128b(ptr, len, secret_ptr, seed)
    elsif len != 0
      return len_1to3_128b(ptr, len, secret_ptr, seed)
    else
      # len == 0
      bitflipl = XXH::Primitives.read_u64_le(secret_ptr + 64) ^ XXH::Primitives.read_u64_le(secret_ptr + 72)
      bitfliph = XXH::Primitives.read_u64_le(secret_ptr + 80) ^ XXH::Primitives.read_u64_le(secret_ptr + 88)
      return Hash128.new(XXH::XXH64.avalanche(seed ^ bitflipl), XXH::XXH64.avalanche(seed ^ bitfliph))
    end
  end

  # ============================================================================
  # 128-bit One-Shot Hashing: Medium Input Paths (17..240 bytes)
  # ============================================================================

  def self.mix32b_128b(acc : Hash128, input_1_ptr : Pointer(UInt8), input_2_ptr : Pointer(UInt8), secret_ptr : Pointer(UInt8), seed : UInt64) : Hash128
    acc.low64 &+= XXH::XXH3.mix16b(input_1_ptr, secret_ptr, seed)
    acc.low64 ^= (XXH::Primitives.read_u64_le(input_2_ptr) &+ XXH::Primitives.read_u64_le(input_2_ptr + 8))

    acc.high64 &+= XXH::XXH3.mix16b(input_2_ptr, secret_ptr + 16, seed)
    acc.high64 ^= (XXH::Primitives.read_u64_le(input_1_ptr) &+ XXH::Primitives.read_u64_le(input_1_ptr + 8))

    acc
  end

  def self.len_17to128_128b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : Hash128
    acc = Hash128.new(len.to_u64 &* XXH::Constants::PRIME64_1, 0_u64)

    # Use smaller version (per XXH_SIZE_OPT >= 1 optimization)
    i = (len - 1).tdiv(32)
    while i >= 0
      acc = mix32b_128b(acc, ptr + (16 * i), ptr + (len - 16 * (i + 1)), secret_ptr + (32 * i), seed)
      i -= 1
    end

    h128 = Hash128.new(acc.low64 &+ acc.high64, 0_u64)
    h128.high64 = (acc.low64 &* XXH::Constants::PRIME64_1) &+ (acc.high64 &* XXH::Constants::PRIME64_4) &+ ((len.to_u64 &- seed) &* XXH::Constants::PRIME64_2)

    h128.low64 = XXH::XXH3.xx3_avalanche(h128.low64)
    h128.high64 = (0_u64 &- XXH::XXH3.xx3_avalanche(h128.high64))

    h128
  end

  def self.len_129to240_128b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : Hash128
    acc = Hash128.new(len.to_u64 &* XXH::Constants::PRIME64_1, 0_u64)

    i = 32
    while i < 160
      acc = mix32b_128b(acc, ptr + (i - 32), ptr + (i - 16), secret_ptr + (i - 32), seed)
      i += 32
    end

    acc.low64 = XXH::XXH3.xx3_avalanche(acc.low64)
    acc.high64 = XXH::XXH3.xx3_avalanche(acc.high64)

    i = 160
    while i <= len
      acc = mix32b_128b(acc, ptr + (i - 32), ptr + (i - 16), secret_ptr + XXH::Constants::XXH3_MIDSIZE_STARTOFFSET + (i - 160), seed)
      i += 32
    end

    acc = mix32b_128b(acc, ptr + (len - 16), ptr + (len - 32), secret_ptr + XXH::Constants::XXH3_SECRET_SIZE_MIN - XXH::Constants::XXH3_MIDSIZE_LASTOFFSET - 16, (0_u64 &- seed))

    h128 = Hash128.new(acc.low64 &+ acc.high64, 0_u64)
    h128.high64 = (acc.low64 &* XXH::Constants::PRIME64_1) &+ (acc.high64 &* XXH::Constants::PRIME64_4) &+ ((len.to_u64 &- seed) &* XXH::Constants::PRIME64_2)

    h128.low64 = XXH::XXH3.xx3_avalanche(h128.low64)
    h128.high64 = (0_u64 &- XXH::XXH3.xx3_avalanche(h128.high64))

    h128
  end

  # ============================================================================
  # 128-bit One-Shot Hashing: Main Dispatch
  # ============================================================================

  def self.hash128(input : Bytes) : Hash128
    ptr = input.to_unsafe
    len = input.size

    @[Likely]
    if len <= 16
      secret = XXH::Buffers.default_secret.to_unsafe
      return len_0to16_128b(ptr, len, secret.as(Pointer(UInt8)), 0_u64)
    elsif len <= 128
      # Phase 2a: 17-128 bytes
      secret = XXH::Buffers.default_secret.to_unsafe
      return len_17to128_128b(ptr, len, secret.as(Pointer(UInt8)), 0_u64)
    elsif len <= 240
      # Phase 2b: 129-240 bytes (native implementation)
      secret = XXH::Buffers.default_secret.to_unsafe
      return len_129to240_128b(ptr, len, secret.as(Pointer(UInt8)), 0_u64)
      @[Unlikely]
    else
      # Phase 3: 240+ bytes (native implementation)
      secret = XXH::Buffers.default_secret.to_unsafe
      return hash_long_128b(ptr, len, secret.as(Pointer(UInt8)), XXH::Buffers.default_secret.size)
    end
  end

  def self.hash128_with_seed(input : Bytes, seed : UInt64) : Hash128
    ptr = input.to_unsafe
    len = input.size

    if len <= 16
      secret = XXH::Buffers.default_secret.to_unsafe
      return len_0to16_128b(ptr, len, secret.as(Pointer(UInt8)), seed)
    elsif len <= 128
      # Phase 2a: 17-128 bytes
      secret = XXH::Buffers.default_secret.to_unsafe
      return len_17to128_128b(ptr, len, secret.as(Pointer(UInt8)), seed)
    elsif len <= 240
      # Phase 2b: 129-240 bytes (native implementation)
      secret = XXH::Buffers.default_secret.to_unsafe
      return len_129to240_128b(ptr, len, secret.as(Pointer(UInt8)), seed)
    else
      # Phase 3: 240+ bytes (native implementation)
      secret = XXH::Buffers.default_secret.to_unsafe
      return hash_long_128b_with_seed(ptr, len, seed, secret.as(Pointer(UInt8)), XXH::Buffers.default_secret.size)
    end
  end

  # ============================================================================
  # 128-bit Long Input Hashing (240+ bytes)
  # ============================================================================

  def self.finalize_long_128b(acc : Pointer(UInt64), secret_ptr : Pointer(UInt8), secret_size : Int32, len : UInt64) : Hash128
    low64 = finalize_long_64b(acc[0], acc[1], acc[2], acc[3], acc[4], acc[5], acc[6], acc[7], secret_ptr, len)
    # For high64, we need to compute mergeAccs with a different starting value
    # Per vendor: h128.high64 = XXH3_mergeAccs(acc, secret + secretSize - XXH_STRIPE_LEN - XXH_SECRET_MERGEACCS_START, ~(len * XXH_PRIME64_2))
    # XXH_STRIPE_LEN = 64, XXH_SECRET_MERGEACCS_START = 11, XXH_PRIME64_2 = 0xC2B2AE3D27D4EB4F_u64
    # So: secret + secretSize - 64 - 11 = secret + secretSize - 75
    high64 = XXH::XXH3.merge_accs(acc, secret_ptr + (secret_size - 64 - 11), ~(len &* XXH::Constants::PRIME64_2))
    Hash128.new(low64, high64)
  end

  def self.hash_long_128b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), secret_size : Int32) : Hash128
    # Stack-allocated for LLVM auto-vectorization
    acc = uninitialized UInt64[8]
    XXH::XXH3.init_acc(acc.to_unsafe)
    hash_long_internal_loop(acc.to_unsafe, ptr, len, secret_ptr, secret_size)
    finalize_long_128b(acc.to_unsafe, secret_ptr, secret_size, len.to_u64)
  end

  def self.hash_long_128b_with_seed(ptr : Pointer(UInt8), len : Int32, seed : UInt64, default_secret_ptr : Pointer(UInt8), secret_size : Int32) : Hash128
    if seed == 0_u64
      return hash_long_128b(ptr, len, default_secret_ptr, secret_size)
    end
    # When seeded, build custom secret
    secret = Bytes.new(XXH::Constants::SECRET_DEFAULT_SIZE, 0)
    nrounds = XXH::Constants::SECRET_DEFAULT_SIZE / 16
    i = 0
    while i < nrounds
      lo = XXH::Primitives.read_u64_le(default_secret_ptr + (16 * i)) &+ seed
      hi = ((XXH::Primitives.read_u64_le(default_secret_ptr + (16 * i + 8)).to_u128 &- seed.to_u128) & XXH::Constants::MASK64).to_u64
      XXH::Primitives.write_u64_le(secret.to_unsafe + (16 * i), lo)
      XXH::Primitives.write_u64_le(secret.to_unsafe + (16 * i + 8), hi)
      i += 1
    end
    # Stack-allocated for LLVM auto-vectorization
    acc = uninitialized UInt64[8]
    XXH::XXH3.init_acc(acc.to_unsafe)
    hash_long_internal_loop(acc.to_unsafe, ptr, len, secret.to_unsafe, secret_size)
    finalize_long_128b(acc.to_unsafe, secret.to_unsafe, secret_size, len.to_u64)
  end
end
