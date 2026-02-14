require "../bindings/safe"
require "../common/types"
require "../xxh32/state"

module XXH
  module XXH32
    def self.hash(data : Bytes, seed : Seed32 = 0_u32) : UInt32
      Bindings::XXH32.hash(data, seed)
    end

    def self.hash(string : String, seed : Seed32 = 0_u32) : UInt32
      Bindings::XXH32.hash(string, seed)
    end

    def self.hash(io : IO, seed : Seed32 = 0_u32) : UInt32
      Bindings::XXH32.hash(io, seed)
    end

    def self.hash_file(path : String | Path, seed : Seed32 = 0_u32) : UInt32
      Bindings::XXH32.hash_file(path, seed)
    end
  end
end
