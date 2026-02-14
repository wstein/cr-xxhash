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

  # Delegates to vendored C implementation via FFI.
  # This replaces the hand-crafted Crystal version for consistency with vendor.
  def self.init_custom_secret(dest_ptr : Pointer(UInt8), secret_ptr : Pointer(UInt8), secret_size : Int32, seed : UInt64) : Nil
    dest_ptr.copy_from(secret_ptr, secret_size)
    LibXXH.XXH3_generateSecret_fromSeed(dest_ptr, seed)
  end

  # Streaming state factory helpers
  def self.new_state(seed : UInt64? = nil)
    State.new(seed || 0_u64)
  end

  def self.new_state128(seed : UInt64? = nil)
    State128.new(seed || 0_u64)
  end
end
