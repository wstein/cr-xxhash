require "cr-xxhash/src/xxh"

module XXHSum
  module CLI
    module Hasher
      private def self.pad_hex(value : UInt32, width = 8)
        value.to_s(16).rjust(width, '0')
      end

      private def self.pad_hex(value : UInt64, width = 16)
        value.to_s(16).rjust(width, '0')
      end

      def self.hash_path(path : String, algorithm : CLI::Algorithm, seed : UInt64? = nil) : String
        case algorithm
        when Algorithm::XXH32
          val = seed ? XXH::XXH32.hash_file(path, seed.to_u32) : XXH::XXH32.hash_file(path)
          pad_hex(val, 8)
        when Algorithm::XXH64
          val = seed ? XXH::XXH64.hash_file(path, seed) : XXH::XXH64.hash_file(path)
          pad_hex(val, 16)
        when Algorithm::XXH128
          val = seed ? XXH::XXH3.hash128_file(path, seed) : XXH::XXH3.hash128_file(path)
          val.to_hex32
        when Algorithm::XXH3_64
          val = seed ? XXH::XXH3.hash64_file(path, seed) : XXH::XXH3.hash64_file(path)
          pad_hex(val, 16)
        else
          raise "Unknown algorithm"
        end
      end

      def self.hash_stdin(algorithm : CLI::Algorithm, seed : UInt64? = nil, input : IO = STDIN) : String
        case algorithm
        when Algorithm::XXH32
          val = seed ? XXH::XXH32.hash(input, seed.to_u32) : XXH::XXH32.hash(input)
          pad_hex(val, 8)
        when Algorithm::XXH64
          val = seed ? XXH::XXH64.hash(input, seed) : XXH::XXH64.hash(input)
          pad_hex(val, 16)
        when Algorithm::XXH128
          val = seed ? XXH::XXH3.hash128(input, seed) : XXH::XXH3.hash128(input)
          val.to_hex32
        when Algorithm::XXH3_64
          val = seed ? XXH::XXH3.hash64(input, seed) : XXH::XXH3.hash64(input)
          pad_hex(val, 16)
        else
          raise "Unknown algorithm"
        end
      end
    end
  end
end
