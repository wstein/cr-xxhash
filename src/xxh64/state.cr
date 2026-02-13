require "../vendor/bindings"

module XXH::XXH64
  # Streaming state wrapper — FFI-backed (delegates to LibXXH)
  class State
    @ffi_state : LibXXH::XXH64_state_t*

    def initialize(seed : UInt64 = 0_u64)
      @ffi_state = LibXXH.XXH64_createState
      reset(seed)
    end

    def reset(seed : UInt64 = 0_u64)
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
end
