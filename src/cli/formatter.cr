module XXH::CLI
  # Output formatter for GNU and BSD style checksums
  module Formatter
    # Algorithm names for output
    ALGO_NAMES = {
      Algorithm::XXH32  => "XXH32",
      Algorithm::XXH64  => "XXH64",
      Algorithm::XXH128 => "XXH128",
      Algorithm::XXH3   => "XXH3",
    }

    # Hash lengths in bytes
    HASH_LENGTHS = {
      Algorithm::XXH32  => 4,
      Algorithm::XXH64  => 8,
      Algorithm::XXH128 => 16,
      Algorithm::XXH3   => 8,
    }

    # Hex lookup table - pre-computed for fast hex conversion without allocations
    private HEX_CHARS_BYTES = "0123456789abcdef".to_s.bytes

    # Convert integer to bytes with specified endianness (optimized)
    # Performance-critical path: uses direct bit shifting instead of branches
    def self.to_bytes(value : UInt32, endianness : DisplayEndianness) : Bytes
      if endianness == DisplayEndianness::Big
        Slice.new(4) { |i| ((value >> ((3 - i) * 8)) & 0xFF_u32).to_u8 }
      else
        Slice.new(4) { |i| ((value >> (i * 8)) & 0xFF_u32).to_u8 }
      end
    end

    def self.to_bytes(value : UInt64, endianness : DisplayEndianness) : Bytes
      if endianness == DisplayEndianness::Big
        Slice.new(8) { |i| ((value >> ((7 - i) * 8)) & 0xFF_u64).to_u8 }
      else
        Slice.new(8) { |i| ((value >> (i * 8)) & 0xFF_u64).to_u8 }
      end
    end

    # Fast hex conversion: write directly to a pre-allocated buffer
    # No intermediate String allocations - zero copy!
    private def self.bytes_to_hex_inline(bytes : Bytes, buffer : Bytes, offset : Int32 = 0)
      bytes.each_with_index do |byte, i|
        pos = offset + (i * 2)
        hi = (byte >> 4) & 0x0F
        lo = byte & 0x0F
        buffer[pos] = HEX_CHARS_BYTES[hi]
        buffer[pos + 1] = HEX_CHARS_BYTES[lo]
      end
    end

    # Convert bytes to hex string - single allocation, no intermediate copies
    def self.bytes_to_hex(bytes : Bytes) : String
      buffer = Bytes.new(bytes.size * 2)
      bytes_to_hex_inline(bytes, buffer)
      String.new(buffer)
    end

    # Format a hash result in GNU style
    # GNU style: "XXH3  hashvalue  filename"
    def self.format_gnu(result : HashResult, algorithm : Algorithm, endianness : DisplayEndianness) : String?
      return nil unless result.success?

      filename = escape_filename(result.filename)

      case algorithm
      when Algorithm::XXH32
        hash32 = result.hash32
        return nil unless hash32
        hash_bytes = to_bytes(hash32, endianness)
        hash_str = bytes_to_hex(hash_bytes)
        "#{hash_str}  #{filename}"
      when Algorithm::XXH64, Algorithm::XXH3
        hash64 = result.hash64
        return nil unless hash64
        hash_bytes = to_bytes(hash64, endianness)
        hash_str = bytes_to_hex(hash_bytes)
        prefix = algorithm == Algorithm::XXH3 ? "XXH3_" : ""
        "#{prefix}#{hash_str}  #{filename}"
      when Algorithm::XXH128
        hash128 = result.hash128
        return nil unless hash128
        # Vendor format: high64 then low64 in big-endian
        # But for little-endian output, it's low64_le then high64_le
        high_be = to_bytes(hash128[1], DisplayEndianness::Big)
        low_be = to_bytes(hash128[0], DisplayEndianness::Big)
        hash_bytes = if endianness == DisplayEndianness::Little
                       to_bytes(hash128[0], DisplayEndianness::Little) + to_bytes(hash128[1], DisplayEndianness::Little)
                     else
                       high_be + low_be
                     end
        hash_str = bytes_to_hex(hash_bytes)
        "#{hash_str}  #{filename}"
      end
    end

    # Format a hash result in BSD style (with --tag)
    # BSD style: "XXH3 (filename) = hashvalue"
    def self.format_bsd(result : HashResult, algorithm : Algorithm, endianness : DisplayEndianness) : String?
      return nil unless result.success?

      filename = escape_filename(result.filename)

      case algorithm
      when Algorithm::XXH32
        hash32 = result.hash32
        return nil unless hash32
        hash_bytes = to_bytes(hash32, endianness)
        hash_str = bytes_to_hex(hash_bytes)
        "#{ALGO_NAMES[algorithm]} (#{filename}) = #{hash_str}"
      when Algorithm::XXH64, Algorithm::XXH3
        hash64 = result.hash64
        return nil unless hash64
        hash_bytes = to_bytes(hash64, endianness)
        hash_str = bytes_to_hex(hash_bytes)
        prefix = algorithm == Algorithm::XXH3 ? "XXH3" : "XXH64"
        "#{prefix} (#{filename}) = #{hash_str}"
      when Algorithm::XXH128
        hash128 = result.hash128
        return nil unless hash128
        # Vendor format: high64 then low64 in big-endian
        # But for little-endian output, it's low64_le then high64_le
        high_be = to_bytes(hash128[1], DisplayEndianness::Big)
        low_be = to_bytes(hash128[0], DisplayEndianness::Big)
        hash_bytes = if endianness == DisplayEndianness::Little
                       to_bytes(hash128[0], DisplayEndianness::Little) + to_bytes(hash128[1], DisplayEndianness::Little)
                     else
                       high_be + low_be
                     end
        hash_str = bytes_to_hex(hash_bytes)
        "XXH128 (#{filename}) = #{hash_str}"
      end
    end

    # Helper to convert integer to bytes with specified endianness
    # Format a hash result according to convention
    def self.format(result : HashResult, algorithm : Algorithm, convention : DisplayConvention, endianness : DisplayEndianness) : String?
      case convention
      when DisplayConvention::GNU
        format_gnu(result, algorithm, endianness)
      when DisplayConvention::BSD
        format_bsd(result, algorithm, endianness)
      end
    end

    # Escape special characters in filename
    def self.escape_filename(filename : String) : String
      escaped = filename.bytes.map do |byte|
        case byte
        when '\\' then "\\\\"
        when '\n' then "\\n"
        when '\r' then "\\r"
        else
          byte.chr
        end
      end.join
      escaped
    end

    # Unescape filename
    def self.unescape_filename(escaped : String) : String?
      result = String.build(escaped.size) do |str|
        i = 0
        while i < escaped.size
          if escaped[i] == '\\' && i + 1 < escaped.size
            case escaped[i + 1]
            when 'n'  then str << '\n'
            when 'r'  then str << '\r'
            when '\\' then str << '\\'
            else
              return nil
            end
            i += 2
          else
            str << escaped[i]
            i += 1
          end
        end
      end
      result
    end

    # Convert hex string to bytes
    def self.hex_to_bytes(hex : String) : Bytes?
      return nil if hex.size % 2 != 0

      bytes = Bytes.new(hex.size // 2)
      (hex.size // 2).times do |i|
        hi = hex[i * 2].to_u8?(16)
        lo = hex[i * 2 + 1].to_u8?(16)
        return nil unless hi && lo
        bytes[i] = (hi << 4) | lo
      end
      bytes
    end

    # Parse a checksum file line (delegates to smaller helpers)
    # Returns {filename, algorithm, hash_bytes, is_le} or nil
    def self.parse_checksum_line(line : String, algo_bitmask : Int32) : NamedTuple(filename: String, algorithm: Algorithm, hash: Bytes, is_le: Bool)?
      line = line.strip

      # Skip empty lines and comments
      return nil if line.empty? || line.starts_with?('#')

      if m = line.match(/^([A-Za-z0-9_]+)\s*\(([^)]+)\)\s*=\s*(.+)$/)
        parse_bsd_checksum_line(m, algo_bitmask)
      else
        parse_gnu_checksum_line(line, algo_bitmask)
      end
    end

    private def self.parse_bsd_checksum_line(m : Regex::MatchData, algo_bitmask : Int32) : NamedTuple(filename: String, algorithm: Algorithm, hash: Bytes, is_le: Bool)?
      algo_name = m[1]
      filename = m[2]
      hash_str = m[3].strip

      algorithm = parse_algorithm_name(algo_name)
      return nil unless algorithm
      return nil unless algo_accepts(algo_bitmask, algorithm)

      is_le = algo_name.includes?("_LE")
      if algorithm == Algorithm::XXH3 && !algo_name.starts_with?("XXH3")
        return nil
      end

      hash = hex_to_bytes(hash_str)
      return nil unless hash

      {filename: filename, algorithm: algorithm, hash: hash, is_le: is_le}
    end

    private def self.parse_gnu_checksum_line(line : String, algo_bitmask : Int32) : NamedTuple(filename: String, algorithm: Algorithm, hash: Bytes, is_le: Bool)?
      parts = line.split(2)
      return nil unless parts.size == 2

      hash_str = parts[0]
      filename = parts[1]

      # Detect algorithm from hash length
      hash_len = hash_str.size
      algorithm = case hash_len
                  when  8 then Algorithm::XXH32
                  when 16 then Algorithm::XXH64
                  when 21 then Algorithm::XXH3
                  when 32 then Algorithm::XXH128
                  else         nil
                  end
      return nil unless algorithm
      return nil unless algo_accepts(algo_bitmask, algorithm)

      if algorithm == Algorithm::XXH3 && !hash_str.starts_with?("XXH3_")
        return nil
      end

      clean_hash = if algorithm == Algorithm::XXH3 && hash_str.starts_with?("XXH3_")
                     hash_str[5..]
                   else
                     hash_str
                   end

      hash = hex_to_bytes(clean_hash)
      return nil unless hash

      {filename: filename, algorithm: algorithm, hash: hash, is_le: false}
    end

    private def self.parse_algorithm_name(name : String) : Algorithm?
      case name.upcase
      when "XXH32"     then Algorithm::XXH32
      when "XXH32_LE"  then Algorithm::XXH32
      when "XXH64"     then Algorithm::XXH64
      when "XXH64_LE"  then Algorithm::XXH64
      when "XXH128"    then Algorithm::XXH128
      when "XXH128_LE" then Algorithm::XXH128
      when "XXH3"      then Algorithm::XXH3
      when "XXH3_LE"   then Algorithm::XXH3
      else
        nil
      end
    end

    private def self.algo_accepts(bitmask : Int32, algo : Algorithm) : Bool
      bit = 1 << algo.value
      (bitmask & bit) != 0
    end
  end
end
