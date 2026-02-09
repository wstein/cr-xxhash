module XXH::XXH3
  # Shared base class for XXH3 streaming states (64-bit and 128-bit).
  # This class contains all common state management to avoid duplication.
  #
  # Subclasses should override `digest` to provide algorithm-specific finalization.
  # All other methods (update, consume_stripes, etc.) are shared.

  class StreamingStateBase
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

    CONST_INTERNALBUFFER_SIZE = 256

    def initialize(seed : UInt64? = nil)
      @acc = uninitialized UInt64[8]
      @custom_secret = Bytes.new(XXH::Constants::SECRET_DEFAULT_SIZE, 0)
      @buffer = Bytes.new(CONST_INTERNALBUFFER_SIZE, 0)
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
      # initialize acc and state per XXH3_reset_internal
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
      @nb_stripes_per_block = (@secret_limit / 8).to_i

      self
    end

    def update(input : Bytes)
      b = input
      len = b.size
      return if len == 0
      @total_len = @total_len &+ len.to_u64

      if len <= CONST_INTERNALBUFFER_SIZE - @buffered_size
        # just append to buffer
        b.copy_to(@buffer.to_unsafe + @buffered_size, len)
        @buffered_size += len
        return
      end

      secret_bytes = (@ext_secret.nil? ? @custom_secret : @ext_secret).as(Bytes)

      offset = 0
      if @buffered_size > 0
        load_size = CONST_INTERNALBUFFER_SIZE - @buffered_size
        b[offset, load_size].copy_to(@buffer.to_unsafe + @buffered_size, load_size)
        offset += load_size
        # consume all stripes from buffer
        nb_stripes = (CONST_INTERNALBUFFER_SIZE / 64).to_i
        @nb_stripes_so_far = consume_stripes(@acc.to_unsafe, @nb_stripes_so_far, @nb_stripes_per_block, @buffer.to_unsafe, nb_stripes, secret_bytes.to_unsafe, @secret_limit)
        @buffered_size = 0
      end

      # process large chunks from remaining input
      remaining = len - offset
      if remaining > CONST_INTERNALBUFFER_SIZE
        nbStripes = ((remaining - 1) / 64).to_i
        @nb_stripes_so_far = consume_stripes(@acc.to_unsafe, @nb_stripes_so_far, @nb_stripes_per_block, b.to_unsafe + offset, nbStripes, secret_bytes.to_unsafe, @secret_limit)
        # copy last 64 bytes into the end of buffer (ensure src is in-bounds)
        src = offset + (nbStripes * 64)
        src = (src + 64 <= len) ? src : (len - 64)
        b[src, 64].copy_to(@buffer.to_unsafe + (CONST_INTERNALBUFFER_SIZE - 64), 64)
        offset += nbStripes * 64
      end

      # copy remaining into buffer
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

    protected def prepare_acc_for_long_input
      sb = secret_buffer
      aptr = acc_buffer
      if buffered_size >= 64
        nbStripes = (buffered_size - 1).tdiv(64)
        nb = @nb_stripes_so_far
        consume_stripes(aptr, nb, @nb_stripes_per_block, internal_buffer.to_unsafe, nbStripes, sb.to_unsafe, secret_limit)
        lastStripePtr = internal_buffer.to_unsafe + (buffered_size - 64)
        XXH::XXH3.accumulate_512_scalar(aptr, lastStripePtr, sb.to_unsafe + (secret_limit - 7))
      else
        # Process the buffered data (less than 64 bytes remaining)
        # Use stack-allocated buffer instead of heap allocation
        lastStripe = uninitialized UInt64[8] # 64 bytes on stack
        catchup_size = 64 - buffered_size
        buffer_end = CONST_INTERNALBUFFER_SIZE - catchup_size
        (internal_buffer.to_unsafe + buffer_end).copy_to(lastStripe.to_unsafe.as(Pointer(UInt8)), catchup_size)
        internal_buffer.to_unsafe.copy_to(lastStripe.to_unsafe.as(Pointer(UInt8)) + catchup_size, buffered_size)
        lastStripePtr = lastStripe.to_unsafe.as(Pointer(UInt8))
        XXH::XXH3.accumulate_512_scalar(aptr, lastStripePtr, sb.to_unsafe + (secret_limit - 7))
      end
    end

    protected def short_digest_unseeded_64(empty_proc : -> UInt64, upto16_proc : -> UInt64, upto128_proc : -> UInt64, upto240_proc : -> UInt64) : UInt64
      len = buffered_size
      ptr = internal_buffer.to_unsafe
      secret_ptr = secret_buffer.to_unsafe
      if len == 0
        empty_proc.call
      elsif len <= 16
        upto16_proc.call
      elsif len <= 128
        upto128_proc.call
      else
        upto240_proc.call
      end
    end

    protected def short_digest_unseeded_128(empty_proc : -> XXH::XXH3::Hash128, upto16_proc : -> XXH::XXH3::Hash128, upto128_proc : -> XXH::XXH3::Hash128, upto240_proc : -> XXH::XXH3::Hash128) : XXH::XXH3::Hash128
      len = buffered_size
      ptr = internal_buffer.to_unsafe
      secret_ptr = secret_buffer.to_unsafe
      if len == 0
        empty_proc.call
      elsif len <= 16
        upto16_proc.call
      elsif len <= 128
        upto128_proc.call
      else
        upto240_proc.call
      end
    end

    def debug_state
      buf_slice = @buffer[0, @buffered_size]
      end_slice = @buffer[CONST_INTERNALBUFFER_SIZE - 64, 64] rescue Bytes.new(0)
      {total_len: @total_len, buffered_size: @buffered_size, nb_stripes_so_far: @nb_stripes_so_far, acc: @acc.dup, buffer: buf_slice.to_a, end_buffer: end_slice.to_a, use_seed: @use_seed}
    end

    def test_debug_secret
      custom = @custom_secret.to_a
      ext = @ext_secret.nil? ? nil : @ext_secret.as(Bytes).to_a
      {use_seed: @use_seed, custom_secret: custom, ext_secret: ext}
    end

    def free; end

    def finalize; end

    # Protected helpers for subclasses
    protected def secret_buffer
      (@ext_secret.nil? ? @custom_secret : @ext_secret).as(Bytes)
    end

    protected def acc_buffer
      @acc.to_unsafe
    end

    protected def internal_buffer
      @buffer
    end

    protected def buffered_size
      @buffered_size
    end

    protected def secret_limit
      @secret_limit
    end

    protected def total_len
      @total_len
    end
  end
end
