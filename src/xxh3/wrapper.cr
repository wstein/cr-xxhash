# XXH3 public API — delegate one-shot and seeded calls to the vendored C implementation (LibXXH).
# The pure-Crystal algorithmic implementation has been removed; streaming and one-shot
# APIs now use the vendored xxHash via FFI.

require "../vendor/bindings"
require "./types"
require "./state"

module XXH::XXH3
  # One-shot 64-bit (XXH3) - delegates to LibXXH
  def self.hash(input : Bytes) : UInt64
    LibXXH.XXH3_64bits(input.to_unsafe, input.size)
  end

  def self.hash_with_seed(input : Bytes, seed : UInt64) : UInt64
    LibXXH.XXH3_64bits_withSeed(input.to_unsafe, input.size, seed)
  end

  # One-shot 128-bit (XXH3) - delegates to LibXXH
  def self.hash128(input : Bytes) : Hash128
    c = LibXXH.XXH3_128bits(input.to_unsafe, input.size)
    Hash128.new(c.low64, c.high64)
  end

  def self.hash128_with_seed(input : Bytes, seed : UInt64) : Hash128
    c = LibXXH.XXH3_128bits_withSeed(input.to_unsafe, input.size, seed)
    Hash128.new(c.low64, c.high64)
  end

  def self.hash128_stream(input : Bytes) : Hash128
    stream_digest128(input, nil)
  end

  def self.hash128_stream_with_seed(input : Bytes, seed : UInt64) : Hash128
    stream_digest128(input, seed)
  end

  # Re-create the small helper used by tests to build a custom secret from seed.
  def self.init_custom_secret(dest_ptr : Pointer(UInt8), secret_ptr : Pointer(UInt8), secret_size : Int32, seed : UInt64) : Nil
    nrounds = (secret_size / 16).to_i
    i = 0
    while i < nrounds
      lo = XXH::Primitives.read_u64_le(secret_ptr + (16 * i)) &+ seed
      hi = ((XXH::Primitives.read_u64_le(secret_ptr + (16 * i + 8)).to_u128 &- seed.to_u128) & UInt64::MAX.to_u128).to_u64
      XXH::Primitives.write_u64_le(dest_ptr + (16 * i), lo)
      XXH::Primitives.write_u64_le(dest_ptr + (16 * i + 8), hi)
      i += 1
    end
  end

  # Streaming state factory helpers
  def self.new_state(seed : UInt64? = nil)
    State.new(seed)
  end

  def self.new_state128(seed : UInt64? = nil)
    State128.new(seed)
  end

  private def self.stream_digest128(input : Bytes, seed : UInt64?) : Hash128
    state = LibXXH.XXH3_createState
    begin
      if seed
        LibXXH.XXH3_128bits_reset_withSeed(state, seed)
      else
        LibXXH.XXH3_128bits_reset(state)
      end
      LibXXH.XXH3_128bits_update(state, input.to_unsafe, input.size)
      result = LibXXH.XXH3_128bits_digest(state)
      Hash128.new(result.low64, result.high64)
    ensure
      LibXXH.XXH3_freeState(state)
    end
  end
end
