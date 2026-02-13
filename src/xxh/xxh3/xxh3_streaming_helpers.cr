require "../streaming_state_base"

module XXH::XXH3
  # Streaming state base class for XXH3 variants — buffers all input and
  # finalizes via LibXXH. Inherits common lifecycle (update/reset/digest) from
  # XXH::StreamingStateBase and overrides algorithm-specifics.
  #
  # The original native accumulation helpers were removed as we rely on
  # the canonical C library (LibXXH) for finalization.

  class StreamingStateBase < XXH::StreamingStateBase
    @data_all : Bytes
    @custom_secret : Bytes
    @use_seed : Bool
    @seed : UInt64
    @ext_secret : Bytes?

    CONST_INTERNALBUFFER_SIZE = 256

    def buffer_size : Int32
      CONST_INTERNALBUFFER_SIZE
    end

    def init_state(seed : UInt64 | UInt32 | Nil) : Nil
      @data_all = Bytes.new(0)
      @custom_secret = Bytes.new(XXH::Constants::SECRET_DEFAULT_SIZE, 0)
      @total_len = 0_u64
      s = (seed || 0_u64).as(UInt64)
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

      nil
    end

    def update_total_len(input_size : Int) : Nil
      @total_len = @total_len.as(UInt64) &+ input_size.to_u64
      nil
    end

    def process_stripe(ptr : Pointer(UInt8), size : Int32) : Nil
      # XXH3 buffers all input; stripe processing is deferred until finalization.
      # This is a no-op for XXH3, which uses @data_all accumulation instead.
      nil
    end

    protected def update_slice(input : Slice(UInt8)) : Nil
      len = input.size
      return if len == 0

      # append to accumulated buffer (XXH3 buffers everything, doesn't process stripes)
      new_size = @data_all.size + len
      new_buf = Bytes.new(new_size)
      @data_all.copy_to(new_buf.to_unsafe, @data_all.size) if @data_all.size > 0
      input.copy_to(new_buf.to_unsafe + @data_all.size, len)
      @data_all = new_buf

      # keep last CONST_INTERNALBUFFER_SIZE bytes in @buffer for debug compatibility
      tail = [new_size, CONST_INTERNALBUFFER_SIZE].min
      start = new_size - tail
      @data_all[start, tail].copy_to(@buffer.to_unsafe, tail)
      @buffered = tail.to_u32

      @total_len = @total_len.as(UInt64) &+ len.to_u64
      nil
    end

    def debug_state
      buf_slice = @buffer[0, @buffered.to_i]
      end_slice = @buffer[CONST_INTERNALBUFFER_SIZE - 64, 64] rescue Bytes.new(0)
      {total_len: @total_len, buffered_size: @buffered, acc: [] of UInt64, buffer: buf_slice.to_a, end_buffer: end_slice.to_a, use_seed: @use_seed}
    end

    def test_debug_secret
      custom = @custom_secret.to_a
      ext = @ext_secret.nil? ? nil : @ext_secret.as(Bytes).to_a
      {use_seed: @use_seed, custom_secret: custom, ext_secret: ext}
    end

    protected def secret_buffer
      (@ext_secret.nil? ? @custom_secret : @ext_secret).as(Bytes)
    end

    def copy_state_details(other : StreamingStateBase) : Nil
      # No-op - copy_from handles all XXH3 state
      nil
    end

    def copy_from(other : StreamingStateBase) : Nil
      # Override to properly copy XXH3-specific fields
      if other.is_a?(StreamingStateBase)
        other_state = other.as(StreamingStateBase)
        @total_len = other_state.@total_len
        @buffered = other_state.@buffered
        @seed = other_state.@seed
        @data_all = other_state.@data_all.dup
        @custom_secret = other_state.@custom_secret.dup
        @use_seed = other_state.@use_seed
        @ext_secret = other_state.@ext_secret
        # Copy buffer bytes
        i = 0
        while i < @buffered.to_i
          @buffer[i] = other_state.@buffer[i]
          i += 1
        end
      end
      nil
    end
  end
end
