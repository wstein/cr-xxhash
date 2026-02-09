require "./xxh3_types"
require "./xxh3_base"

module XXH::XXH3
  # ============================================================================
  # 64-bit One-Shot Hashing: Small Input Paths (0..16 bytes)
  # ============================================================================

  def self.len_1to3_64b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : UInt64
    c1 = ptr[0]
    c2 = ptr[len >> 1]
    c3 = ptr[len - 1]
    combined = ((c1.to_u32 << 16) | (c2.to_u32 << 24) | c3.to_u32 | (len.to_u32 << 8))
    bitflip = (XXH::Primitives.read_u32_le(secret_ptr) ^ XXH::Primitives.read_u32_le(secret_ptr + 4)).to_u64 &+ seed
    keyed = combined.to_u64 ^ bitflip
    XXH::XXH64.avalanche(keyed)
  end

  def self.len_4to8_64b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : UInt64
    seed_mod = seed ^ ((XXH::Primitives.bswap32((seed & 0xFFFFFFFF_u64).to_u32).to_u64) << 32)
    input1 = XXH::Primitives.read_u32_le(ptr)
    input2 = XXH::Primitives.read_u32_le(ptr + (len - 4))
    input_64 = input2.to_u64 &+ (input1.to_u64 << 32)
    bitflip = (XXH::Primitives.read_u64_le(secret_ptr + 8) ^ XXH::Primitives.read_u64_le(secret_ptr + 16)) &- seed_mod
    keyed = input_64 ^ bitflip
    rrmxmx(keyed, len.to_u64)
  end

  def self.len_9to16_64b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : UInt64
    bitflip1 = (XXH::Primitives.read_u64_le(secret_ptr + 24) ^ XXH::Primitives.read_u64_le(secret_ptr + 32)) &+ seed
    bitflip2 = (XXH::Primitives.read_u64_le(secret_ptr + 40) ^ XXH::Primitives.read_u64_le(secret_ptr + 48)) &- seed
    input_lo = XXH::Primitives.read_u64_le(ptr) ^ bitflip1
    input_hi = XXH::Primitives.read_u64_le(ptr + (len - 8)) ^ bitflip2
    acc = len.to_u64 &+ XXH::Primitives.bswap64(input_lo) &+ input_hi &+ XXH::XXH3.mul128_fold64(input_lo, input_hi)
    XXH::XXH3.xx3_avalanche(acc)
  end

  def self.len_0to16_64b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : UInt64
    if len > 8
      return len_9to16_64b(ptr, len, secret_ptr, seed)
    elsif len >= 4
      return len_4to8_64b(ptr, len, secret_ptr, seed)
    elsif len != 0
      return len_1to3_64b(ptr, len, secret_ptr, seed)
    else
      # len == 0
      bitflip = XXH::Primitives.read_u64_le(secret_ptr + 56) ^ XXH::Primitives.read_u64_le(secret_ptr + 64)
      return XXH::XXH64.avalanche(seed ^ bitflip)
    end
  end

  # ============================================================================
  # 64-bit One-Shot Hashing: Medium Input Paths (17..240 bytes)
  # ============================================================================

  def self.len_17to128_64b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : UInt64
    acc = len.to_u64 &* XXH::Constants::PRIME64_1

    # Use smaller version (per XXH_SIZE_OPT >= 1 optimization)
    i = (len - 1).tdiv(32)
    while i >= 0
      acc &+= XXH::XXH3.mix16b(ptr + (16 * i), secret_ptr + (32 * i), seed)
      acc &+= XXH::XXH3.mix16b(ptr + (len - 16 * (i + 1)), secret_ptr + (32 * i + 16), seed)
      i -= 1
    end

    XXH::XXH3.xx3_avalanche(acc)
  end

  def self.len_129to240_64b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : UInt64
    acc = len.to_u64 &* XXH::Constants::PRIME64_1
    acc_end = 0_u64

    # First 8 rounds: mix 16 bytes each from start using fixed secret offsets
    i = 0
    while i < 8
      acc &+= XXH::XXH3.mix16b(ptr + (16 * i), secret_ptr + (16 * i), seed)
      i += 1
    end

    # Last block: always mix at least one 16-byte chunk from the end
    acc_end = XXH::XXH3.mix16b(ptr + (len - 16), secret_ptr + 136 - 17, seed)

    # Intermediate avalanche of acc
    acc = XXH::XXH3.xx3_avalanche(acc)

    # Process remaining complete 16-byte blocks
    nb_rounds = len.tdiv(16)
    i = 8
    while i < nb_rounds
      acc_end &+= XXH::XXH3.mix16b(ptr + (16 * i), secret_ptr + (16 * (i - 8)) + 3, seed)
      i += 1
    end

    XXH::XXH3.xx3_avalanche(acc &+ acc_end)
  end

  # ============================================================================
  # 64-bit One-Shot Hashing: Main Dispatch
  # ============================================================================

  def self.hash64(input : Bytes) : UInt64
    ptr = input.to_unsafe
    len = input.size

    @[Likely]
    if len <= 16
      secret = XXH::Buffers.default_secret.to_unsafe
      return len_0to16_64b(ptr, len, secret.as(Pointer(UInt8)), 0_u64)
    elsif len <= 128
      # Phase 2a: 17-128 bytes
      secret = XXH::Buffers.default_secret.to_unsafe
      return len_17to128_64b(ptr, len, secret.as(Pointer(UInt8)), 0_u64)
    elsif len <= 240
      # Phase 2b: 129-240 bytes (native implementation)
      secret = XXH::Buffers.default_secret.to_unsafe
      return len_129to240_64b(ptr, len, secret.as(Pointer(UInt8)), 0_u64)
      @[Unlikely]
    else
      # Phase 3: 240+ bytes (native implementation)
      secret = XXH::Buffers.default_secret.to_unsafe
      return hash_long_64b(ptr, len, secret.as(Pointer(UInt8)), XXH::Buffers.default_secret.size)
    end
  end

  def self.hash64_with_seed(input : Bytes, seed : UInt64) : UInt64
    ptr = input.to_unsafe
    len = input.size

    if len <= 16
      secret = XXH::Buffers.default_secret.to_unsafe
      return len_0to16_64b(ptr, len, secret.as(Pointer(UInt8)), seed)
    elsif len <= 128
      # Phase 2a: 17-128 bytes
      secret = XXH::Buffers.default_secret.to_unsafe
      return len_17to128_64b(ptr, len, secret.as(Pointer(UInt8)), seed)
    elsif len <= 240
      # Phase 2b: 129-240 bytes (native implementation)
      secret = XXH::Buffers.default_secret.to_unsafe
      return len_129to240_64b(ptr, len, secret.as(Pointer(UInt8)), seed)
    else
      # Phase 3: 240+ bytes (native implementation)
      secret = XXH::Buffers.default_secret.to_unsafe
      return hash_long_64b_with_seed(ptr, len, seed, secret.as(Pointer(UInt8)), XXH::Buffers.default_secret.size)
    end
  end

  # ============================================================================
  # 64-bit Long Input Hashing (240+ bytes)
  # ============================================================================

  def self.finalize_long_64b(acc0 : UInt64, acc1 : UInt64, acc2 : UInt64, acc3 : UInt64, acc4 : UInt64, acc5 : UInt64, acc6 : UInt64, acc7 : UInt64, secret_ptr : Pointer(UInt8), len : UInt64) : UInt64
    # Build accumulator array for merge_accs
    acc = uninitialized UInt64[8]
    acc[0] = acc0
    acc[1] = acc1
    acc[2] = acc2
    acc[3] = acc3
    acc[4] = acc4
    acc[5] = acc5
    acc[6] = acc6
    acc[7] = acc7
    XXH::XXH3.merge_accs(acc.to_unsafe, secret_ptr + 11, len &* XXH::Constants::PRIME64_1)
  end

  def self.hash_long_64b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), secret_size : Int32) : UInt64
    # Stack-allocated for LLVM auto-vectorization
    acc = uninitialized UInt64[8]
    XXH::XXH3.init_acc(acc.to_unsafe)
    hash_long_internal_loop(acc.to_unsafe, ptr, len, secret_ptr, secret_size)
    finalize_long_64b(acc[0], acc[1], acc[2], acc[3], acc[4], acc[5], acc[6], acc[7], secret_ptr, len.to_u64)
  end

  def self.hash_long_64b_with_seed(ptr : Pointer(UInt8), len : Int32, seed : UInt64, default_secret_ptr : Pointer(UInt8), secret_size : Int32) : UInt64
    if seed == 0_u64
      return hash_long_64b(ptr, len, default_secret_ptr, secret_size)
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
    finalize_long_64b(acc[0], acc[1], acc[2], acc[3], acc[4], acc[5], acc[6], acc[7], secret.to_unsafe, len.to_u64)
  end

  # ============================================================================
  # Public API: Main hash functions (non-streaming)
  # ============================================================================

  def self.hash(input : Bytes) : UInt64
    hash64(input)
  end

  def self.hash_with_seed(input : Bytes, seed : UInt64) : UInt64
    hash64_with_seed(input, seed)
  end
end
