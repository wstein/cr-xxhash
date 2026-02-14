module XXH
  # 128-bit hash result (idiomatic Crystal wrapper)
  # Bidirectional conversion with C struct XXH128_hash_t
  struct Hash128
    getter low64 : UInt64
    getter high64 : UInt64

    # Construct from two integers: `high64, low64` (matches canonical ordering)
    def initialize(@high64 : UInt64, @low64 : UInt64)
    end

    # Initialize from C struct
    def initialize(c_hash : LibXXH::XXH128_hash_t)
      @low64 = c_hash.low64
      @high64 = c_hash.high64
    end

    # String representation: uppercase hex (64 + 64 bits)
    def to_s(io : IO) : Nil
      io << high64.to_s(16).rjust(16, '0')
      io << low64.to_s(16).rjust(16, '0')
    end

    # Big-endian bytes (high64 first, then low64)
    def to_bytes : Bytes
      bytes = Bytes.new(16)
      IO::ByteFormat::BigEndian.encode(high64, bytes[0, 8])
      IO::ByteFormat::BigEndian.encode(low64, bytes[8, 8])
      bytes
    end

    # Equality comparison
    def ==(other : Hash128) : Bool
      low64 == other.low64 && high64 == other.high64
    end

    # Hash code for use in Hash collections
    def hash : UInt64
      low64 ^ high64
    end

    # Inspect for debugging
    def inspect(io : IO) : Nil
      io << "XXH::Hash128("
      io << high64.to_s(16).rjust(16, '0')
      io << low64.to_s(16).rjust(16, '0')
      io << ")"
    end
  end

  # Seed type aliases for clarity
  alias Seed32 = UInt32
  alias Seed64 = UInt64

  # Secret type for XXH3 custom secret
  alias Secret = Bytes
end
