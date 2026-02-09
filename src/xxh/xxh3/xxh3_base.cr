module XXH::XXH3
  # ============================================================================
  # Shared Helper Functions (used by both 64-bit and 128-bit variants)
  # ============================================================================

  # Initial accumulator values (per XXH3 spec)
  INIT_ACC = [
    0xC2B2AE3D_u64,
    0x9E3779B185EBCA87_u64,
    0xC2B2AE3D27D4EB4F_u64,
    0x165667B19E3779F9_u64,
    0x85EBCA77C2B2AE63_u64,
    0x85EBCA77_u64,
    0x27D4EB2F165667C5_u64,
    0x9E3779B1_u64,
  ]

  # Helpers ported from C reference implementation (small-input paths)
  @[AlwaysInline]
  def self.mul128_fold64(lhs : UInt64, rhs : UInt64) : UInt64
    product = lhs.to_u128 * rhs.to_u128
    low = (product & XXH::Constants::MASK64).to_u64
    high = (product >> 64).to_u64
    low ^ high
  end

  @[AlwaysInline]
  def self.xorshift64(v : UInt64, shift : Int32) : UInt64
    v ^ (v >> shift)
  end

  @[AlwaysInline]
  def self.xx3_avalanche(h64 : UInt64) : UInt64
    h = xorshift64(h64, 37)
    h = h &* XXH::Constants::PRIME_MX1
    h = xorshift64(h, 32)
    h
  end

  @[AlwaysInline]
  def self.rrmxmx(h64 : UInt64, len : UInt64) : UInt64
    h = h64
    h ^= XXH::Primitives.rotl64(h, 49_u32) ^ XXH::Primitives.rotl64(h, 24_u32)
    h = h &* XXH::Constants::PRIME_MX2
    h ^= (h >> 35) &+ len
    h = h &* XXH::Constants::PRIME_MX2
    xorshift64(h, 28)
  end

  # 128-bit helpers
  @[AlwaysInline]
  def self.mult64to128(lhs : UInt64, rhs : UInt64) : Hash128
    product = lhs.to_u128 * rhs.to_u128
    low = (product & XXH::Constants::MASK64).to_u64
    high = (product >> 64).to_u64
    Hash128.new(low, high)
  end

  def self.xx3_avalanche_128(acc : Hash128) : Hash128
    # Avalanche both halves independently
    low = xx3_avalanche(acc.low64)
    high = xx3_avalanche(acc.high64)
    Hash128.new(low, high)
  end

  # ============================================================================
  # Accumulation and Scrambling (hot path for long inputs)
  # ============================================================================

  # Mixing function for 16-byte blocks
  @[AlwaysInline]
  def self.mix16b(ptr : Pointer(UInt8), secret_ptr : Pointer(UInt8), seed : UInt64) : UInt64
    in_lo = XXH::Primitives.read_u64_le(ptr)
    in_hi = XXH::Primitives.read_u64_le(ptr + 8)

    s0 = XXH::Primitives.read_u64_le(secret_ptr)
    s1 = XXH::Primitives.read_u64_le(secret_ptr + 8)

    # Use wrapping arithmetic on 64-bit values instead of expensive u128 casts
    v1 = s0 &+ seed
    v2 = s1 &- seed

    lhs = in_lo ^ v1
    rhs = in_hi ^ v2

    mul128_fold64(lhs, rhs)
  end

  # Multiply lower 32-bit parts with wrapping arithmetic
  @[AlwaysInline]
  def self.mult32to64_add64(lhs : UInt64, rhs : UInt64, acc : UInt64) : UInt64
    m = (lhs & 0xFFFFFFFF_u64) &* (rhs & 0xFFFFFFFF_u64)
    (m &+ acc)
  end

  # Single round of accumulation on one lane
  @[AlwaysInline]
  def self.scalar_round(acc : Pointer(UInt64), input_ptr : Pointer(UInt8), secret_ptr : Pointer(UInt8), lane : Int32)
    data_val = XXH::Primitives.read_u64_le(input_ptr + (lane * 8))
    data_key = data_val ^ XXH::Primitives.read_u64_le(secret_ptr + (lane * 8))
    acc[lane ^ 1] = (acc[lane ^ 1] &+ data_val)
    acc[lane] = mult32to64_add64(data_key, (data_key >> 32), acc[lane])
  end

  # Accumulate one 512-bit block (8 lanes of 64-bit) using scalar operations
  @[AlwaysInline]
  def self.accumulate_512_scalar(acc : Pointer(UInt64), input_ptr : Pointer(UInt8), secret_ptr : Pointer(UInt8))
    i = 0
    while i < 8
      scalar_round(acc, input_ptr, secret_ptr, i)
      i += 1
    end
  end

  # Accumulate multiple 512-bit stripes with unrolled loop (2-stripe batches)
  @[AlwaysInline]
  def self.accumulate_scalar(acc : Pointer(UInt64), input_ptr : Pointer(UInt8), secret_ptr : Pointer(UInt8), nbStripes : Int32)
    n = 0
    in_ptr = input_ptr
    secret_off = 0
    prefetch_dist = 128
    # Unroll by 2 stripes per loop with light prefetch
    while n + 1 < nbStripes
      # prefetch next stripe
      _ = XXH::Primitives.read_u64_le(in_ptr + prefetch_dist)

      accumulate_512_scalar(acc, in_ptr, secret_ptr + secret_off)
      accumulate_512_scalar(acc, in_ptr + 64, secret_ptr + secret_off + 8)
      in_ptr = in_ptr + 128
      secret_off = secret_off + 16
      n += 2
    end
    while n < nbStripes
      accumulate_512_scalar(acc, in_ptr, secret_ptr + secret_off)
      in_ptr = in_ptr + 64
      secret_off = secret_off + 8
      n += 1
    end
  end

  # Scramble one lane of accumulator
  @[AlwaysInline]
  def self.scalar_scramble_round(acc : Pointer(UInt64), secret_ptr : Pointer(UInt8), lane : Int32)
    key64 = XXH::Primitives.read_u64_le(secret_ptr + (lane * 8))
    acc64 = acc[lane]
    acc64 = xorshift64(acc64, 47)
    acc64 = acc64 ^ key64
    acc64 = acc64 &* 0x9E3779B1_u64
    acc[lane] = acc64
  end

  # Scramble all 8 accumulator lanes
  @[AlwaysInline]
  def self.scramble_acc_scalar(acc : Pointer(UInt64), secret_ptr : Pointer(UInt8))
    i = 0
    while i < 8
      scalar_scramble_round(acc, secret_ptr, i)
      i += 1
    end
  end

  # ============================================================================
  # Finalization Helpers (merging accumulators)
  # ============================================================================

  # Mix two accumulators with secret
  @[AlwaysInline]
  def self.mix2accs(acc : Pointer(UInt64), idx0 : Int32, idx1 : Int32, secret_ptr : Pointer(UInt8)) : UInt64
    mul128_fold64(acc[idx0] ^ XXH::Primitives.read_u64_le(secret_ptr), acc[idx1] ^ XXH::Primitives.read_u64_le(secret_ptr + 8))
  end

  # Merge all 8 accumulators into a single 64-bit hash
  @[AlwaysInline]
  def self.merge_accs(acc : Pointer(UInt64), secret_ptr : Pointer(UInt8), start : UInt64) : UInt64
    result = start
    i = 0
    while i < 4
      pair_idx = 2 * i
      result = result &+ mix2accs(acc, pair_idx, pair_idx + 1, secret_ptr + (16 * i))
      i += 1
    end
    xx3_avalanche(result)
  end

  # Initialize accumulator lanes from the canonical INIT_ACC constants
  def self.init_acc(acc_ptr : Pointer(UInt64)) : Nil
    i = 0
    while i < 8
      acc_ptr[i] = INIT_ACC[i]
      i += 1
    end
  end

  # Initialize a custom secret derived from the provided secret and seed.
  # Writes into `dest_ptr` a secret of `secret_size` bytes produced by adding
  # the seed to the low 64-bit word and subtracting the seed from the high 64-bit word
  # for each 16-byte block.
  #
  # This helper is used by the streaming `State` and `State128` implementations
  # to initialize `@custom_secret` when a non-zero seed is provided.
  def self.init_custom_secret(dest_ptr : Pointer(UInt8), secret_ptr : Pointer(UInt8), secret_size : Int32, seed : UInt64) : Nil
    nrounds = (secret_size / 16).to_i
    i = 0
    while i < nrounds
      lo = XXH::Primitives.read_u64_le(secret_ptr + (16 * i)) &+ seed
      hi = XXH::Primitives.read_u64_le(secret_ptr + (16 * i + 8)) &- seed
      XXH::Primitives.write_u64_le(dest_ptr + (16 * i), lo)
      XXH::Primitives.write_u64_le(dest_ptr + (16 * i + 8), hi)
      i += 1
    end
  end

  # ============================================================================
  # Long Input Processing Loop (shared by 64-bit and 128-bit)
  # ============================================================================

  def self.hash_long_internal_loop(acc : Pointer(UInt64), input_ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), secret_size : Int32)
    nbStripesPerBlock = ((secret_size - 64) / 8).to_i
    block_len = 64 * nbStripesPerBlock
    nb_blocks = ((len - 1) / block_len).to_i

    n = 0
    in_ptr = input_ptr
    while n < nb_blocks
      accumulate_scalar(acc, in_ptr, secret_ptr, nbStripesPerBlock)
      scramble_acc_scalar(acc, secret_ptr + (secret_size - 64))
      in_ptr = in_ptr + block_len
      n += 1
    end

    if len > 64
      nbStripes = (((len - 1) - (block_len * nb_blocks)) / 64).to_i
      accumulate_scalar(acc, in_ptr, secret_ptr, nbStripes)

      p = input_ptr + (len - 64)
      accumulate_512_scalar(acc, p, secret_ptr + (secret_size - 64 - 7))
    end
  end
end
