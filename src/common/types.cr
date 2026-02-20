module XXH
  # 128-bit helpers — use native `UInt128` for 128-bit hash values.
  # Provides `low64`/`high64` accessors and canonical serialization helpers.
  struct ::UInt128
    # Return the lower 64 bits as UInt64
    def low64 : UInt64
      (self & 0xFFFFFFFFFFFFFFFF_u128).to_u64
    end

    # Return the upper 64 bits as UInt64
    def high64 : UInt64
      (self >> 64).to_u64
    end

    # Big-endian bytes (high64 first, then low64)
    def to_bytes : Bytes
      bytes = Bytes.new(16)
      write_to_bytes(bytes)
      bytes
    end

    # Write big-endian bytes into the provided destination buffer (16 bytes)
    def write_to_bytes(dst : Bytes) : Nil
      raise ArgumentError.new("Destination buffer too small") if dst.size < 16
      IO::ByteFormat::BigEndian.encode(high64, dst[0, 8])
      IO::ByteFormat::BigEndian.encode(low64, dst[8, 8])
    end

    # Optimized 32-hex-digit canonical representation (zero-padded)
    # Avoids multiple intermediate string allocations.
    def to_hex32 : String
      String.new(32) do |buffer|
        (0..15).each do |i|
          # High 64
          nibble = ((high64 >> (4 * (15 - i))) & 0xF).to_u8
          buffer[i] = (nibble < 10) ? (48_u8 + nibble) : (87_u8 + nibble)
        end
        (0..15).each do |i|
          # Low 64
          nibble = ((low64 >> (4 * (15 - i))) & 0xF).to_u8
          buffer[16 + i] = (nibble < 10) ? (48_u8 + nibble) : (87_u8 + nibble)
        end
        {32, 32}
      end
    end

    # Inspect for debugging (keeps the representation explicit)
    def inspect(io : IO) : Nil
      io << "UInt128(0x"
      io << to_hex32
      io << ")"
    end

    # Construct from high/low halves
    @[AlwaysInline]
    def self.from_halves(high : UInt64, low : UInt64) : UInt128
      (high.to_u128 << 64) | low.to_u128
    end

    # Construct from FFI C struct (LibXXH::XXH128_hash_t)
    @[AlwaysInline]
    def self.from_c_hash(c_hash : LibXXH::XXH128_hash_t) : UInt128
      (c_hash.high64.to_u128 << 64) | c_hash.low64.to_u128
    end

    @[AlwaysInline]
    def self.from_c_hash(c_hash : LibXXH::XXH3_128_hash_t) : UInt128
      (c_hash.high.to_u128 << 64) | c_hash.low.to_u128
    end

    # Produce an FFI C struct from a native UInt128
    @[AlwaysInline]
    def to_c_hash : LibXXH::XXH128_hash_t
      LibXXH::XXH128_hash_t.new(low64: low64, high64: high64)
    end
  end

  # Seed type aliases for clarity
  alias Seed32 = UInt32
  alias Seed64 = UInt64

  # Secret type for XXH3 custom secret
  alias Secret = Bytes
end
