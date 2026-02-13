require "./xxh3_streaming_helpers"

module XXH::XXH3
  # 128-bit Streaming state wrapper (FFI-backed) - 128-bit output
  class State128 < StreamingStateBase
    def digest : Hash128
      # Finalize FFI state and return 128-bit hash
      c = LibXXH.XXH3_128bits_digest(@ffi_state)
      Hash128.new(c.low64, c.high64)
    end
  end

  # Factory helper
  def self.new_state128(seed : UInt64? = nil)
    State128.new(seed)
  end
end
