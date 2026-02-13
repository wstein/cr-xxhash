require "./xxh3_streaming_helpers"

module XXH::XXH3
  # Streaming state wrapper (FFI-backed) - 64-bit output
  class State < StreamingStateBase
    def digest : UInt64
      # Use the accumulated buffer and delegate finalization to LibXXH
      data = @data_all
      if @use_seed
        LibXXH.XXH3_64bits_withSeed(data.to_unsafe, data.size, @seed)
      else
        LibXXH.XXH3_64bits(data.to_unsafe, data.size)
      end
    end
  end

  # Factory helper
  def self.new_state(seed : UInt64? = nil)
    State.new(seed)
  end
end
