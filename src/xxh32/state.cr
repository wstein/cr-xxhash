require "../vendor/bindings"

module XXH::XXH32
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
end
