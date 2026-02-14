#!/usr/bin/env crystal
require "json"

# Generates JSON test-vector data from vendor/xxHash/tests/sanity_test_vectors.h
# - output: spec/fixtures/vendor_vectors.json

VENDOR_HEADER    = "vendor/xxHash/tests/sanity_test_vectors.h"
OUT_FIXTURES_DIR = "spec/fixtures"

content = File.read(VENDOR_HEADER)

# Helper to extract an array block by C type/name
def extract_array_block(content, array_name)
  re = /static\s+const\s+\w+\s+#{Regex.escape(array_name)}\s*\[\]\s*=\s*\{(.*?)\};/m
  m = content.match(re)
  m ? m[1] : nil
end

# Parse 32/64/128-bit testdata entries
vec_xxh32_block = extract_array_block(content, "XSUM_XXH32_testdata")
vec_xxh64_block = extract_array_block(content, "XSUM_XXH64_testdata")
vec_xxh3_block = extract_array_block(content, "XSUM_XXH3_testdata")
vec_xxh128_block = extract_array_block(content, "XSUM_XXH128_testdata")

parse_32 = ->(block : String?) do
  entries = [] of Hash(String, UInt64)
  return entries unless block
  block.scan(/\{\s*(\d+)\s*,\s*0x([0-9A-Fa-f]+)U\s*,\s*0x([0-9A-Fa-f]+)U\s*\}/) do |m|
    len, seed_hex, res_hex = m[1], m[2], m[3]
    entries << {"len" => len.to_i64.to_u64, "seed" => seed_hex.to_u64(16), "result" => res_hex.to_u64(16)}
  end
  entries
end

parse_64 = ->(block : String?) do
  entries = [] of Hash(String, UInt64)
  return entries unless block
  block.scan(/\{\s*(\d+)\s*,\s*0x([0-9A-Fa-f]+)(?:U|ULL)\s*,\s*0x([0-9A-Fa-f]+)(?:U|ULL)\s*\}/) do |m|
    len, seed_hex, res_hex = m[1], m[2], m[3]
    entries << {"len" => len.to_i64.to_u64, "seed" => seed_hex.to_u64(16), "result" => res_hex.to_u64(16)}
  end
  entries
end

# 128 entries: { len, seed, { low64, high64 } }
parse_128 = ->(block : String?) do
  entries = [] of Hash(String, UInt64)
  return entries unless block
  block.scan(/\{\s*(\d+)\s*,\s*0x([0-9A-Fa-f]+)ULL\s*,\s*\{\s*0x([0-9A-Fa-f]+)ULL\s*,\s*0x([0-9A-Fa-f]+)ULL\s*\}\s*\}/) do |m|
    len, seed_hex, low_hex, high_hex = m[1], m[2], m[3], m[4]
    # note: vendor prints low then high; normalize to high/low in output
    entries << {"len" => len.to_i64.to_u64, "seed" => seed_hex.to_u64(16), "high" => high_hex.to_u64(16), "low" => low_hex.to_u64(16)}
  end
  entries
end

xxh32 = parse_32.call(vec_xxh32_block)
xxh64 = parse_64.call(vec_xxh64_block)
xxh3 = parse_64.call(vec_xxh3_block)
xxh128 = parse_128.call(vec_xxh128_block)

# Determine maximum length for sanity buffer creation
max_len = [xxh32.map { |e| e["len"].to_i64 }.max || 0,
           xxh64.map { |e| e["len"].to_i64 }.max || 0,
           xxh3.map { |e| e["len"].to_i64 }.max || 0,
           xxh128.map { |e| e["len"].to_i64 }.max || 0].compact.max || 0

# Emit per-algorithm JSON fixtures (hex-format values)
fixtures_dir = OUT_FIXTURES_DIR

# helper to write a fixture object { vectors: [...], sanity_buffer_max_len: N }
def write_fixture_object(path : String, arr : Array(Hash(String, String | Int32)), max_len : Int32)
  io = IO::Memory.new
  JSON.build(io, indent: "  ") do |json|
    json.object do
      json.field("vectors") do
        json.array do
          arr.each do |obj|
            json.object do
              obj.each do |k, v|
                json.field(k, v)
              end
            end
          end
        end
      end
      json.field("sanity_buffer_max_len", max_len)
    end
  end
  File.write(path, io.to_s)
  puts "Wrote #{path}"
end

# Prepare arrays (hex formatted)
xxh32_arr = xxh32.map { |e| {"len" => e["len"].to_i, "seed" => "0x#{e["seed"].to_s(16)}", "result" => "0x#{e["result"].to_s(16)}"} }
xxh64_arr = xxh64.map { |e| {"len" => e["len"].to_i, "seed" => "0x#{e["seed"].to_s(16)}", "result" => "0x#{e["result"].to_s(16)}"} }
xxh3_arr = xxh3.map { |e| {"len" => e["len"].to_i, "seed" => "0x#{e["seed"].to_s(16)}", "result" => "0x#{e["result"].to_s(16)}"} }
xxh128_arr = xxh128.map { |e| {"len" => e["len"].to_i, "seed" => "0x#{e["seed"].to_s(16)}", "high" => "0x#{e["high"].to_s(16)}", "low" => "0x#{e["low"].to_s(16)}"} }

# Write per-algorithm files (each file includes sanity_buffer_max_len)
write_fixture_object(File.join(fixtures_dir, "vendor_vectors_xxh32.json"), xxh32_arr, max_len.to_i32)
write_fixture_object(File.join(fixtures_dir, "vendor_vectors_xxh64.json"), xxh64_arr, max_len.to_i32)
write_fixture_object(File.join(fixtures_dir, "vendor_vectors_xxh3.json"), xxh3_arr, max_len.to_i32)
write_fixture_object(File.join(fixtures_dir, "vendor_vectors_xxh128.json"), xxh128_arr, max_len.to_i32)
