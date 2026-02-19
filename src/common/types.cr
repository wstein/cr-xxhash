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
      IO::ByteFormat::BigEndian.encode(high64, bytes[0, 8])
      IO::ByteFormat::BigEndian.encode(low64, bytes[8, 8])
      bytes
    end

    # 32-hex-digit canonical representation (zero-padded)
    def to_hex32 : String
      high64.to_s(16).rjust(16, '0') + low64.to_s(16).rjust(16, '0')
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
