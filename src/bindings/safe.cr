require "./lib_xxh"
require "../common/errors"
require "../common/types"

module XXH
  BUFFER_SIZE = 8192

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

      def self.hash(io : IO, seed : UInt32 = 0_u32) : UInt32
        state = LibXXH.XXH32_createState
        raise StateError.new("Failed to allocate XXH32 state") if state.null?
        ErrorHandler.check!(LibXXH.XXH32_reset(state, seed), "XXH32 reset for IO hash")
        buffer = Bytes.new(BUFFER_SIZE)
        begin
          while (bytes_read = io.read(buffer)) > 0
            slice = buffer[0, bytes_read]
            ErrorHandler.check!(LibXXH.XXH32_update(state, slice.to_unsafe, bytes_read), "XXH32 update")
          end
          LibXXH.XXH32_digest(state)
        ensure
          ErrorHandler.check!(LibXXH.XXH32_freeState(state), "XXH32 free state")
        end
      end

      def self.hash_file(path : String | Path, seed : UInt32 = 0_u32) : UInt32
        File.open(path, "r") do |file|
          hash(file, seed)
        end
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

      def self.hash(io : IO, seed : UInt64 = 0_u64) : UInt64
        state = LibXXH.XXH64_createState
        raise StateError.new("Failed to allocate XXH64 state") if state.null?
        ErrorHandler.check!(LibXXH.XXH64_reset(state, seed), "XXH64 reset for IO hash")
        buffer = Bytes.new(BUFFER_SIZE)
        begin
          while (bytes_read = io.read(buffer)) > 0
            slice = buffer[0, bytes_read]
            ErrorHandler.check!(LibXXH.XXH64_update(state, slice.to_unsafe, bytes_read), "XXH64 update")
          end
          LibXXH.XXH64_digest(state)
        ensure
          ErrorHandler.check!(LibXXH.XXH64_freeState(state), "XXH64 free state")
        end
      end

      def self.hash_file(path : String | Path, seed : UInt64 = 0_u64) : UInt64
        File.open(path, "r") { |file| hash(file, seed) }
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

      def self.hash(io : IO, seed : UInt64 = 0_u64) : UInt64
        state = LibXXH.XXH3_createState
        raise StateError.new("Failed to create XXH3 state") if state.null?
        if seed == 0_u64
          ErrorHandler.check!(LibXXH.XXH3_64bits_reset(state), "XXH3_64 reset for IO hash")
        else
          ErrorHandler.check!(LibXXH.XXH3_64bits_reset_withSeed(state, seed), "XXH3_64 reset with seed")
        end
        buffer = Bytes.new(BUFFER_SIZE)
        begin
          while (bytes_read = io.read(buffer)) > 0
            slice = buffer[0, bytes_read]
            ErrorHandler.check!(LibXXH.XXH3_64bits_update(state, slice.to_unsafe, bytes_read), "XXH3_64 update")
          end
          LibXXH.XXH3_64bits_digest(state)
        ensure
          ErrorHandler.check!(LibXXH.XXH3_freeState(state), "XXH3 free state")
        end
      end

      def self.hash_file(path : String | Path, seed : UInt64 = 0_u64) : UInt64
        File.open(path, "r") { |file| hash(file, seed) }
      end
    end

    # XXH3 128-bit safe one-shot hasher
    module XXH3_128
      def self.hash(data : Bytes, seed : UInt64 = 0_u64) : UInt128
        c_hash = if seed == 0_u64
                   LibXXH.XXH3_128bits(data.to_unsafe, data.size)
                 else
                   LibXXH.XXH3_128bits_withSeed(data.to_unsafe, data.size, seed)
                 end
        UInt128.from_c_hash(c_hash)
      end

      def self.hash(string : String, seed : UInt64 = 0_u64) : UInt128
        hash(string.to_slice, seed)
      end

      def self.hash(slice : Slice(UInt8), seed : UInt64 = 0_u64) : UInt128
        c_hash = if seed == 0_u64
                   LibXXH.XXH3_128bits(slice.to_unsafe, slice.size)
                 else
                   LibXXH.XXH3_128bits_withSeed(slice.to_unsafe, slice.size, seed)
                 end
        UInt128.from_c_hash(c_hash)
      end

      def self.hash_with_secret(data : Bytes, secret : ::XXH::Secret) : UInt128
        c_hash = LibXXH.XXH3_128bits_withSecret(data.to_unsafe, data.size, secret.to_unsafe, secret.size)
        UInt128.from_c_hash(c_hash)
      end

      def self.hash(io : IO, seed : UInt64 = 0_u64) : UInt128
        state = LibXXH.XXH3_createState
        raise StateError.new("Failed to create XXH3 state") if state.null?
        if seed == 0_u64
          ErrorHandler.check!(LibXXH.XXH3_128bits_reset(state), "XXH3_128 reset for IO hash")
        else
          ErrorHandler.check!(LibXXH.XXH3_128bits_reset_withSeed(state, seed), "XXH3_128 reset with seed")
        end
        buffer = Bytes.new(BUFFER_SIZE)
        begin
          while (bytes_read = io.read(buffer)) > 0
            slice = buffer[0, bytes_read]
            ErrorHandler.check!(LibXXH.XXH3_128bits_update(state, slice.to_unsafe, bytes_read), "XXH3_128 update")
          end
          c_hash = LibXXH.XXH3_128bits_digest(state)
          UInt128.from_c_hash(c_hash)
        ensure
          ErrorHandler.check!(LibXXH.XXH3_freeState(state), "XXH3 free state")
        end
      end

      def self.hash_file(path : String | Path, seed : UInt64 = 0_u64) : UInt128
        File.open(path, "r") { |file| hash(file, seed) }
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
