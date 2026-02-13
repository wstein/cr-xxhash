require "../xxh/primitives"
require "../xxh/common"

module XXH::XXH32
  # Pure-Crystal XXH32 implementation (translated from vendored C)

  # Implementation removed — streaming is delegated to LibXXH (FFI)
  # Round/stripe helpers were removed after migrating State to FFI.

  # merge_accs removed — use LibXXH internal implementation via FFI.

  # avalanche removed — use LibXXH's behavior via FFI.

  # init_accs removed — not needed with FFI-backed State.

  # consume_long removed — native implementation is used via FFI.

  # finalize_hash removed — native finalize is used via FFI.

  # One-shot hashing (C-backed via LibXXH)
  def self.hash(input : Bytes, seed : UInt32 = 0_u32) : UInt32
    LibXXH.XXH32(input.to_unsafe, input.size, seed)
  end

  # Streaming state wrapper — FFI-backed (delegates to LibXXH)
  class State
    @ffi_state : LibXXH::XXH32_state_t*

    def initialize(seed : UInt32 = 0_u32)
      @ffi_state = LibXXH.XXH32_createState
      reset(seed)
    end

    def reset(seed : UInt32 = 0_u32)
      @seed = seed
      LibXXH.XXH32_reset(@ffi_state, seed)
      self
    end

    def update(input : Bytes)
      return if input.size == 0
      LibXXH.XXH32_update(@ffi_state, input.to_unsafe, input.size)
      nil
    end

    def digest : UInt32
      LibXXH.XXH32_digest(@ffi_state)
    end

    def copy_from(other : State)
      LibXXH.XXH32_copyState(@ffi_state, other.instance_variable_get(@ffi_state))
      nil
    end

    def free
      LibXXH.XXH32_freeState(@ffi_state)
    end

    def finalize
      free
    end
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
