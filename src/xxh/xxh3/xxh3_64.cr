module XXH::XXH3
  # ============================================================================
  # 64-bit One-Shot Hashing: Small Input Paths (0..16 bytes)
  # ============================================================================

  def self.len_1to3_64b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : UInt64
    c1 = ptr[0]
    c2 = ptr[len >> 1]
    c3 = ptr[len - 1]
    combined = ((c1.to_u32 << 16) | (c2.to_u32 << 24) | (c3.to_u32) | (len.to_u32 << 8)).to_u64
    bitflip = (XXH::Primitives.read_u32_le(secret_ptr).to_u64 ^ XXH::Primitives.read_u32_le(secret_ptr + 4).to_u64) &+ seed
    keyed = combined ^ bitflip
    XXH::XXH64.avalanche(keyed)
  end

  def self.len_4to8_64b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : UInt64
    seed = seed ^ (((XXH::Primitives.bswap32((seed & 0xFFFFFFFF_u64).to_u32).to_u128 << 32) & XXH::Constants::MASK64).to_u64)
    input1 = XXH::Primitives.read_u32_le(ptr)
    input2 = XXH::Primitives.read_u32_le(ptr + (len - 4))
    bf = XXH::Primitives.read_u64_le(secret_ptr + 8).to_u128 ^ XXH::Primitives.read_u64_le(secret_ptr + 16).to_u128
    bitflip = ((bf &- seed.to_u128) & XXH::Constants::MASK64).to_u64
    input64 = input2.to_u64 | (input1.to_u64 << 32)
    keyed = input64 ^ bitflip
    rrmxmx(keyed, len.to_u64)
  end

  def self.len_9to16_64b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : UInt64
    bf1 = XXH::Primitives.read_u64_le(secret_ptr + 24).to_u128 ^ XXH::Primitives.read_u64_le(secret_ptr + 32).to_u128
    bf2 = XXH::Primitives.read_u64_le(secret_ptr + 40).to_u128 ^ XXH::Primitives.read_u64_le(secret_ptr + 48).to_u128
    bitflip1 = ((bf1 + seed.to_u128) & XXH::Constants::MASK64).to_u64
    bitflip2 = ((bf2 &- seed.to_u128) & XXH::Constants::MASK64).to_u64
    input_lo = XXH::Primitives.read_u64_le(ptr) ^ bitflip1
    input_hi = XXH::Primitives.read_u64_le(ptr + (len - 8)) ^ bitflip2
    acc = len.to_u64 &+ XXH::Primitives.bswap64(input_lo) &+ input_hi &+ mul128_fold64(input_lo, input_hi)
    xx3_avalanche(acc)
  end

  def self.len_0to16_64b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : UInt64
    @[Likely]
    if len == 0
      return XXH::XXH64.avalanche(seed ^ (XXH::Primitives.read_u64_le(secret_ptr + 56) ^ XXH::Primitives.read_u64_le(secret_ptr + 64)))
    elsif len <= 3
      return len_1to3_64b(ptr, len, secret_ptr, seed)
    elsif len <= 8
      return len_4to8_64b(ptr, len, secret_ptr, seed)
      @[Unlikely]
    else
      return len_9to16_64b(ptr, len, secret_ptr, seed)
    end
  end

  # ============================================================================
  # 64-bit One-Shot Hashing: Medium Input Paths (17..240 bytes)
  # ============================================================================

  def self.len_17to128_64b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : UInt64
    acc = len.to_u64 &* XXH::Constants::PRIME64_1

    if len > 32
      if len > 64
        if len > 96
          acc = acc &+ mix16b(ptr + 48, secret_ptr + 96, seed)
          acc = acc &+ mix16b(ptr + (len - 64), secret_ptr + 112, seed)
        end
        acc = acc &+ mix16b(ptr + 32, secret_ptr + 64, seed)
        acc = acc &+ mix16b(ptr + (len - 48), secret_ptr + 80, seed)
      end
      acc = acc &+ mix16b(ptr + 16, secret_ptr + 32, seed)
      acc = acc &+ mix16b(ptr + (len - 32), secret_ptr + 48, seed)
    end

    acc = acc &+ mix16b(ptr + 0, secret_ptr + 0, seed)
    acc = acc &+ mix16b(ptr + (len - 16), secret_ptr + 16, seed)

    xx3_avalanche(acc)
  end

  def self.len_129to240_64b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : UInt64
    acc = len.to_u64 &* XXH::Constants::PRIME64_1
    # first 8 rounds
    8.times do |i|
      acc = acc &+ mix16b(ptr + (16 * i), secret_ptr + (16 * i), seed)
    end

    acc_end = mix16b(ptr + (len - 16), secret_ptr + (XXH::Constants::XXH3_SECRET_SIZE_MIN - 17), seed)

    # per reference: avalanche the first accumulator before processing remaining rounds
    acc = xx3_avalanche(acc)

    nb_rounds = len.tdiv(16)
    (8...nb_rounds).each do |i|
      acc_end = acc_end &+ mix16b(ptr + (16 * i), secret_ptr + (16 * (i - 8)) + 3, seed)
    end

    xx3_avalanche(acc &+ acc_end)
  end

  # ============================================================================
  # 64-bit One-Shot Hashing: Main Dispatch
  # ============================================================================

  def self.hash(input : Bytes) : UInt64
    len = input.size
    ptr = input.to_unsafe
    secret = XXH::Buffers.default_secret.to_unsafe

    @[Likely]
    if len <= 16
      return len_0to16_64b(ptr, len, secret.as(Pointer(UInt8)), 0_u64)
    elsif len <= 128
      return len_17to128_64b(ptr, len, secret.as(Pointer(UInt8)), 0_u64)
    elsif len <= 240
      return len_129to240_64b(ptr, len, secret.as(Pointer(UInt8)), 0_u64)
      @[Unlikely]
    else
      return hash_long_64b(ptr, len, secret.as(Pointer(UInt8)), XXH::Buffers.default_secret.size)
    end
  end

  def self.hash_with_seed(input : Bytes, seed : UInt64) : UInt64
    ptr = input.to_unsafe
    secret = XXH::Buffers.default_secret.to_unsafe
    len = input.size

    @[Likely]
    if len <= 16
      return len_0to16_64b(ptr, len, secret.as(Pointer(UInt8)), seed)
    elsif len <= 128
      return len_17to128_64b(ptr, len, secret.as(Pointer(UInt8)), seed)
    elsif len <= 240
      return len_129to240_64b(ptr, len, secret.as(Pointer(UInt8)), seed)
      @[Unlikely]
    else
      return hash_long_64b_with_seed(ptr, len, seed, secret.as(Pointer(UInt8)), XXH::Buffers.default_secret.size)
    end
  end

  # ============================================================================
  # 64-bit Long Input Hashing (240+ bytes)
  # ============================================================================

  @[AlwaysInline]
  def self.finalize_long_64b(acc0 : UInt64, acc1 : UInt64, acc2 : UInt64, acc3 : UInt64, acc4 : UInt64, acc5 : UInt64, acc6 : UInt64, acc7 : UInt64, secret_ptr : Pointer(UInt8), len : UInt64) : UInt64
    # Convert individual values back to array for merge_accs
    acc = uninitialized UInt64[8]
    acc[0] = acc0
    acc[1] = acc1
    acc[2] = acc2
    acc[3] = acc3
    acc[4] = acc4
    acc[5] = acc5
    acc[6] = acc6
    acc[7] = acc7
    merge_accs(acc.to_unsafe, secret_ptr + 11, len &* 0x9E3779B185EBCA87_u64)
  end

  def self.hash_long_64b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), secret_size : Int32) : UInt64
    # follow XXH3_hashLong_64b_internal logic
    # Stack-allocated for LLVM auto-vectorization
    acc = uninitialized UInt64[8]
    acc[0] = 0xC2B2AE3D_u64
    acc[1] = 0x9E3779B185EBCA87_u64
    acc[2] = 0xC2B2AE3D27D4EB4F_u64
    acc[3] = 0x165667B19E3779F9_u64
    acc[4] = 0x85EBCA77C2B2AE63_u64
    acc[5] = 0x85EBCA77_u64
    acc[6] = 0x27D4EB2F165667C5_u64
    acc[7] = 0x9E3779B1_u64

    hash_long_internal_loop(acc.to_unsafe, ptr, len, secret_ptr, secret_size)

    finalize_long_64b(acc[0], acc[1], acc[2], acc[3], acc[4], acc[5], acc[6], acc[7], secret_ptr, len.to_u64)
  end

  def self.hash_long_64b_with_seed(ptr : Pointer(UInt8), len : Int32, seed : UInt64, _secret_ptr : Pointer(UInt8), secret_size : Int32) : UInt64
    # For seeded long hash, generate custom secret from default secret and seed
    secret = Bytes.new(XXH::Constants::SECRET_DEFAULT_SIZE) { |i| XXH::Buffers.default_secret[i] }
    # init custom secret like C's XXH3_initCustomSecret
    nrounds = XXH::Constants::SECRET_DEFAULT_SIZE / 16
    i = 0
    while i < nrounds
      lo = XXH::Primitives.read_u64_le(secret.to_unsafe + (16 * i)) &+ seed
      hi = XXH::Primitives.read_u64_le(secret.to_unsafe + (16 * i + 8)) &- seed
      XXH::Primitives.write_u64_le(secret.to_unsafe + (16 * i), lo)
      XXH::Primitives.write_u64_le(secret.to_unsafe + (16 * i + 8), hi)
      i += 1
    end

    hash_long_64b(ptr, len, secret.to_unsafe.as(Pointer(UInt8)), secret_size)
  end
end
