module XXHSum
  module CLI
    module Formatter
      # Reverse hex string bytes (e.g., "aabbccdd" -> "ddccbbaa")
      # Assumes input is valid hex with even length
      private def self.reverse_hex_bytes(hex : String) : String
        len = hex.bytesize
        return hex if len < 2
        String.new(len) do |buffer|
          (0...(len // 2)).each do |i|
            src_i = len - (i + 1) * 2
            dst_i = i * 2
            buffer[dst_i] = hex.to_unsafe[src_i]
            buffer[dst_i + 1] = hex.to_unsafe[src_i + 1]
          end
          {len, len}
        end
      end

      def self.format_gnu(hex : String, filename : String?, algorithm : CLI::Algorithm, little_endian : Bool = false) : String
        # Add algorithm prefix and handle endianness
        hex_with_prefix = case algorithm
                          when CLI::Algorithm::XXH3_64
                            if little_endian
                              "XXH3_LE_#{reverse_hex_bytes(hex)}"
                            else
                              "XXH3_#{hex}"
                            end
                          when CLI::Algorithm::XXH32
                            if little_endian
                              "XXH32_LE_#{reverse_hex_bytes(hex)}"
                            else
                              hex
                            end
                          when CLI::Algorithm::XXH64
                            if little_endian
                              "XXH64_LE_#{reverse_hex_bytes(hex)}"
                            else
                              hex
                            end
                          when CLI::Algorithm::XXH128
                            if little_endian
                              "XXH128_LE_#{reverse_hex_bytes(hex)}"
                            else
                              hex
                            end
                          else
                            hex
                          end

        if filename == nil
          # When no filename provided, show only the hash
          hex_with_prefix
        else
          # Show hash with filename (including "stdin" for piped input)
          "#{hex_with_prefix}  #{filename}"
        end
      end

      def self.format_bsd(algo_name : String, hex : String, filename : String, little_endian : Bool = false) : String
        le_hex = little_endian ? reverse_hex_bytes(hex) : hex
        le_suffix = little_endian ? "_LE" : ""
        "#{algo_name}#{le_suffix} (#{filename}) = #{le_hex}"
      end

      def self.algo_name(algorithm : CLI::Algorithm) : String
        case algorithm
        when CLI::Algorithm::XXH32   then "xxh32"
        when CLI::Algorithm::XXH64   then "xxh64"
        when CLI::Algorithm::XXH128  then "xxh128"
        when CLI::Algorithm::XXH3_64 then "xxh3"
        else
          raise "Unknown algorithm"
        end
      end
    end
  end
end
