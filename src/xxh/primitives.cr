# Minimal primitives shim (native algorithm implementations removed)
# Retains a small set of helper functions required by the rest
# of the codebase (reading little-endian words, rotations, swaps).

module XXH::Primitives
  @[AlwaysInline]
  def self.rotl32(x : UInt32, r : UInt32) : UInt32
    (x << r) | (x >> (32_u32 - r))
  end

  @[AlwaysInline]
  def self.rotl64(x : UInt64, r : UInt32) : UInt64
    (x << r) | (x >> (64_u32 - r))
  end

  @[AlwaysInline]
  def self.read_u32_le(ptr : Pointer(UInt8)) : UInt32
    ptr[0].to_u32 |
      (ptr[1].to_u32 << 8) |
      (ptr[2].to_u32 << 16) |
      (ptr[3].to_u32 << 24)
  end

  @[AlwaysInline]
  def self.read_u64_le(ptr : Pointer(UInt8)) : UInt64
    ptr[0].to_u64 |
      (ptr[1].to_u64 << 8) |
      (ptr[2].to_u64 << 16) |
      (ptr[3].to_u64 << 24) |
      (ptr[4].to_u64 << 32) |
      (ptr[5].to_u64 << 40) |
      (ptr[6].to_u64 << 48) |
      (ptr[7].to_u64 << 56)
  end

  @[AlwaysInline]
  def self.read_u64_le_safe(ptr : Pointer(UInt8), len : Int32) : UInt64
    case len
    when 0
      0_u64
    when 1
      ptr[0].to_u64
    when 2
      (ptr[0].to_u64) | (ptr[1].to_u64 << 8)
    when 3
      (ptr[0].to_u64) | (ptr[1].to_u64 << 8) | (ptr[2].to_u64 << 16)
    when 4
      read_u32_le(ptr).to_u64 | (ptr[4].to_u64 << 32)
    when 5
      read_u32_le(ptr).to_u64 | (ptr[4].to_u64 << 32) | (ptr[5].to_u64 << 40)
    when 6
      read_u32_le(ptr).to_u64 | (ptr[4].to_u64 << 32) | (ptr[5].to_u64 << 40) | (ptr[6].to_u64 << 48)
    when 7
      read_u32_le(ptr).to_u64 | (ptr[4].to_u64 << 32) | (ptr[5].to_u64 << 40) | (ptr[6].to_u64 << 48) | (ptr[7].to_u64 << 56)
    else
      read_u64_le(ptr)
    end
  end

  @[AlwaysInline]
  def self.bswap32(x : UInt32) : UInt32
    ((x << 24) & 0xFF000000_u32) |
      ((x << 8) & 0xFF0000_u32) |
      ((x >> 8) & 0xFF00_u32) |
      ((x >> 24) & 0xFF_u32)
  end

  @[AlwaysInline]
  def self.bswap64(x : UInt64) : UInt64
    ((x << 56) & 0xFF00000000000000_u64) |
      ((x << 40) & 0xFF000000000000_u64) |
      ((x << 24) & 0xFF0000000000_u64) |
      ((x << 8) & 0xFF00000000_u64) |
      ((x >> 8) & 0xFF000000_u64) |
      ((x >> 24) & 0xFF0000_u64) |
      ((x >> 40) & 0xFF00_u64) |
      ((x >> 56) & 0xFF_u64)
  end

  @[AlwaysInline]
  def self.add32(a : UInt32, b : UInt32) : UInt32
    a &+ b
  end

  @[AlwaysInline]
  def self.add64(a : UInt64, b : UInt64) : UInt64
    a &+ b
  end

  @[AlwaysInline]
  def self.low32(x : UInt64) : UInt32
    x.to_u32
  end

  @[AlwaysInline]
  def self.high32(x : UInt64) : UInt32
    (x >> 32).to_u32
  end

  @[AlwaysInline]
  def self.combine64(low : UInt32, high : UInt32) : UInt64
    low.to_u64 | (high.to_u64 << 32)
  end
end
