require "./xxh3_streaming_helpers"

module XXH::XXH3
  # 128-bit Streaming state wrapper (native) - 128-bit output
  class State128 < StreamingStateBase
    def digest : Hash128
      sb = secret_buffer
      if total_len > 240_u64
        # Work directly on @acc (no dup - matches C semantics)
        aptr = acc_buffer
        prepare_acc_for_long_input
        return XXH::XXH3.finalize_long_128b(aptr, sb.to_unsafe, secret_limit + 64, total_len.to_u64)
      end
      if @use_seed
        return XXH::XXH3.hash128_with_seed(internal_buffer[0, buffered_size], @seed)
      end

      # Use native short-paths for unseeded streaming inputs (avoid FFI fallback)
      short_digest_unseeded_128(
        -> { XXH::XXH3.hash128(Bytes.new(0)) },
        -> { XXH::XXH3.len_0to16_128b(internal_buffer.to_unsafe, buffered_size, sb.to_unsafe, 0_u64) },
        -> { XXH::XXH3.len_17to128_128b(internal_buffer.to_unsafe, buffered_size, sb.to_unsafe, 0_u64) },
        -> { XXH::XXH3.len_129to240_128b(internal_buffer.to_unsafe, buffered_size, sb.to_unsafe, 0_u64) }
      )
    end
  end

  # Factory helper
  def self.new_state128(seed : UInt64? = nil)
    State128.new(seed)
  end
end
