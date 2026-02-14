require "../vendor/bindings"
require "./state"

module XXH::XXH64
  # XXH64 — FFI-backed wrapper (streaming and one-shot delegate to LibXXH)
  # Native implementations are used via LibXXH; Crystal helpers were removed.

  # One-shot hashing (C-backed via LibXXH)
  def self.hash(input : Bytes, seed : UInt64 = 0_u64) : UInt64
    LibXXH.XXH64(input.to_unsafe, input.size, seed)
  end

  def self.new_state(seed : UInt64 = 0_u64)
    State.new(seed)
  end
end
