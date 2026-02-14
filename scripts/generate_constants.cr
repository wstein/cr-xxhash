#!/usr/bin/env crystal
# Script to parse vendor xxHash headers and generate Crystal constants
# Run: crystal scripts/generate_constants.cr

require "regex"
require "file"

HEADER_PATH = "vendor/xxHash/xxhash.h"
OUTPUT_PATH = "src/vendor/constants.cr"

# Patterns to extract (name => crystal_type)
CONSTANTS = {
  # Secret sizes (use Int32 for array sizing)
  "XXH3_SECRET_SIZE_MIN"     => :Int32,
  "XXH3_SECRET_DEFAULT_SIZE" => :Int32,
  "XXH_SECRET_DEFAULT_SIZE"  => :Int32,

  # XXH3 midsize (use Int32 for array sizing)
  "XXH3_MIDSIZE_MAX"         => :Int32,
  "XXH3_MIDSIZE_STARTOFFSET" => :Int32,
  "XXH3_MIDSIZE_LASTOFFSET"  => :Int32,

  # Stripe/block (use Int32 for array sizing)
  "XXH_STRIPE_LEN" => :Int32,
  "XXH_ACC_NB"     => :Int32,

  # Primes (used by pure Crystal implementations)
  "XXH_PRIME32_1" => :UInt32,
  "XXH_PRIME32_2" => :UInt32,
  "XXH_PRIME32_3" => :UInt32,
  "XXH_PRIME32_4" => :UInt32,
  "XXH_PRIME32_5" => :UInt32,
  "XXH_PRIME64_1" => :UInt64,
  "XXH_PRIME64_2" => :UInt64,
  "XXH_PRIME64_3" => :UInt64,
  "XXH_PRIME64_4" => :UInt64,
  "XXH_PRIME64_5" => :UInt64,
}

def extract_constants(header_path : String) : Hash(String, String)
  constants = {} of String => String

  content = File.read(header_path)

  CONSTANTS.each do |name, type|
    # Match #define NAME value (hex or decimal, with optional U/ULL suffix)
    pattern = /#define\s+#{name}\s+(0x[0-9A-Fa-f]+|\d+)(?:U|ULL)?/
    if match = content.match(pattern)
      raw_value = match[1]
      # Crystal uses lowercase hex (0x..., not 0X...)
      value = raw_value.downcase
      suffix = case type
               when :UInt32 then "_u32"
               when :UInt64 then "_u64"
               else              ""
               end
      constants[name] = "#{value}#{suffix}"
    end
  end

  constants
end

def generate_crystal_file(constants : Hash(String, String)) : String
  # pretty alignment: compute column widths
  max_name = constants.keys.max_by(&.size).size
  max_val = constants.values.max_by(&.size).size

  lines = [] of String
  lines << "# Auto-generated from vendor/xxHash/xxhash.h"
  lines << "# DO NOT EDIT - run `crystal scripts/generate_constants.cr` to regenerate"
  lines << ""
  lines << "lib LibXXH"
  lines << "  # Vendor macro constants (imported from C headers)"
  lines << "  # NOTE: Default secret (XXH3_kSecret / XXH_SECRET_DEFAULT_SIZE) is defined in vendor headers — keep hardcoded; it never changes."

  constants.each do |name, value|
    name_field = name.ljust(max_name)
    val_field = value.rjust(max_val)
    lines << "  #{name_field} = #{val_field}"
  end

  lines << "end"
  lines << "" # final newline
  lines.join("\n")
end

puts "Parsing #{HEADER_PATH}..."
constants = extract_constants(HEADER_PATH)

puts "Found #{constants.size} constants:"
constants.each do |name, value|
  puts "  #{name} = #{value}"
end

output = generate_crystal_file(constants)
File.write(OUTPUT_PATH, output)

puts ""
puts "Generated #{OUTPUT_PATH}"
