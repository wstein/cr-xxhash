require "../../../src/xxh"

module XXHSum
  module CLI
    module Hasher
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

        case simd_mode
        when "scalar"
          LibXXH.xxh3_64_scalar(data.to_unsafe, data.size, seed)
        {% if flag?(:x86_64) %}
        when "sse2"
          LibXXH.xxh3_64_sse2(data.to_unsafe, data.size, seed)
        when "avx2"
          LibXXH.xxh3_64_avx2(data.to_unsafe, data.size, seed)
        when "avx512"
          LibXXH.xxh3_64_avx512(data.to_unsafe, data.size, seed)
        {% elsif flag?(:aarch64) %}
        when "neon"
          LibXXH.xxh3_64_neon(data.to_unsafe, data.size, seed)
        when "sve"
          LibXXH.xxh3_64_sve(data.to_unsafe, data.size, seed)
        {% end %}
        else
          XXH::XXH3.hash64(data, seed)
        end
      end

      private def self.hash_xxh128_bytes(data : Bytes, seed : UInt64, simd_mode : String?) : UInt128
        return XXH::XXH3.hash128(data, seed) if simd_mode.nil?

        c_hash = case simd_mode
                 when "scalar"
                   LibXXH.xxh3_128_scalar(data.to_unsafe, data.size, seed)
                 {% if flag?(:x86_64) %}
                 when "sse2"
                   LibXXH.xxh3_128_sse2(data.to_unsafe, data.size, seed)
                 when "avx2"
                   LibXXH.xxh3_128_avx2(data.to_unsafe, data.size, seed)
                 when "avx512"
                   LibXXH.xxh3_128_avx512(data.to_unsafe, data.size, seed)
                 {% elsif flag?(:aarch64) %}
                 when "neon"
                   LibXXH.xxh3_128_neon(data.to_unsafe, data.size, seed)
                 when "sve"
                   LibXXH.xxh3_128_sve(data.to_unsafe, data.size, seed)
                 {% end %}
                 else
                   return XXH::XXH3.hash128(data, seed)
                 end

        UInt128.from_c_hash(c_hash)
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
