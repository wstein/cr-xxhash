require "./xxh3_streaming_helpers"

module XXH::XXH3
  # Streaming state wrapper (native) - 64-bit output
  class State < StreamingStateBase
    def digest : UInt64
      sb = secret_buffer
      if total_len > 240_u64
        # Work directly on @acc (no dup - matches C semantics)
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
        return XXH::XXH3.finalize_long_64b(aptr[0], aptr[1], aptr[2], aptr[3], aptr[4], aptr[5], aptr[6], aptr[7], sb.to_unsafe, total_len)
      end
      if @use_seed
        return XXH::XXH3.hash_with_seed(internal_buffer[0, buffered_size], @seed)
      end

      # Use native short-paths for unseeded streaming inputs (avoid FFI fallback)
      len = buffered_size
      ptr = internal_buffer.to_unsafe
      secret_ptr = sb.to_unsafe
      if len == 0
        return XXH::XXH3.hash(Bytes.new(0))
      elsif len <= 16
        return XXH::XXH3.len_0to16_64b(ptr, len, secret_ptr, 0_u64)
      elsif len <= 128
        return XXH::XXH3.len_17to128_64b(ptr, len, secret_ptr, 0_u64)
      else
        return XXH::XXH3.len_129to240_64b(ptr, len, secret_ptr, 0_u64)
      end
    end
  end

  # Factory helper
  def self.new_state(seed : UInt64? = nil)
    State.new(seed)
  end
end
