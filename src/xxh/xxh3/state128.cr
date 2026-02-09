module XXH::XXH3
  # 128-bit Streaming state wrapper (native)
  class State128
    @acc : StaticArray(UInt64, 8)
    @custom_secret : Bytes
    @buffer : Bytes
    @buffered_size : Int32
    @use_seed : Bool
    @nb_stripes_so_far : Int32
    @total_len : UInt64
    @nb_stripes_per_block : Int32
    @secret_limit : Int32
    @seed : UInt64
    @ext_secret : Bytes?

    XXH3_INTERNALBUFFER_SIZE = 256

    def initialize(seed : UInt64? = nil)
      @acc = uninitialized UInt64[8]
      @custom_secret = Bytes.new(XXH::Constants::SECRET_DEFAULT_SIZE, 0)
      @buffer = Bytes.new(XXH3_INTERNALBUFFER_SIZE, 0)
      @buffered_size = 0
      @use_seed = false
      @nb_stripes_so_far = 0
      @total_len = 0_u64
      @nb_stripes_per_block = 0
      @secret_limit = 0
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
      init_reset_internal(s, XXH::Buffers.default_secret, XXH::Buffers.default_secret.size)
    end

    def init_reset_internal(seed : UInt64, secret_bytes : Bytes, secret_size : Int32)
      # Initialize acc and state per XXH3_reset_internal (same as 64-bit state)
      XXH::XXH3.init_acc(@acc.to_unsafe)

      if seed != 0_u64
        @seed = seed
        @use_seed = true
        # init custom secret
        XXH::XXH3.init_custom_secret(@custom_secret.to_unsafe, secret_bytes.to_unsafe, secret_size, seed)
        @ext_secret = nil
      else
        @seed = 0_u64
        @use_seed = false
        @ext_secret = secret_bytes
      end

      @buffered_size = 0
      @nb_stripes_so_far = 0
      @total_len = 0_u64
      @secret_limit = secret_size - 64
      @nb_stripes_per_block = @secret_limit.tdiv(8)

      self
    end

    def update(input : Bytes)
      b = input
      len = b.size
      return if len == 0
      @total_len = @total_len &+ len.to_u64

      if len <= XXH3_INTERNALBUFFER_SIZE - @buffered_size
        # just append to buffer
        b.copy_to(@buffer.to_unsafe + @buffered_size, len)
        @buffered_size += len
        return
      end

      secret_bytes = (@ext_secret.nil? ? @custom_secret : @ext_secret).as(Bytes)

      offset = 0
      if @buffered_size > 0
        load_size = XXH3_INTERNALBUFFER_SIZE - @buffered_size
        b[offset, load_size].copy_to(@buffer.to_unsafe + @buffered_size, load_size)
        offset += load_size
        nb_stripes = XXH3_INTERNALBUFFER_SIZE.tdiv(64)
        @nb_stripes_so_far = consume_stripes(@acc.to_unsafe, @nb_stripes_so_far, @nb_stripes_per_block, @buffer.to_unsafe, nb_stripes, secret_bytes.to_unsafe, @secret_limit)
        @buffered_size = 0
      end

      remaining = len - offset
      if remaining > XXH3_INTERNALBUFFER_SIZE
        nbStripes = (remaining - 1).tdiv(64)
        @nb_stripes_so_far = consume_stripes(@acc.to_unsafe, @nb_stripes_so_far, @nb_stripes_per_block, b.to_unsafe + offset, nbStripes, secret_bytes.to_unsafe, @secret_limit)
        src = offset + (nbStripes * 64)
        b[src, 64].copy_to(@buffer.to_unsafe + (XXH3_INTERNALBUFFER_SIZE - 64), 64)
        offset += nbStripes * 64
      end

      rem = len - offset
      b[offset, rem].copy_to(@buffer.to_unsafe, rem)
      @buffered_size = rem
    end

    def consume_stripes(acc_ptr : Pointer(UInt64), nb_stripes_so_far, nbStripesPerBlock, input_ptr, nbStripes, secret_ptr, secretLimit)
      initial_secret_offset = nb_stripes_so_far * 8
      if nbStripes >= (nbStripesPerBlock - nb_stripes_so_far)
        nbStripesThisIter = nbStripesPerBlock - nb_stripes_so_far
        while true
          XXH::XXH3.accumulate_scalar(acc_ptr, input_ptr, secret_ptr + initial_secret_offset, nbStripesThisIter)
          XXH::XXH3.scramble_acc_scalar(acc_ptr, secret_ptr + secretLimit)
          input_ptr += (nbStripesThisIter * 64)
          nbStripes -= nbStripesThisIter
          nbStripesThisIter = nbStripesPerBlock
          initial_secret_offset = 0
          break unless nbStripes >= nbStripesPerBlock
        end
        nb_stripes_so_far = 0
      end
      if nbStripes > 0
        XXH::XXH3.accumulate_scalar(acc_ptr, input_ptr, secret_ptr + initial_secret_offset, nbStripes)
        input_ptr += (nbStripes * 64)
        nb_stripes_so_far = nb_stripes_so_far + nbStripes
      end
      nb_stripes_so_far
    end

    def digest : Hash128
      secret_bytes = (@ext_secret.nil? ? @custom_secret : @ext_secret).as(Bytes)
      if @total_len > 240_u64
        # Work directly on @acc (no dup - matches C semantics)
        acc_ptr = @acc.to_unsafe
        if @buffered_size >= 64
          nbStripes = (@buffered_size - 1).tdiv(64)
          nb = @nb_stripes_so_far
          consume_stripes(acc_ptr, nb, @nb_stripes_per_block, @buffer.to_unsafe, nbStripes, secret_bytes.to_unsafe, @secret_limit)
          lastStripePtr = @buffer.to_unsafe + (@buffered_size - 64)
          XXH::XXH3.accumulate_512_scalar(acc_ptr, lastStripePtr, secret_bytes.to_unsafe + (@secret_limit - 7))
        else
          # Process the buffered data (less than 64 bytes remaining)
          # Use stack-allocated buffer instead of heap allocation
          lastStripe = uninitialized UInt64[8] # 64 bytes on stack
          catchup_size = 64 - @buffered_size
          buffer_end = XXH3_INTERNALBUFFER_SIZE - catchup_size
          (@buffer.to_unsafe + buffer_end).copy_to(lastStripe.to_unsafe.as(Pointer(UInt8)), catchup_size)
          @buffer.to_unsafe.copy_to(lastStripe.to_unsafe.as(Pointer(UInt8)) + catchup_size, @buffered_size)
          lastStripePtr = lastStripe.to_unsafe.as(Pointer(UInt8))
          XXH::XXH3.accumulate_512_scalar(acc_ptr, lastStripePtr, secret_bytes.to_unsafe + (@secret_limit - 7))
        end
        return XXH::XXH3.finalize_long_128b(acc_ptr, secret_bytes.to_unsafe, @secret_limit + 64, @total_len.to_u64)
      end
      if @use_seed
        return XXH::XXH3.hash128_with_seed(@buffer[0, @buffered_size], @seed)
      end

      # Use native short-paths for unseeded streaming inputs (avoid FFI fallback)
      len = @buffered_size
      ptr = @buffer.to_unsafe
      secret_ptr = secret_bytes.to_unsafe
      if len == 0
        return XXH::XXH3.hash128(Bytes.new(0))
      elsif len <= 16
        return XXH::XXH3.len_0to16_128b(ptr, len, secret_ptr, 0_u64)
      elsif len <= 128
        return XXH::XXH3.len_17to128_128b(ptr, len, secret_ptr, 0_u64)
      else
        return XXH::XXH3.len_129to240_128b(ptr, len, secret_ptr, 0_u64)
      end
    end

    def debug_state
      buf_slice = @buffer[0, @buffered_size]
      end_slice = @buffer[XXH3_INTERNALBUFFER_SIZE - 64, 64] rescue Bytes.new(0)
      {total_len: @total_len, buffered_size: @buffered_size, nb_stripes_so_far: @nb_stripes_so_far, acc: @acc.dup, buffer: buf_slice.to_a, end_buffer: end_slice.to_a, use_seed: @use_seed}
    end

    # Test-only accessor: exposes secret bytes for tests/debugging. Not part of public API.
    def test_debug_secret
      custom = @custom_secret.to_a
      ext = @ext_secret.nil? ? nil : @ext_secret.as(Bytes).to_a
      {use_seed: @use_seed, custom_secret: custom, ext_secret: ext}
    end

    def free; end

    def finalize; end
  end

  # Factory helper (moved here so aggregator is purely declarative)
  def self.new_state128(seed : UInt64? = nil)
    State128.new(seed)
  end
end
