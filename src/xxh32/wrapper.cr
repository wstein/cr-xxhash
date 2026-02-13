require "../vendor/bindings"
require "./state"

module XXH::XXH32
  # XXH32 — FFI-backed wrapper (streaming and one-shot delegate to LibXXH)
  # Former Crystal helpers were removed during consolidation.

  # One-shot hashing (C-backed via LibXXH)
  def self.hash(input : Bytes, seed : UInt32 = 0_u32) : UInt32
    LibXXH.XXH32(input.to_unsafe, input.size, seed)
  end

  def self.new_state(seed : UInt32 = 0_u32)
    State.new(seed)
  end

  # C-style aliases
  def self.xxh32_create_state(seed : UInt32 = 0_u32) : State
    new_state(seed)
  end

  def self.xxh32_reset(state : State, seed : UInt32 = 0_u32) : Int32
    state.reset(seed)
    0
  end

  def self.xxh32_update(state : State, input_ptr : Pointer(Void), len : Int) : Int32
    return 0 if input_ptr.null? && len == 0
    ptr8 = input_ptr.as(Pointer(UInt8))
    slice = Slice.new(ptr8, len)
    state.update(slice)
    0
  end

  def self.xxh32_digest(state : State) : UInt32
    state.digest
  end

  def self.xxh32_free_state(state : State) : Int32
    state.reset(0_u32)
    0
  end

  def self.xxh32_copy_state(dst : State, src : State)
    dst.copy_from(src)
    nil
  end

  # Canonical conversions (big-endian)
  def self.xxh32_canonical_from_hash(dst : Bytes, hash : UInt32)
    (0...4).each do |i|
      dst[i] = ((hash >> ((3 - i) * 8)) & 0xFF_u32).to_u8
    end
    nil
  end

  def self.xxh32_hash_from_canonical(src : Bytes) : UInt32
    ((0...4).map { |i| src[i].to_u32 << ((3 - i) * 8) }).reduce(0_u32) { |acc, x| acc | x }
  end
end
