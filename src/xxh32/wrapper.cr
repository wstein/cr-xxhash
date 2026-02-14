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
end
