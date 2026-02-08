module XXH::XXH3
  # 128-bit result type
  struct Hash128
    property low64 : UInt64
    property high64 : UInt64

    def initialize(low64 : UInt64, high64 : UInt64)
      @low64 = low64
      @high64 = high64
    end

    def ==(other : Hash128)
      @low64 == other.low64 && @high64 == other.high64
    end

    def to_tuple
      {@low64, @high64}
    end
  end

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
  def self.mul128_fold64(lhs : UInt64, rhs : UInt64) : UInt64
    product = lhs.to_u128 * rhs.to_u128
    low = (product & ((1_u128 << 64) - 1)).to_u64
    high = (product >> 64).to_u64
    low ^ high
  end

  def self.xorshift64(v : UInt64, shift : Int32) : UInt64
    v ^ (v >> shift)
  end

  def self.xx3_avalanche(h64 : UInt64) : UInt64
    h = xorshift64(h64, 37)
    h = h &* XXH::Constants::PRIME_MX1
    h = xorshift64(h, 32)
    h
  end

  def self.rrmxmx(h64 : UInt64, len : UInt64) : UInt64
    h = h64
    h ^= XXH::Primitives.rotl64(h, 49_u32) ^ XXH::Primitives.rotl64(h, 24_u32)
    h = h &* XXH::Constants::PRIME_MX2
    h ^= (h >> 35) &+ len
    h = h &* XXH::Constants::PRIME_MX2
    xorshift64(h, 28)
  end

  # 128-bit helpers
  def self.mult64to128(lhs : UInt64, rhs : UInt64) : Hash128
    product = lhs.to_u128 * rhs.to_u128
    low = (product & ((1_u128 << 64) - 1)).to_u64
    high = (product >> 64).to_u64
    Hash128.new(low, high)
  end

  def self.xx3_avalanche_128(acc : Hash128) : Hash128
    # Avalanche both halves independently
    low = xx3_avalanche(acc.low64)
    high = xx3_avalanche(acc.high64)
    Hash128.new(low, high)
  end

  # 0..16 bytes handlers
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
    mask = (1_u128 << 64) - 1
    seed = seed ^ (((XXH::Primitives.bswap32((seed & 0xFFFFFFFF_u64).to_u32).to_u128 << 32) & mask).to_u64)
    input1 = XXH::Primitives.read_u32_le(ptr)
    input2 = XXH::Primitives.read_u32_le(ptr + (len - 4))
    bf = XXH::Primitives.read_u64_le(secret_ptr + 8).to_u128 ^ XXH::Primitives.read_u64_le(secret_ptr + 16).to_u128
    bitflip = ((bf &- seed.to_u128) & ((1_u128 << 64) - 1)).to_u64
    input64 = input2.to_u64 | (input1.to_u64 << 32)
    keyed = input64 ^ bitflip
    rrmxmx(keyed, len.to_u64)
  end

  def self.len_9to16_64b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : UInt64
    bf1 = XXH::Primitives.read_u64_le(secret_ptr + 24).to_u128 ^ XXH::Primitives.read_u64_le(secret_ptr + 32).to_u128
    bf2 = XXH::Primitives.read_u64_le(secret_ptr + 40).to_u128 ^ XXH::Primitives.read_u64_le(secret_ptr + 48).to_u128
    bitflip1 = ((bf1 + seed.to_u128) & ((1_u128 << 64) - 1)).to_u64
    bitflip2 = ((bf2 &- seed.to_u128) & ((1_u128 << 64) - 1)).to_u64
    input_lo = XXH::Primitives.read_u64_le(ptr) ^ bitflip1
    input_hi = XXH::Primitives.read_u64_le(ptr + (len - 8)) ^ bitflip2
    acc = len.to_u64 &+ XXH::Primitives.bswap64(input_lo) &+ input_hi &+ mul128_fold64(input_lo, input_hi)
    xx3_avalanche(acc)
  end

  def self.len_0to16_64b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : UInt64
    if len == 0
      return XXH::XXH64.avalanche(seed ^ (XXH::Primitives.read_u64_le(secret_ptr + 56) ^ XXH::Primitives.read_u64_le(secret_ptr + 64)))
    elsif len <= 3
      return len_1to3_64b(ptr, len, secret_ptr, seed)
    elsif len <= 8
      return len_4to8_64b(ptr, len, secret_ptr, seed)
    else
      return len_9to16_64b(ptr, len, secret_ptr, seed)
    end
  end

  # 128-bit simple paths (0..16 bytes)
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
    m128.high64 = xx3_avalanche(m128.high64)

    m128
  end

  def self.len_9to16_128b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : Hash128
    bitflipl = (XXH::Primitives.read_u64_le(secret_ptr + 32) ^ XXH::Primitives.read_u64_le(secret_ptr + 40)) &- seed
    bitfliph = (XXH::Primitives.read_u64_le(secret_ptr + 48) ^ XXH::Primitives.read_u64_le(secret_ptr + 56)) &+ seed

    input_lo = XXH::Primitives.read_u64_le(ptr)
    input_hi = XXH::Primitives.read_u64_le(ptr + (len - 8))

    m128 = mult64to128(input_lo ^ input_hi ^ bitflipl, XXH::Constants::PRIME64_1)

    m128.low64 &+= ((len - 1).to_u64 << 54)
    input_hi ^= bitfliph

    # 64-bit version:
    m128.high64 &+= input_hi &+ mult32to64_len9to16((input_hi & 0xFFFFFFFF_u64).to_u32, XXH::Constants::PRIME32_2 &- 1)

    m128.low64 ^= XXH::Primitives.bswap64(m128.high64)

    h128 = mult64to128(m128.low64, XXH::Constants::PRIME64_2)
    h128.high64 &+= m128.high64 &* XXH::Constants::PRIME64_2

    h128.low64 = xx3_avalanche(h128.low64)
    h128.high64 = xx3_avalanche(h128.high64)

    h128
  end

  def self.mult32to64_len9to16(lhs : UInt32, rhs : UInt32) : UInt64
    (lhs.to_u64 * rhs.to_u64) & ((1_u128 << 64) - 1)
  end

  # 128-bit medium paths (17..240)
  def self.mix32b_128b(acc : Hash128, input_1_ptr : Pointer(UInt8), input_2_ptr : Pointer(UInt8), secret_ptr : Pointer(UInt8), seed : UInt64) : Hash128
    acc.low64 &+= mix16b(input_1_ptr, secret_ptr, seed)
    acc.low64 ^= (XXH::Primitives.read_u64_le(input_2_ptr) &+ XXH::Primitives.read_u64_le(input_2_ptr + 8))

    acc.high64 &+= mix16b(input_2_ptr, secret_ptr + 16, seed)
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

    h128.low64 = xx3_avalanche(h128.low64)
    h128.high64 = (0_u64 &- xx3_avalanche(h128.high64))

    h128
  end

  def self.len_129to240_128b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), seed : UInt64) : Hash128
    acc = Hash128.new(len.to_u64 &* XXH::Constants::PRIME64_1, 0_u64)

    i = 32
    while i < 160
      acc = mix32b_128b(acc, ptr + (i - 32), ptr + (i - 16), secret_ptr + (i - 32), seed)
      i += 32
    end

    acc.low64 = xx3_avalanche(acc.low64)
    acc.high64 = xx3_avalanche(acc.high64)

    i = 160
    while i <= len
      acc = mix32b_128b(acc, ptr + (i - 32), ptr + (i - 16), secret_ptr + XXH::Constants::XXH3_MIDSIZE_STARTOFFSET + (i - 160), seed)
      i += 32
    end

    acc = mix32b_128b(acc, ptr + (len - 16), ptr + (len - 32), secret_ptr + XXH::Constants::XXH3_SECRET_SIZE_MIN - XXH::Constants::XXH3_MIDSIZE_LASTOFFSET - 16, (0_u64 &- seed))

    h128 = Hash128.new(acc.low64 &+ acc.high64, 0_u64)
    h128.high64 = (acc.low64 &* XXH::Constants::PRIME64_1) &+ (acc.high64 &* XXH::Constants::PRIME64_4) &+ ((len.to_u64 &- seed) &* XXH::Constants::PRIME64_2)

    h128.low64 = xx3_avalanche(h128.low64)
    h128.high64 = (0_u64 &- xx3_avalanche(h128.high64))

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

  # Middle-length (17..128) helper
  def self.mix16b(ptr : Pointer(UInt8), secret_ptr : Pointer(UInt8), seed : UInt64) : UInt64
    mask = (1_u128 << 64) - 1
    in_lo = XXH::Primitives.read_u64_le(ptr)
    in_hi = XXH::Primitives.read_u64_le(ptr + 8)

    s0 = XXH::Primitives.read_u64_le(secret_ptr).to_u128
    s1 = XXH::Primitives.read_u64_le(secret_ptr + 8).to_u128

    v1 = (s0 + seed.to_u128) & mask
    v2 = (s1 &- seed.to_u128) & mask

    lhs = in_lo ^ v1.to_u64
    rhs = in_hi ^ v2.to_u64

    mul128_fold64(lhs, rhs)
  end

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

  # One-shot hashing (iterative: implement small and medium inputs)
  def self.hash(input : Bytes) : UInt64
    len = input.size
    ptr = input.to_unsafe
    secret = XXH::Buffers.default_secret.to_unsafe

    if len <= 16
      return len_0to16_64b(ptr, len, secret.as(Pointer(UInt8)), 0_u64)
    elsif len <= 128
      return len_17to128_64b(ptr, len, secret.as(Pointer(UInt8)), 0_u64)
    elsif len <= 240
      return len_129to240_64b(ptr, len, secret.as(Pointer(UInt8)), 0_u64)
    else
      return hash_long_64b(ptr, len, secret.as(Pointer(UInt8)), XXH::Buffers.default_secret.size)
    end
  end

  def self.hash_with_seed(input : Bytes, seed : UInt64) : UInt64
    ptr = input.to_unsafe
    secret = XXH::Buffers.default_secret.to_unsafe
    len = input.size

    if len <= 16
      return len_0to16_64b(ptr, len, secret.as(Pointer(UInt8)), seed)
    elsif len <= 128
      return len_17to128_64b(ptr, len, secret.as(Pointer(UInt8)), seed)
    elsif len <= 240
      return len_129to240_64b(ptr, len, secret.as(Pointer(UInt8)), seed)
    else
      return hash_long_64b_with_seed(ptr, len, seed, secret.as(Pointer(UInt8)), XXH::Buffers.default_secret.size)
    end
  end

  def self.hash128(input : Bytes) : Hash128
    ptr = input.to_unsafe
    len = input.size

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

  # 129..240
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

  # Long input helpers (accumulate/scramble)
  def self.mult32to64_add64(lhs : UInt64, rhs : UInt64, acc : UInt64) : UInt64
    m = ((lhs & 0xFFFFFFFF_u64).to_u128 * (rhs & 0xFFFFFFFF_u64).to_u128) & ((1_u128 << 64) - 1)
    (m.to_u64 &+ acc)
  end

  def self.scalar_round(acc : Array(UInt64), input_ptr : Pointer(UInt8), secret_ptr : Pointer(UInt8), lane : Int32)
    data_val = XXH::Primitives.read_u64_le(input_ptr + (lane * 8))
    data_key = data_val ^ XXH::Primitives.read_u64_le(secret_ptr + (lane * 8))
    acc[lane ^ 1] = (acc[lane ^ 1] &+ data_val)
    acc[lane] = mult32to64_add64(data_key, (data_key >> 32), acc[lane])
  end

  def self.accumulate_512_scalar(acc : Array(UInt64), input_ptr : Pointer(UInt8), secret_ptr : Pointer(UInt8))
    (0...8).each do |i|
      scalar_round(acc, input_ptr, secret_ptr, i)
    end
  end

  def self.accumulate_scalar(acc : Array(UInt64), input_ptr : Pointer(UInt8), secret_ptr : Pointer(UInt8), nbStripes : Int32)
    n = 0
    while n < nbStripes
      in_ptr = input_ptr + (n * 64)
      # prefetch hint omitted
      accumulate_512_scalar(acc, in_ptr, secret_ptr + (n * 8))
      n += 1
    end
  end

  def self.scalar_scramble_round(acc : Array(UInt64), secret_ptr : Pointer(UInt8), lane : Int32)
    key64 = XXH::Primitives.read_u64_le(secret_ptr + (lane * 8))
    acc64 = acc[lane]
    acc64 = xorshift64(acc64, 47)
    acc64 = acc64 ^ key64
    acc64 = acc64 &* 0x9E3779B1_u64
    acc[lane] = acc64
  end

  def self.scramble_acc_scalar(acc : Array(UInt64), secret_ptr : Pointer(UInt8))
    (0...8).each do |i|
      scalar_scramble_round(acc, secret_ptr, i)
    end
  end

  def self.hash_long_64b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), secret_size : Int32) : UInt64
    # follow XXH3_hashLong_64b_internal logic
    acc = Array.new(8, 0_u64)
    acc[0] = 0xC2B2AE3D_u64
    acc[1] = 0x9E3779B185EBCA87_u64
    acc[2] = 0xC2B2AE3D27D4EB4F_u64
    acc[3] = 0x165667B19E3779F9_u64
    acc[4] = 0x85EBCA77C2B2AE63_u64
    acc[5] = 0x85EBCA77_u64
    acc[6] = 0x27D4EB2F165667C5_u64
    acc[7] = 0x9E3779B1_u64

    hash_long_internal_loop(acc, ptr, len, secret_ptr, secret_size)

    finalize_long_64b(acc, secret_ptr, len.to_u64)
  end

  def self.hash_long_64b_with_seed(ptr : Pointer(UInt8), len : Int32, seed : UInt64, _secret_ptr : Pointer(UInt8), secret_size : Int32) : UInt64
    # For seeded long hash, generate custom secret from default secret and seed
    secret = Bytes.new(XXH::Constants::SECRET_DEFAULT_SIZE) { |i| XXH::Buffers.default_secret[i] }
    # init custom secret like C's XXH3_initCustomSecret
    nrounds = (XXH::Constants::SECRET_DEFAULT_SIZE / 16).to_i
    (0...nrounds).each do |i|
      lo = XXH::Primitives.read_u64_le(secret.to_unsafe + (16 * i)) &+ seed
      hi = ((XXH::Primitives.read_u64_le(secret.to_unsafe + (16 * i + 8)).to_u128 &- seed.to_u128) & ((1_u128 << 64) - 1)).to_u64
      XXH::Primitives.write_u64_le(secret.to_unsafe + (16 * i), lo)
      XXH::Primitives.write_u64_le(secret.to_unsafe + (16 * i + 8), hi)
    end

    hash_long_64b(ptr, len, secret.to_unsafe.as(Pointer(UInt8)), secret_size)
  end

  def self.hash_long_internal_loop(acc : Array(UInt64), input_ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), secret_size : Int32)
    nbStripesPerBlock = (secret_size - 64).tdiv(8)
    block_len = 64 * nbStripesPerBlock
    nb_blocks = (len - 1).tdiv(block_len)

    n = 0
    while n < nb_blocks
      accumulate_scalar(acc, input_ptr + (n * block_len), secret_ptr, nbStripesPerBlock)
      scramble_acc_scalar(acc, secret_ptr + (secret_size - 64))
      n += 1
    end

    if len > 64
      nbStripes = ((len - 1) - (block_len * nb_blocks)).tdiv(64)
      accumulate_scalar(acc, input_ptr + (nb_blocks * block_len), secret_ptr, nbStripes)

      p = input_ptr + (len - 64)
      accumulate_512_scalar(acc, p, secret_ptr + (secret_size - 64 - 7))
    end
  end

  def self.mix2accs(acc : Array(UInt64), secret_ptr : Pointer(UInt8)) : UInt64
    mul128_fold64(acc[0] ^ XXH::Primitives.read_u64_le(secret_ptr), acc[1] ^ XXH::Primitives.read_u64_le(secret_ptr + 8))
  end

  def self.merge_accs(acc : Array(UInt64), secret_ptr : Pointer(UInt8), start : UInt64) : UInt64
    result = start
    4.times do |i|
      result = result &+ mix2accs(acc[2 * i, 2], secret_ptr + (16 * i))
    end
    xx3_avalanche(result)
  end

  def self.finalize_long_64b(acc : Array(UInt64), secret_ptr : Pointer(UInt8), len : UInt64) : UInt64
    merge_accs(acc, secret_ptr + 11, len &* 0x9E3779B185EBCA87_u64)
  end

  # Phase 3 (240+ bytes): Long input path for 128-bit hashing
  def self.finalize_long_128b(acc : Array(UInt64), secret_ptr : Pointer(UInt8), secret_size : Int32, len : UInt64) : Hash128
    low64 = finalize_long_64b(acc, secret_ptr, len)
    # For high64, we need to compute mergeAccs with a different starting value
    # Per vendor: h128.high64 = XXH3_mergeAccs(acc, secret + secretSize - XXH_STRIPE_LEN - XXH_SECRET_MERGEACCS_START, ~(len * XXH_PRIME64_2))
    # XXH_STRIPE_LEN = 64, XXH_SECRET_MERGEACCS_START = 11, XXH_PRIME64_2 = 0xC2B2AE3D27D4EB4F_u64
    # So: secret + secretSize - 64 - 11 = secret + secretSize - 75
    high64 = merge_accs(acc, secret_ptr + (secret_size - 64 - 11), ~(len &* XXH::Constants::PRIME64_2))
    Hash128.new(low64, high64)
  end

  def self.hash_long_128b(ptr : Pointer(UInt8), len : Int32, secret_ptr : Pointer(UInt8), secret_size : Int32) : Hash128
    acc = Array(UInt64).new(8) do |i|
      INIT_ACC[i]
    end
    hash_long_internal_loop(acc, ptr, len, secret_ptr, secret_size)
    finalize_long_128b(acc, secret_ptr, secret_size, len.to_u64)
  end

  def self.hash_long_128b_with_seed(ptr : Pointer(UInt8), len : Int32, seed : UInt64, default_secret_ptr : Pointer(UInt8), secret_size : Int32) : Hash128
    if seed == 0_u64
      return hash_long_128b(ptr, len, default_secret_ptr, secret_size)
    end
    # When seeded, build custom secret
    secret = Bytes.new(XXH::Constants::SECRET_DEFAULT_SIZE, 0)
    nrounds = XXH::Constants::SECRET_DEFAULT_SIZE.tdiv(16)
    (0...nrounds).each do |i|
      lo = XXH::Primitives.read_u64_le(default_secret_ptr + (16 * i)) &+ seed
      hi = ((XXH::Primitives.read_u64_le(default_secret_ptr + (16 * i + 8)).to_u128 &- seed.to_u128) & ((1_u128 << 64) - 1)).to_u64
      XXH::Primitives.write_u64_le(secret.to_unsafe + (16 * i), lo)
      XXH::Primitives.write_u64_le(secret.to_unsafe + (16 * i + 8), hi)
    end
    acc = Array(UInt64).new(8) do |i|
      INIT_ACC[i]
    end
    hash_long_internal_loop(acc, ptr, len, secret.to_unsafe, secret_size)
    finalize_long_128b(acc, secret.to_unsafe, secret_size, len.to_u64)
  end

  # Streaming state wrapper (native)
  class State
    @acc : Array(UInt64)
    @custom_secret : Bytes
    @buffer : Bytes
    @buffered_size : Int32
    @use_seed : Bool
    @nb_stripes_so_far : Int32
    @total_len : UInt64
    @nb_stripes_per_block : Int32
    @secret_limit : Int32
    @seed : UInt64
    @ext_secret : Bytes?

    XXH3_INTERNALBUFFER_SIZE = 256

    def initialize(seed : UInt64? = nil)
      @acc = Array(UInt64).new(8) { 0_u64 }
      @custom_secret = Bytes.new(XXH::Constants::SECRET_DEFAULT_SIZE, 0)
      @buffer = Bytes.new(XXH3_INTERNALBUFFER_SIZE, 0)
      @buffered_size = 0
      @use_seed = false
      @nb_stripes_so_far = 0
      @total_len = 0_u64
      @nb_stripes_per_block = 0
      @secret_limit = 0
      @seed = 0_u64
      @ext_secret = nil

      if seed.nil?
        reset
      else
        reset(seed)
      end
    end

    def reset(seed : UInt64? = nil)
      s = seed || 0_u64
      init_reset_internal(s, XXH::Buffers.default_secret, XXH::Buffers.default_secret.size)
    end

    def init_reset_internal(seed : UInt64, secret_bytes : Bytes, secret_size : Int32)
      # initialize acc and state per XXH3_reset_internal
      @acc[0] = 0xC2B2AE3D_u64
      @acc[1] = 0x9E3779B185EBCA87_u64
      @acc[2] = 0xC2B2AE3D27D4EB4F_u64
      @acc[3] = 0x165667B19E3779F9_u64
      @acc[4] = 0x85EBCA77C2B2AE63_u64
      @acc[5] = 0x85EBCA77_u64
      @acc[6] = 0x27D4EB2F165667C5_u64
      @acc[7] = 0x9E3779B1_u64

      if seed != 0_u64
        @seed = seed
        @use_seed = true
        # init custom secret
        nrounds = XXH::Constants::SECRET_DEFAULT_SIZE / 16
        (0...nrounds).each do |i|
          lo = XXH::Primitives.read_u64_le(secret_bytes.to_unsafe + (16 * i)) &+ seed
          hi = ((XXH::Primitives.read_u64_le(secret_bytes.to_unsafe + (16 * i + 8)).to_u128 &- seed.to_u128) & ((1_u128 << 64) - 1)).to_u64
          XXH::Primitives.write_u64_le(@custom_secret.to_unsafe + (16 * i), lo)
          XXH::Primitives.write_u64_le(@custom_secret.to_unsafe + (16 * i + 8), hi)
        end
        # Per C implementation, when seeded we keep customSecret but set extSecret to NULL
        @ext_secret = nil
      else
        @seed = 0_u64
        @use_seed = false
        # default secret is provided directly via extSecret
        @ext_secret = secret_bytes
      end

      @buffered_size = 0
      @nb_stripes_so_far = 0
      @total_len = 0_u64
      @secret_limit = secret_size - 64
      @nb_stripes_per_block = @secret_limit.tdiv(8)

      self
    end

    def update(input : Bytes)
      b = input
      len = b.size
      return if len == 0
      @total_len = @total_len &+ len.to_u64

      if len <= XXH3_INTERNALBUFFER_SIZE - @buffered_size
        # just append to buffer
        b.copy_to(@buffer.to_unsafe + @buffered_size, len)
        @buffered_size += len
        return
      end

      secret_bytes = (@ext_secret.nil? ? @custom_secret : @ext_secret).as(Bytes)

      offset = 0
      if @buffered_size > 0
        load_size = XXH3_INTERNALBUFFER_SIZE - @buffered_size
        b[offset, load_size].copy_to(@buffer.to_unsafe + @buffered_size, load_size)
        offset += load_size
        # consume all stripes from buffer
        nb_stripes = XXH3_INTERNALBUFFER_SIZE.tdiv(64)
        @nb_stripes_so_far = consume_stripes(@acc, @nb_stripes_so_far, @nb_stripes_per_block, @buffer.to_unsafe, nb_stripes, secret_bytes.to_unsafe, @secret_limit)
        @buffered_size = 0
      end

      # process large chunks from remaining input
      remaining = len - offset
      if remaining > XXH3_INTERNALBUFFER_SIZE
        nbStripes = (remaining - 1).tdiv(64)
        @nb_stripes_so_far = consume_stripes(@acc, @nb_stripes_so_far, @nb_stripes_per_block, b.to_unsafe + offset, nbStripes, secret_bytes.to_unsafe, @secret_limit)
        # copy last 64 bytes into the end of buffer
        src = offset + (nbStripes * 64)
        b[src, 64].copy_to(@buffer.to_unsafe + (XXH3_INTERNALBUFFER_SIZE - 64), 64)
        offset += nbStripes * 64
      end

      # copy remaining into buffer
      rem = len - offset
      b[offset, rem].copy_to(@buffer.to_unsafe, rem)
      @buffered_size = rem
    end

    def consume_stripes(acc, nb_stripes_so_far, nbStripesPerBlock, input_ptr, nbStripes, secret_ptr, secretLimit)
      initial_secret_offset = nb_stripes_so_far * 8
      if nbStripes >= (nbStripesPerBlock - nb_stripes_so_far)
        nbStripesThisIter = nbStripesPerBlock - nb_stripes_so_far
        while true
          XXH::XXH3.accumulate_scalar(acc, input_ptr, secret_ptr + initial_secret_offset, nbStripesThisIter)
          XXH::XXH3.scramble_acc_scalar(acc, secret_ptr + secretLimit)
          input_ptr += (nbStripesThisIter * 64)
          nbStripes -= nbStripesThisIter
          nbStripesThisIter = nbStripesPerBlock
          initial_secret_offset = 0
          break unless nbStripes >= nbStripesPerBlock
        end
        nb_stripes_so_far = 0
      end
      if nbStripes > 0
        XXH::XXH3.accumulate_scalar(acc, input_ptr, secret_ptr + initial_secret_offset, nbStripes)
        input_ptr += (nbStripes * 64)
        nb_stripes_so_far = nb_stripes_so_far + nbStripes
      end
      nb_stripes_so_far
    end

    def digest : UInt64
      secret_bytes = (@ext_secret.nil? ? @custom_secret : @ext_secret).as(Bytes)
      if @total_len > 240_u64
        acc_copy = @acc.dup
        if @buffered_size >= 64
          nbStripes = (@buffered_size - 1).tdiv(64)
          nb = @nb_stripes_so_far
          consume_stripes(acc_copy, nb, @nb_stripes_per_block, @buffer.to_unsafe, nbStripes, secret_bytes.to_unsafe, @secret_limit)
          lastStripePtr = @buffer.to_unsafe + (@buffered_size - 64)
          XXH::XXH3.accumulate_512_scalar(acc_copy, lastStripePtr, secret_bytes.to_unsafe + (@secret_limit - 7))
        else
          # Process the buffered data (less than 64 bytes remaining)
          # Per C implementation, we need to assemble a 64-byte stripe from:
          # 1. The last (64 - buffered_size) bytes from the end of the internal buffer
          # 2. The buffered bytes at the start
          catchup_size = 64 - @buffered_size
          lastStripe = Bytes.new(64)
          # Copy catchup bytes from end of buffer (bytes not yet consumed)
          buffer_end = XXH3_INTERNALBUFFER_SIZE - catchup_size
          (@buffer.to_unsafe + buffer_end).copy_to(lastStripe.to_unsafe, catchup_size)
          # Copy buffered bytes at start
          @buffer.to_unsafe.copy_to(lastStripe.to_unsafe + catchup_size, @buffered_size)
          lastStripePtr = lastStripe.to_unsafe
          XXH::XXH3.accumulate_512_scalar(acc_copy, lastStripePtr, secret_bytes.to_unsafe + (@secret_limit - 7))
        end
        return XXH::XXH3.finalize_long_64b(acc_copy, secret_bytes.to_unsafe, @total_len)
      end
      if @use_seed
        return XXH::XXH3.hash_with_seed(@buffer[0, @buffered_size], @seed)
      end

      # Use native short-paths for unseeded streaming inputs (avoid FFI fallback)
      len = @buffered_size
      ptr = @buffer.to_unsafe
      secret_ptr = secret_bytes.to_unsafe
      if len == 0
        return XXH::XXH3.hash(Bytes.new(0))
      elsif len <= 16
        return XXH::XXH3.len_0to16_64b(ptr, len, secret_ptr, 0_u64)
      elsif len <= 128
        return XXH::XXH3.len_17to128_64b(ptr, len, secret_ptr, 0_u64)
      else
        return XXH::XXH3.len_129to240_64b(ptr, len, secret_ptr, 0_u64)
      end
    end

    def debug_state
      buf_slice = @buffer[0, @buffered_size]
      end_slice = @buffer[XXH3_INTERNALBUFFER_SIZE - 64, 64] rescue Bytes.new(0)
      {total_len: @total_len, buffered_size: @buffered_size, nb_stripes_so_far: @nb_stripes_so_far, acc: @acc.dup, buffer: buf_slice.to_a, end_buffer: end_slice.to_a}
    end

    def free; end

    def finalize; end
  end

  # 128-bit Streaming state wrapper (native)
  class State128
    @acc : Array(UInt64)
    @custom_secret : Bytes
    @buffer : Bytes
    @buffered_size : Int32
    @use_seed : Bool
    @nb_stripes_so_far : Int32
    @total_len : UInt64
    @nb_stripes_per_block : Int32
    @secret_limit : Int32
    @seed : UInt64
    @ext_secret : Bytes?

    XXH3_INTERNALBUFFER_SIZE = 256

    def initialize(seed : UInt64? = nil)
      @acc = Array(UInt64).new(8) { 0_u64 }
      @custom_secret = Bytes.new(XXH::Constants::SECRET_DEFAULT_SIZE, 0)
      @buffer = Bytes.new(XXH3_INTERNALBUFFER_SIZE, 0)
      @buffered_size = 0
      @use_seed = false
      @nb_stripes_so_far = 0
      @total_len = 0_u64
      @nb_stripes_per_block = 0
      @secret_limit = 0
      @seed = 0_u64
      @ext_secret = nil

      if seed.nil?
        reset
      else
        reset(seed)
      end
    end

    def reset(seed : UInt64? = nil)
      s = seed || 0_u64
      init_reset_internal(s, XXH::Buffers.default_secret, XXH::Buffers.default_secret.size)
    end

    def init_reset_internal(seed : UInt64, secret_bytes : Bytes, secret_size : Int32)
      # Initialize acc and state per XXH3_reset_internal (same as 64-bit state)
      @acc[0] = 0xC2B2AE3D_u64
      @acc[1] = 0x9E3779B185EBCA87_u64
      @acc[2] = 0xC2B2AE3D27D4EB4F_u64
      @acc[3] = 0x165667B19E3779F9_u64
      @acc[4] = 0x85EBCA77C2B2AE63_u64
      @acc[5] = 0x85EBCA77_u64
      @acc[6] = 0x27D4EB2F165667C5_u64
      @acc[7] = 0x9E3779B1_u64

      if seed != 0_u64
        @seed = seed
        @use_seed = true
        # init custom secret
        nrounds = XXH::Constants::SECRET_DEFAULT_SIZE / 16
        (0...nrounds).each do |i|
          lo = XXH::Primitives.read_u64_le(secret_bytes.to_unsafe + (16 * i)) &+ seed
          hi = ((XXH::Primitives.read_u64_le(secret_bytes.to_unsafe + (16 * i + 8)).to_u128 &- seed.to_u128) & ((1_u128 << 64) - 1)).to_u64
          XXH::Primitives.write_u64_le(@custom_secret.to_unsafe + (16 * i), lo)
          XXH::Primitives.write_u64_le(@custom_secret.to_unsafe + (16 * i + 8), hi)
        end
        @ext_secret = nil
      else
        @seed = 0_u64
        @use_seed = false
        @ext_secret = secret_bytes
      end

      @buffered_size = 0
      @nb_stripes_so_far = 0
      @total_len = 0_u64
      @secret_limit = secret_size - 64
      @nb_stripes_per_block = @secret_limit.tdiv(8)

      self
    end

    def update(input : Bytes)
      b = input
      len = b.size
      return if len == 0
      @total_len = @total_len &+ len.to_u64

      if len <= XXH3_INTERNALBUFFER_SIZE - @buffered_size
        # just append to buffer
        b.copy_to(@buffer.to_unsafe + @buffered_size, len)
        @buffered_size += len
        return
      end

      secret_bytes = (@ext_secret.nil? ? @custom_secret : @ext_secret).as(Bytes)

      offset = 0
      if @buffered_size > 0
        load_size = XXH3_INTERNALBUFFER_SIZE - @buffered_size
        b[offset, load_size].copy_to(@buffer.to_unsafe + @buffered_size, load_size)
        offset += load_size
        nb_stripes = XXH3_INTERNALBUFFER_SIZE.tdiv(64)
        @nb_stripes_so_far = consume_stripes(@acc, @nb_stripes_so_far, @nb_stripes_per_block, @buffer.to_unsafe, nb_stripes, secret_bytes.to_unsafe, @secret_limit)
        @buffered_size = 0
      end

      remaining = len - offset
      if remaining > XXH3_INTERNALBUFFER_SIZE
        nbStripes = (remaining - 1).tdiv(64)
        @nb_stripes_so_far = consume_stripes(@acc, @nb_stripes_so_far, @nb_stripes_per_block, b.to_unsafe + offset, nbStripes, secret_bytes.to_unsafe, @secret_limit)
        src = offset + (nbStripes * 64)
        b[src, 64].copy_to(@buffer.to_unsafe + (XXH3_INTERNALBUFFER_SIZE - 64), 64)
        offset += nbStripes * 64
      end

      rem = len - offset
      b[offset, rem].copy_to(@buffer.to_unsafe, rem)
      @buffered_size = rem
    end

    def consume_stripes(acc, nb_stripes_so_far, nbStripesPerBlock, input_ptr, nbStripes, secret_ptr, secretLimit)
      initial_secret_offset = nb_stripes_so_far * 8
      if nbStripes >= (nbStripesPerBlock - nb_stripes_so_far)
        nbStripesThisIter = nbStripesPerBlock - nb_stripes_so_far
        while true
          XXH::XXH3.accumulate_scalar(acc, input_ptr, secret_ptr + initial_secret_offset, nbStripesThisIter)
          XXH::XXH3.scramble_acc_scalar(acc, secret_ptr + secretLimit)
          input_ptr += (nbStripesThisIter * 64)
          nbStripes -= nbStripesThisIter
          nbStripesThisIter = nbStripesPerBlock
          initial_secret_offset = 0
          break unless nbStripes >= nbStripesPerBlock
        end
        nb_stripes_so_far = 0
      end
      if nbStripes > 0
        XXH::XXH3.accumulate_scalar(acc, input_ptr, secret_ptr + initial_secret_offset, nbStripes)
        input_ptr += (nbStripes * 64)
        nb_stripes_so_far = nb_stripes_so_far + nbStripes
      end
      nb_stripes_so_far
    end

    def digest : Hash128
      secret_bytes = (@ext_secret.nil? ? @custom_secret : @ext_secret).as(Bytes)
      if @total_len > 240_u64
        acc_copy = @acc.dup
        if @buffered_size >= 64
          nbStripes = (@buffered_size - 1).tdiv(64)
          nb = @nb_stripes_so_far
          consume_stripes(acc_copy, nb, @nb_stripes_per_block, @buffer.to_unsafe, nbStripes, secret_bytes.to_unsafe, @secret_limit)
          lastStripePtr = @buffer.to_unsafe + (@buffered_size - 64)
          XXH::XXH3.accumulate_512_scalar(acc_copy, lastStripePtr, secret_bytes.to_unsafe + (@secret_limit - 7))
        else
          catchup_size = 64 - @buffered_size
          lastStripe = Bytes.new(64)
          buffer_end = XXH3_INTERNALBUFFER_SIZE - catchup_size
          (@buffer.to_unsafe + buffer_end).copy_to(lastStripe.to_unsafe, catchup_size)
          @buffer.to_unsafe.copy_to(lastStripe.to_unsafe + catchup_size, @buffered_size)
          lastStripePtr = lastStripe.to_unsafe
          XXH::XXH3.accumulate_512_scalar(acc_copy, lastStripePtr, secret_bytes.to_unsafe + (@secret_limit - 7))
        end
        return XXH::XXH3.finalize_long_128b(acc_copy, secret_bytes.to_unsafe, @secret_limit + 64, @total_len.to_u64)
      end
      if @use_seed
        return XXH::XXH3.hash128_with_seed(@buffer[0, @buffered_size], @seed)
      end

      # Use native short-paths for unseeded streaming inputs (avoid FFI fallback)
      len = @buffered_size
      ptr = @buffer.to_unsafe
      secret_ptr = secret_bytes.to_unsafe
      if len == 0
        return XXH::XXH3.hash128(Bytes.new(0))
      elsif len <= 16
        return XXH::XXH3.len_0to16_128b(ptr, len, secret_ptr, 0_u64)
      elsif len <= 128
        return XXH::XXH3.len_17to128_128b(ptr, len, secret_ptr, 0_u64)
      else
        return XXH::XXH3.len_129to240_128b(ptr, len, secret_ptr, 0_u64)
      end
    end

    def debug_state
      buf_slice = @buffer[0, @buffered_size]
      end_slice = @buffer[XXH3_INTERNALBUFFER_SIZE - 64, 64] rescue Bytes.new(0)
      {total_len: @total_len, buffered_size: @buffered_size, nb_stripes_so_far: @nb_stripes_so_far, acc: @acc.dup, buffer: buf_slice.to_a, end_buffer: end_slice.to_a}
    end

    def free; end

    def finalize; end
  end

  def self.new_state(seed : UInt64? = nil)
    State.new(seed)
  end

  def self.new_state128(seed : UInt64? = nil)
    State128.new(seed)
  end
end
