require "../bindings/safe"
require "../common/types"
require "../xxh3/state"

module XXH
  module XXH3
    def self.hash64(data : Bytes, seed : Seed64 = 0_u64) : UInt64
      Bindings::XXH3_64.hash(data, seed)
    end

    def self.hash64(string : String, seed : Seed64 = 0_u64) : UInt64
      Bindings::XXH3_64.hash(string, seed)
    end

    def self.hash64(io : IO, seed : Seed64 = 0_u64) : UInt64
      Bindings::XXH3_64.hash(io, seed)
    end

    def self.hash64_file(path : String | Path, seed : Seed64 = 0_u64) : UInt64
      Bindings::XXH3_64.hash_file(path, seed)
    end
  end
end
