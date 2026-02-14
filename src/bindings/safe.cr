require "./lib_xxh"
require "../common/errors"
require "../common/types"

module XXH
  # Safe wrapper layer over low-level FFI bindings
  # Handles:
  # - Type conversions (Bytes, String, Slice)
  # - Bounds checking via Bytes/String
  # - No unsafe pointers exposed to caller
  # - Error code validation
  module Bindings
    # XXH32 safe one-shot hasher
    module XXH32
      def self.hash(data : Bytes, seed : UInt32 = 0_u32) : UInt32
        LibXXH.XXH32(data.to_unsafe, data.size, seed)
      end

      def self.hash(string : String, seed : UInt32 = 0_u32) : UInt32
        hash(string.to_slice, seed)
      end

      def self.hash(slice : Slice(UInt8), seed : UInt32 = 0_u32) : UInt32
        LibXXH.XXH32(slice.to_unsafe, slice.size, seed)
      end
    end

    # XXH64 safe one-shot hasher
    module XXH64
      def self.hash(data : Bytes, seed : UInt64 = 0_u64) : UInt64
        LibXXH.XXH64(data.to_unsafe, data.size, seed)
      end

      def self.hash(string : String, seed : UInt64 = 0_u64) : UInt64
        hash(string.to_slice, seed)
      end

      def self.hash(slice : Slice(UInt8), seed : UInt64 = 0_u64) : UInt64
        LibXXH.XXH64(slice.to_unsafe, slice.size, seed)
      end
    end

    # XXH3 64-bit safe one-shot hasher
    module XXH3_64
      def self.hash(data : Bytes, seed : UInt64 = 0_u64) : UInt64
        if seed == 0_u64
          LibXXH.XXH3_64bits(data.to_unsafe, data.size)
        else
          LibXXH.XXH3_64bits_withSeed(data.to_unsafe, data.size, seed)
        end
      end

      def self.hash(string : String, seed : UInt64 = 0_u64) : UInt64
        hash(string.to_slice, seed)
      end

      def self.hash(slice : Slice(UInt8), seed : UInt64 = 0_u64) : UInt64
        if seed == 0_u64
          LibXXH.XXH3_64bits(slice.to_unsafe, slice.size)
        else
          LibXXH.XXH3_64bits_withSeed(slice.to_unsafe, slice.size, seed)
        end
      end

      def self.hash_with_secret(data : Bytes, secret : ::XXH::Secret) : UInt64
        LibXXH.XXH3_64bits_withSecret(data.to_unsafe, data.size, secret.to_unsafe, secret.size)
      end
    end

    # XXH3 128-bit safe one-shot hasher
    module XXH3_128
      def self.hash(data : Bytes, seed : UInt64 = 0_u64) : ::XXH::Hash128
        c_hash = if seed == 0_u64
                   LibXXH.XXH3_128bits(data.to_unsafe, data.size)
                 else
                   LibXXH.XXH3_128bits_withSeed(data.to_unsafe, data.size, seed)
                 end
        ::XXH::Hash128.new(c_hash)
      end

      def self.hash(string : String, seed : UInt64 = 0_u64) : ::XXH::Hash128
        hash(string.to_slice, seed)
      end

      def self.hash(slice : Slice(UInt8), seed : UInt64 = 0_u64) : ::XXH::Hash128
        c_hash = if seed == 0_u64
                   LibXXH.XXH3_128bits(slice.to_unsafe, slice.size)
                 else
                   LibXXH.XXH3_128bits_withSeed(slice.to_unsafe, slice.size, seed)
                 end
        ::XXH::Hash128.new(c_hash)
      end

      def self.hash_with_secret(data : Bytes, secret : ::XXH::Secret) : ::XXH::Hash128
        c_hash = LibXXH.XXH3_128bits_withSecret(data.to_unsafe, data.size, secret.to_unsafe, secret.size)
        ::XXH::Hash128.new(c_hash)
      end
    end

    # Version utilities
    module Version
      def self.number : UInt32
        LibXXH.versionNumber
      end

      def self.to_s : String
        v = number
        major = (v >> 16) & 0xFF
        minor = (v >> 8) & 0xFF
        patch = v & 0xFF
        "#{major}.#{minor}.#{patch}"
      end
    end
  end
end
