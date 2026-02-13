require "./xxh3_streaming_helpers"

module XXH::XXH3
  # 128-bit Streaming state wrapper (native) - 128-bit output
  class State128 < StreamingStateBase
    def digest : Hash128
      data = @data_all
      if @use_seed
        c = LibXXH.XXH3_128bits_withSeed(data.to_unsafe, data.size, @seed)
      else
        c = LibXXH.XXH3_128bits(data.to_unsafe, data.size)
      end
      Hash128.new(c.low64, c.high64)
    end
  end

  # Factory helper
  def self.new_state128(seed : UInt64? = nil)
    State128.new(seed)
  end
end
