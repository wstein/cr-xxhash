require "../../../src/xxh"
require "../../../src/bindings/simd_handler"

module XXHSum
  module CLI
    module Hasher
      # SIMD Dispatch Notes (xxhash-wrapper refactor):
      # - All SIMD variants (scalar, neon, sve, sse2, avx2, avx512) are unconditionally compiled
      # - Each variant has its own CPU flags set during compilation (no runtime simd_backend selection)
      # - Consumer (this code) explicitly calls the desired variant via LibXXH function
      # - If CPU doesn't support the target variant, OS raises SIGILL (process crash)
      # - URL options validation in options.cr ensures only supported variants are selectable
      
      private def self.pad_hex(value : UInt32, width = 8)
        value.to_s(16).rjust(width, '0')
      end

      private def self.pad_hex(value : UInt64, width = 16)
        value.to_s(16).rjust(width, '0')
      end

      private def self.read_all_bytes(io : IO) : Bytes
        io.getb_to_end
      end

      private def self.hash_xxh3_64_bytes(data : Bytes, seed : UInt64, simd_mode : String?) : UInt64
        return XXH::XXH3.hash64(data, seed) if simd_mode.nil?

        if simd_mode == "scalar"
          return LibXXH.xxh3_64_scalar(data.to_unsafe, data.size, seed)
        end

        {% if flag?(:x86_64) %}
        if simd_mode == "sse2"
          return LibXXH.xxh3_64_sse2(data.to_unsafe, data.size, seed)
        elsif simd_mode == "avx2"
          return LibXXH.xxh3_64_avx2(data.to_unsafe, data.size, seed)
        elsif simd_mode == "avx512"
          return LibXXH.xxh3_64_avx512(data.to_unsafe, data.size, seed)
        end
        {% elsif flag?(:aarch64) %}
        if simd_mode == "neon"
          return LibXXH.xxh3_64_neon(data.to_unsafe, data.size, seed)
        elsif simd_mode == "sve"
          return LibXXH.xxh3_64_sve(data.to_unsafe, data.size, seed)
        end
        {% end %}

        XXH::XXH3.hash64(data, seed)
      end

      private def self.hash_xxh128_bytes(data : Bytes, seed : UInt64, simd_mode : String?) : UInt128
        return XXH::XXH3.hash128(data, seed) if simd_mode.nil?

        if simd_mode == "scalar"
          return UInt128.from_c_hash(LibXXH.xxh3_128_scalar(data.to_unsafe, data.size, seed))
        end

        {% if flag?(:x86_64) %}
        if simd_mode == "sse2"
          return UInt128.from_c_hash(LibXXH.xxh3_128_sse2(data.to_unsafe, data.size, seed))
        elsif simd_mode == "avx2"
          return UInt128.from_c_hash(LibXXH.xxh3_128_avx2(data.to_unsafe, data.size, seed))
        elsif simd_mode == "avx512"
          return UInt128.from_c_hash(LibXXH.xxh3_128_avx512(data.to_unsafe, data.size, seed))
        end
        {% elsif flag?(:aarch64) %}
        if simd_mode == "neon"
          return UInt128.from_c_hash(LibXXH.xxh3_128_neon(data.to_unsafe, data.size, seed))
        elsif simd_mode == "sve"
          return UInt128.from_c_hash(LibXXH.xxh3_128_sve(data.to_unsafe, data.size, seed))
        end
        {% end %}

        XXH::XXH3.hash128(data, seed)
      end

      def self.hash_path(path : String, algorithm : CLI::Algorithm, seed : UInt64? = nil, simd_mode : String? = nil) : String
        case algorithm
        when Algorithm::XXH32
          val = seed ? XXH::XXH32.hash_file(path, seed.to_u32) : XXH::XXH32.hash_file(path)
          pad_hex(val, 8)
        when Algorithm::XXH64
          val = seed ? XXH::XXH64.hash_file(path, seed) : XXH::XXH64.hash_file(path)
          pad_hex(val, 16)
        when Algorithm::XXH128
          used_seed = seed || 0_u64
          if simd_mode
            data = File.open(path, "rb") { |file| read_all_bytes(file) }
            val = hash_xxh128_bytes(data, used_seed, simd_mode)
          else
            val = seed ? XXH::XXH3.hash128_file(path, seed) : XXH::XXH3.hash128_file(path)
          end
          val.to_hex32
        when Algorithm::XXH3_64
          used_seed = seed || 0_u64
          if simd_mode
            data = File.open(path, "rb") { |file| read_all_bytes(file) }
            val = hash_xxh3_64_bytes(data, used_seed, simd_mode)
          else
            val = seed ? XXH::XXH3.hash64_file(path, seed) : XXH::XXH3.hash64_file(path)
          end
          pad_hex(val, 16)
        else
          raise "Unknown algorithm"
        end
      end

      def self.hash_stdin(algorithm : CLI::Algorithm, seed : UInt64? = nil, simd_mode : String? = nil, input : IO = STDIN) : String
        case algorithm
        when Algorithm::XXH32
          val = seed ? XXH::XXH32.hash(input, seed.to_u32) : XXH::XXH32.hash(input)
          pad_hex(val, 8)
        when Algorithm::XXH64
          val = seed ? XXH::XXH64.hash(input, seed) : XXH::XXH64.hash(input)
          pad_hex(val, 16)
        when Algorithm::XXH128
          used_seed = seed || 0_u64
          if simd_mode
            data = read_all_bytes(input)
            val = hash_xxh128_bytes(data, used_seed, simd_mode)
          else
            val = seed ? XXH::XXH3.hash128(input, seed) : XXH::XXH3.hash128(input)
          end
          val.to_hex32
        when Algorithm::XXH3_64
          used_seed = seed || 0_u64
          if simd_mode
            data = read_all_bytes(input)
            val = hash_xxh3_64_bytes(data, used_seed, simd_mode)
          else
            val = seed ? XXH::XXH3.hash64(input, seed) : XXH::XXH3.hash64(input)
          end
          pad_hex(val, 16)
        else
          raise "Unknown algorithm"
        end
      end
    end
  end
end
