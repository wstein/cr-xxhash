require "../bindings/safe"
require "../common/types"
require "../xxh3/state64"

module XXH
  module XXH3
    def self.hash64(data : Bytes) : UInt64
      Bindings::XXH3_64.hash(data)
    end

    def self.hash64(data : Bytes, seed : Seed64) : UInt64
      Bindings::XXH3_64.hash(data, seed)
    end

    def self.hash64(string : String) : UInt64
      Bindings::XXH3_64.hash(string)
    end

    def self.hash64(string : String, seed : Seed64) : UInt64
      Bindings::XXH3_64.hash(string, seed)
    end

    def self.hash64(io : IO) : UInt64
      Bindings::XXH3_64.hash(io)
    end

    def self.hash64(io : IO, seed : Seed64) : UInt64
      Bindings::XXH3_64.hash(io, seed)
    end

    def self.hash64_file(path : String | Path) : UInt64
      Bindings::XXH3_64.hash_file(path)
    end

    def self.hash64_file(path : String | Path, seed : Seed64) : UInt64
      Bindings::XXH3_64.hash_file(path, seed)
    end
  end
end
