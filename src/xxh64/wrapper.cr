require "../vendor/bindings"

module XXH::XXH64
  # XXH64 — FFI-backed wrapper (streaming and one-shot delegate to LibXXH)
  # Native implementations are used via LibXXH; Crystal helpers were removed.

  # init_accs removed — not needed with FFI-backed State.

  # consume_long removed — native implementation is used via FFI.

  # merge_accs removed — use LibXXH via FFI.

  # finalize_hash removed — use LibXXH (FFI) finalize when streaming.

  # One-shot hashing (C-backed via LibXXH)
  def self.hash(input : Bytes, seed : UInt64 = 0_u64) : UInt64
    LibXXH.XXH64(input.to_unsafe, input.size, seed)
  end

  # Streaming state wrapper — FFI-backed (delegates to LibXXH)
  class State
    @ffi_state : LibXXH::XXH64_state_t*
    @seed : UInt64

    def initialize(seed : UInt64 = 0_u64)
      @ffi_state = LibXXH.XXH64_createState
      @seed = seed
      reset(seed)
    end

    def reset(seed : UInt64 = 0_u64)
      @seed = seed
      LibXXH.XXH64_reset(@ffi_state, seed)
      self
    end

    def update(input : Bytes)
      return if input.size == 0
      LibXXH.XXH64_update(@ffi_state, input.to_unsafe, input.size)
      nil
    end

    def digest : UInt64
      LibXXH.XXH64_digest(@ffi_state)
    end

    def copy_from(other : State)
      LibXXH.XXH64_copyState(@ffi_state, other.@ffi_state)
      nil
    end

    def free
      LibXXH.XXH64_freeState(@ffi_state)
    end

    def finalize
      free
    end
  end

  def self.new_state(seed : UInt64 = 0_u64)
    State.new(seed)
  end

  # Compatibility wrappers mirroring LibXXH streaming API
  # Create a new streaming state (equivalent to LibXXH.XXH64_createState)
  def self.create_state(seed : UInt64 = 0_u64) : State
    State.new(seed)
  end

  # C-style API aliases (for compatibility with existing code)
  def self.xxh64_create_state(seed : UInt64 = 0_u64) : State
    create_state(seed)
  end

  # Reset an existing state (equivalent to LibXXH.XXH64_reset)
  # Returns 0 on success to match C's XXH_errorcode semantics
  def self.reset_state(state : State, seed : UInt64 = 0_u64) : Int32
    state.reset(seed)
    0
  end

  def self.xxh64_reset(state : State, seed : UInt64 = 0_u64) : Int32
    reset_state(state, seed)
  end

  # Update a state with input (equivalent to LibXXH.XXH64_update)
  def self.update_state(state : State, input : Bytes) : Int32
    state.update(input)
    0
  end

  # Pointer-based update (mirrors C signature: void* input, size_t len)
  def self.xxh64_update(state : State, input_ptr : Pointer(Void), len : Int) : Int32
    return 0 if input_ptr.null? && len == 0
    ptr8 = input_ptr.as(Pointer(UInt8))
    slice = Slice.new(ptr8, len)
    state.update(slice)
    0
  end

  # Finalize/digest a state (equivalent to LibXXH.XXH64_digest)
  def self.digest_state(state : State) : UInt64
    state.digest
  end

  def self.xxh64_digest(state : State) : UInt64
    digest_state(state)
  end

  # Free state (no-op for pure Crystal implementation) — return 0 for success
  def self.xxh64_free_state(state : State) : Int32
    # Optionally clear state
    state.reset(0_u64)
    0
  end

  # Copy state (mirror C XXH64_copyState(dst, src))
  def self.xxh64_copy_state(dst : State, src : State)
    dst.copy_from(src)
    nil
  end

  # Canonical representation conversions (big-endian storage)
  # Writes 8 bytes (big-endian) into dst
  def self.xxh64_canonical_from_hash(dst : Bytes, hash : UInt64)
    # Ensure dst has at least 8 bytes
    (0...8).each do |i|
      dst[i] = ((hash >> ((7 - i) * 8)) & 0xFF_u64).to_u8
    end
    nil
  end

  def self.xxh64_hash_from_canonical(src : Bytes) : UInt64
    ((0...8).map { |i| src[i].to_u64 << ((7 - i) * 8) }).reduce(0_u64) { |acc, x| acc | x }
  end
end
