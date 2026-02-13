require "./xxh3_streaming_helpers"

module XXH::XXH3
  # Streaming state wrapper (FFI-backed) - 64-bit output
  class State < StreamingStateBase
    def digest : UInt64
      # Finalize FFI state and return hash (state is freed automatically on finalize)
      LibXXH.XXH3_64bits_digest(@ffi_state)
    end
  end

  # Factory helper
  def self.new_state(seed : UInt64? = nil)
    State.new(seed)
  end
end
