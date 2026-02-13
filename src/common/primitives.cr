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
  def self.write_u64_le(ptr : Pointer(UInt8), v : UInt64)
    ptr[0] = (v & 0xFF).to_u8
    ptr[1] = ((v >> 8) & 0xFF).to_u8
    ptr[2] = ((v >> 16) & 0xFF).to_u8
    ptr[3] = ((v >> 24) & 0xFF).to_u8
    ptr[4] = ((v >> 32) & 0xFF).to_u8
    ptr[5] = ((v >> 40) & 0xFF).to_u8
    ptr[6] = ((v >> 48) & 0xFF).to_u8
    ptr[7] = ((v >> 56) & 0xFF).to_u8
  end
end
