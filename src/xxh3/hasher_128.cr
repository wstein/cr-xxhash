require "../bindings/safe"
require "../common/types"
require "../xxh3/state128"

module XXH
  module XXH3
    def self.hash128(data : Bytes | String) : UInt128
      Bindings::XXH3_128.hash(data)
    end

    def self.hash128(data : Bytes | String, seed : Seed64) : UInt128
      Bindings::XXH3_128.hash(data, seed)
    end

    def self.hash128(io : IO) : UInt128
      Bindings::XXH3_128.hash(io)
    end

    def self.hash128(io : IO, seed : Seed64) : UInt128
      Bindings::XXH3_128.hash(io, seed)
    end

    def self.hash128_file(path : String | Path) : UInt128
      Bindings::XXH3_128.hash_file(path)
    end

    def self.hash128_file(path : String | Path, seed : Seed64) : UInt128
      Bindings::XXH3_128.hash_file(path, seed)
    end
  end
end
