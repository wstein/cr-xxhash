require "./xxh3_streaming_helpers"

module XXH::XXH3
  # Streaming state wrapper (native) - 64-bit output
  class State < StreamingStateBase
    def digest : UInt64
      sb = secret_buffer
      if total_len > 240_u64
        # Work directly on @acc (no dup - matches C semantics)
        aptr = acc_buffer
        prepare_acc_for_long_input
        return XXH::XXH3.finalize_long_64b(aptr[0], aptr[1], aptr[2], aptr[3], aptr[4], aptr[5], aptr[6], aptr[7], sb.to_unsafe, total_len)
      end
      if @use_seed
        return XXH::XXH3.hash_with_seed(internal_buffer[0, buffered_size], @seed)
      end

      # Use native short-paths for unseeded streaming inputs (avoid FFI fallback)
      short_digest_unseeded_64(
        -> { XXH::XXH3.hash(Bytes.new(0)) },
        -> { XXH::XXH3.len_0to16_64b(internal_buffer.to_unsafe, buffered_size, sb.to_unsafe, 0_u64) },
        -> { XXH::XXH3.len_17to128_64b(internal_buffer.to_unsafe, buffered_size, sb.to_unsafe, 0_u64) },
        -> { XXH::XXH3.len_129to240_64b(internal_buffer.to_unsafe, buffered_size, sb.to_unsafe, 0_u64) }
      )
    end
  end

  # Factory helper
  def self.new_state(seed : UInt64? = nil)
    State.new(seed)
  end
end
