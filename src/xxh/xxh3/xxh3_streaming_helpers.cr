module XXH::XXH3
  # Simplified streaming state base — this implementation buffers all updates
  # and uses the vendored LibXXH (FFI) for finalization. The original native
  # accumulation helpers were removed as we rely on the canonical C library.
  #
  # The public streaming API (update/reset/digest) and debug helpers are
  # preserved so higher-level code and tests continue to work.

  class StreamingStateBase
    @data_all : Bytes
    @custom_secret : Bytes
    @buffer : Bytes
    @buffered_size : Int32
    @use_seed : Bool
    @total_len : UInt64
    @seed : UInt64
    @ext_secret : Bytes?

    CONST_INTERNALBUFFER_SIZE = 256

    def initialize(seed : UInt64? = nil)
      @data_all = Bytes.new(0)
      @custom_secret = Bytes.new(XXH::Constants::SECRET_DEFAULT_SIZE, 0)
      @buffer = Bytes.new(CONST_INTERNALBUFFER_SIZE, 0)
      @buffered_size = 0
      @use_seed = false
      @total_len = 0_u64
      @seed = 0_u64
      @ext_secret = nil

      if seed.nil?
        reset
      else
        reset(seed)
      end
    end

    def reset(seed : UInt64? = nil)
      s = seed || 0_u64
      @data_all = Bytes.new(0)
      @buffered_size = 0
      @total_len = 0_u64
      @seed = s
      @use_seed = (s != 0_u64)

      if @use_seed
        # initialize custom secret when seeded
        XXH::XXH3.init_custom_secret(@custom_secret.to_unsafe, XXH::Buffers.default_secret.to_unsafe, XXH::Buffers.default_secret.size, s)
        @ext_secret = nil
      else
        @custom_secret = Bytes.new(XXH::Constants::SECRET_DEFAULT_SIZE, 0)
        @ext_secret = XXH::Buffers.default_secret
      end

      self
    end

    def update(input : Bytes)
      len = input.size
      return if len == 0

      # append to accumulated buffer
      new_size = @data_all.size + len
      new_buf = Bytes.new(new_size)
      @data_all.copy_to(new_buf.to_unsafe, @data_all.size) if @data_all.size > 0
      input.copy_to(new_buf.to_unsafe + @data_all.size, len)
      @data_all = new_buf

      # keep last CONST_INTERNALBUFFER_SIZE bytes in @buffer for debug compatibility
      tail = [new_size, CONST_INTERNALBUFFER_SIZE].min
      start = new_size - tail
      @data_all[start, tail].copy_to(@buffer.to_unsafe, tail)
      @buffered_size = tail

      @total_len = @total_len &+ len.to_u64
      nil
    end

    # The old internal accumulation helpers are removed. Subclasses should call
    # LibXXH in `digest` to compute the final value from `@data_all`.

    def debug_state
      buf_slice = @buffer[0, @buffered_size]
      end_slice = @buffer[CONST_INTERNALBUFFER_SIZE - 64, 64] rescue Bytes.new(0)
      {total_len: @total_len, buffered_size: @buffered_size, acc: [] of UInt64, buffer: buf_slice.to_a, end_buffer: end_slice.to_a, use_seed: @use_seed}
    end

    def test_debug_secret
      custom = @custom_secret.to_a
      ext = @ext_secret.nil? ? nil : @ext_secret.as(Bytes).to_a
      {use_seed: @use_seed, custom_secret: custom, ext_secret: ext}
    end

    def free; end

    def finalize; end

    protected def secret_buffer
      (@ext_secret.nil? ? @custom_secret : @ext_secret).as(Bytes)
    end

    protected def acc_buffer
      # kept for compatibility but not used by new implementation
      uninitialized UInt64[8]
    end

    protected def internal_buffer
      @buffer
    end

    protected def buffered_size
      @buffered_size
    end

    protected def secret_limit
      (@ext_secret.nil? ? @custom_secret.size : @ext_secret.size) - 64
    end

    protected def total_len
      @total_len
    end
  end
end
