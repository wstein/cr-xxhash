require "../vendor/bindings"

module XXH::XXH3
  # Streaming state wrapper — FFI-backed (delegates to LibXXH)
  class State
    @ffi_state : LibXXH::XXH3_state_t*

    def initialize(seed : UInt64 = 0_u64)
      @ffi_state = LibXXH.XXH3_createState
      reset(seed)
    end

    def reset(seed : UInt64 = 0_u64)
      if seed != 0_u64
        LibXXH.XXH3_64bits_reset_withSeed(@ffi_state, seed)
        # Generate the custom secret from seed (same logic as C library)
        secret = Buffers.default_secret
        custom_secret = Bytes.new(secret.size)
        XXH::XXH3.init_custom_secret(custom_secret.to_unsafe, secret.to_unsafe, secret.size, seed)
      else
        LibXXH.XXH3_64bits_reset(@ffi_state)
      end
      self
    end

    def update(input : Bytes)
      return if input.size == 0
      LibXXH.XXH3_64bits_update(@ffi_state, input.to_unsafe, input.size)
      nil
    end

    def digest : UInt64
      LibXXH.XXH3_64bits_digest(@ffi_state)
    end

    def copy_from(other : State)
      LibXXH.XXH3_copyState(@ffi_state, other.@ffi_state)
      nil
    end

    def free
      LibXXH.XXH3_freeState(@ffi_state)
    end

    def finalize
      free
    end

  end

  # XXH3 128-bit Streaming State
  class State128
    @ffi_state : LibXXH::XXH3_state_t*

    def initialize(seed : UInt64 = 0_u64)
      @ffi_state = LibXXH.XXH3_createState
      reset(seed)
    end

    def reset(seed : UInt64 = 0_u64)
      if seed != 0_u64
        LibXXH.XXH3_128bits_reset_withSeed(@ffi_state, seed)
        # Generate the custom secret from seed (same logic as C library)
        secret = Buffers.default_secret
        custom_secret = Bytes.new(secret.size)
        XXH::XXH3.init_custom_secret(custom_secret.to_unsafe, secret.to_unsafe, secret.size, seed)
       else
        LibXXH.XXH3_128bits_reset(@ffi_state)
      end
      self
    end

    def update(input : Bytes)
      return if input.size == 0
      LibXXH.XXH3_128bits_update(@ffi_state, input.to_unsafe, input.size)
      nil
    end

    def digest : Hash128
      c = LibXXH.XXH3_128bits_digest(@ffi_state)
      Hash128.new(c.low64, c.high64)
    end

    def copy_from(other : State128)
      LibXXH.XXH3_copyState(@ffi_state, other.@ffi_state)
      nil
    end

    def free
      LibXXH.XXH3_freeState(@ffi_state)
    end

    def finalize
      free
    end
  end

  # Factory Methods
  def self.new_state(seed : UInt64? = nil)
    State.new(seed || 0_u64)
  end

  def self.new_state128(seed : UInt64? = nil)
    State128.new(seed || 0_u64)
  end
end
