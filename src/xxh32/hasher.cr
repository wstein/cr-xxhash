require "../bindings/safe"
require "../common/types"
require "../xxh32/state"

module XXH
  module XXH32
    # Unseeded (default) overloads
    def self.hash(data : Bytes | String) : UInt32
      Bindings::XXH32.hash(data)
    end

    def self.hash(io : IO) : UInt32
      Bindings::XXH32.hash(io)
    end

    def self.hash_file(path : String | Path) : UInt32
      Bindings::XXH32.hash_file(path)
    end

    # Seeded overloads
    def self.hash(data : Bytes | String, seed : Seed32) : UInt32
      Bindings::XXH32.hash(data, seed)
    end

    def self.hash(io : IO, seed : Seed32) : UInt32
      Bindings::XXH32.hash(io, seed)
    end

    def self.hash_file(path : String | Path, seed : Seed32) : UInt32
      Bindings::XXH32.hash_file(path, seed)
    end
  end
end
