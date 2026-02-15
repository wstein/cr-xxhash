require "../bindings/safe"
require "../common/types"
require "../xxh64/state"

module XXH
  module XXH64
    # Unseeded (default) overloads
    def self.hash(data : Bytes) : UInt64
      Bindings::XXH64.hash(data)
    end

    def self.hash(string : String) : UInt64
      Bindings::XXH64.hash(string)
    end

    def self.hash(io : IO) : UInt64
      Bindings::XXH64.hash(io)
    end

    def self.hash_file(path : String | Path) : UInt64
      Bindings::XXH64.hash_file(path)
    end

    # Seeded overloads
    def self.hash(data : Bytes, seed : Seed64) : UInt64
      Bindings::XXH64.hash(data, seed)
    end

    def self.hash(string : String, seed : Seed64) : UInt64
      Bindings::XXH64.hash(string, seed)
    end

    def self.hash(io : IO, seed : Seed64) : UInt64
      Bindings::XXH64.hash(io, seed)
    end

    def self.hash_file(path : String | Path, seed : Seed64) : UInt64
      Bindings::XXH64.hash_file(path, seed)
    end
  end
end
