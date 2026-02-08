require "spec"
require "../src/xxh/primitives.cr"
require "../src/xxh/dispatch.cr"
require "../src/xxh/xxh3.cr"

describe "XXH128 Dispatch (XXH3-based)" do
  describe "One-Shot Hashing" do
    it "hashes empty input" do
      result = XXH::Dispatch.hash_xxh128(Bytes.new(0), 0_u64)
      expected = SpecFFI.xxh3_128(Bytes.new(0))
      {result[0], result[1]}.should eq({expected.low64, expected.high64})
    end

    it "hashes short and medium inputs" do
      ["", "a", "hello", "hello world test message extra", ("x" * 1024)].each do |s|
        data = s.to_slice
        result = XXH::Dispatch.hash_xxh128(data, 0_u64)
        expected = SpecFFI.xxh3_128(data)
        {result[0], result[1]}.should eq({expected.low64, expected.high64})
      end
    end

    it "matches vendor for lengths 0..128" do
      (0..128).each do |len|
        input = Bytes.new(len) { |i| (i % 256).to_u8 }
        result = XXH::Dispatch.hash_xxh128(input, 0_u64)
        expected = SpecFFI.xxh3_128(input)
        if result != {expected.low64, expected.high64}
          puts "MISMATCH at len=#{len}: got #{result}, expected {#{expected.low64}, #{expected.high64}}"
        end
        result.should eq({expected.low64, expected.high64})
      end
    end

    it "respects seed values" do
      input = "benchmark test string".to_slice
      (0..16).each do |seed|
        seed_u64 = seed.to_u64
        result = XXH::Dispatch.hash_xxh128(input, seed_u64)
        expected = SpecFFI.xxh3_128_with_seed(input, seed_u64)
        result.should eq({expected.low64, expected.high64})
      end
    end
  end

  describe "Streamed hashing via FFI oracle" do
    it "matches streaming digest for large input" do
      input = Bytes.new(65536) { |i| (i % 256).to_u8 }

      # Oracle streaming via centralized SpecFFI helper
      expected = SpecFFI.xxh3_128_stream_digest(input)

      # One-shot via dispatch should match
      result = XXH::Dispatch.hash_xxh128(input, 0_u64)
      result.should eq({expected.low64, expected.high64})
    end
  end
end
