module XXH::XXH3
  # 128-bit result type
  struct Hash128
    property low64 : UInt64
    property high64 : UInt64

    def initialize(low64 : UInt64, high64 : UInt64)
      @low64 = low64
      @high64 = high64
    end

    def ==(other : Hash128)
      @low64 == other.low64 && @high64 == other.high64
    end

    def to_tuple
      {@low64, @high64}
    end

    def to_u128 : UInt128
      (high64.to_u128 << 64) | low64.to_u128
    end
  end
end
