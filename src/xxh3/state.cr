module XXH::XXH3
  # ============================================================================
  # XXH3 Streaming State (FFI-backed) — Base Class
  # ============================================================================
  # FFI-backed streaming state using vendored LibXXH for O(1) memory efficiency.
  # Avoids O(n²) buffer accumulation by using native FFI streaming API directly.

  class StreamingStateBase
    @ffi_state : LibXXH::XXH3_state_t*
    @buffer : Bytes
    @buffered_size : Int32
    @use_seed : Bool
    @seed : UInt64
    @custom_secret : Bytes
    @ext_secret : Bytes?

    CONST_INTERNALBUFFER_SIZE = 256

    def initialize(seed : UInt64? = nil)
      @ffi_state = LibXXH.XXH3_createState
      @buffer = Bytes.new(CONST_INTERNALBUFFER_SIZE, 0)
      @buffered_size = 0
      @use_seed = false
      @seed = 0_u64
      @custom_secret = Bytes.new(XXH::Constants::SECRET_DEFAULT_SIZE, 0)
      @ext_secret = nil

      if seed.nil?
        reset
      else
        reset(seed)
      end
    end

    def reset(seed : UInt64? = nil)
      s = seed || 0_u64
      @buffered_size = 0
      @seed = s
      @use_seed = (s != 0_u64)

      if @use_seed
        # Derive custom secret for debug interface and potential future use
        XXH::XXH3.init_custom_secret(@custom_secret.to_unsafe, XXH::Buffers.default_secret.to_unsafe, XXH::Buffers.default_secret.size, s)
        @ext_secret = nil
        # Use FFI reset with seed (custom secret is advisory only in FFI mode)
        LibXXH.XXH3_64bits_reset_withSeed(@ffi_state, s)
      else
        @custom_secret = Bytes.new(XXH::Constants::SECRET_DEFAULT_SIZE, 0)
        @ext_secret = XXH::Buffers.default_secret
        LibXXH.XXH3_64bits_reset(@ffi_state)
      end

      self
    end

    def update(input : Bytes)
      len = input.size
      return if len == 0

      # Feed directly to FFI streaming state — O(1) memory regardless of input size
      LibXXH.XXH3_64bits_update(@ffi_state, input.to_unsafe, len)

      # Keep last CONST_INTERNALBUFFER_SIZE bytes in @buffer for debug compatibility
      tail = [len, CONST_INTERNALBUFFER_SIZE].min
      start = len - tail
      input[start, tail].copy_to(@buffer.to_unsafe, tail)
      @buffered_size = tail

      nil
    end

    def debug_state
      buf_slice = @buffer[0, @buffered_size]
      end_slice = @buffer[CONST_INTERNALBUFFER_SIZE - 64, 64] rescue Bytes.new(0)
      {buffered_size: @buffered_size, acc: [] of UInt64, buffer: buf_slice.to_a, end_buffer: end_slice.to_a, use_seed: @use_seed}
    end

    def test_debug_secret
      custom = @custom_secret.to_a
      ext = @ext_secret.nil? ? nil : @ext_secret.as(Bytes).to_a
      {use_seed: @use_seed, custom_secret: custom, ext_secret: ext}
    end

    def free
      LibXXH.XXH3_freeState(@ffi_state)
    end

    def finalize
      free
    end

    protected def secret_buffer
      (@ext_secret.nil? ? @custom_secret : @ext_secret).as(Bytes)
    end
  end

  # ============================================================================
  # XXH3 64-bit Streaming State
  # ============================================================================
  class State < StreamingStateBase
    def digest : UInt64
      # Finalize FFI state and return hash
      LibXXH.XXH3_64bits_digest(@ffi_state)
    end
  end

  # ============================================================================
  # XXH3 128-bit Streaming State
  # ============================================================================
  class State128 < StreamingStateBase
    def digest : Hash128
      # Finalize FFI state and return 128-bit hash
      c = LibXXH.XXH3_128bits_digest(@ffi_state)
      Hash128.new(c.low64, c.high64)
    end
  end

  # ============================================================================
  # Factory Methods
  # ============================================================================
  def self.new_state(seed : UInt64? = nil)
    State.new(seed)
  end

  def self.new_state128(seed : UInt64? = nil)
    State128.new(seed)
  end
end
