require "spec"
require "../src/xxh/primitives.cr"
require "../src/xxh/dispatch.cr"
require "../src/xxh/xxh3.cr"
require "../src/ffi/bindings.cr"

describe "XXH128 Dispatch (XXH3-based)" do
  describe "One-Shot Hashing" do
    it "hashes empty input" do
      result = XXH::Dispatch.hash_xxh128(Bytes.new(0), 0_u64)
      expected = LibXXH.XXH3_128bits(Pointer(UInt8).null, 0)
      {result[0], result[1]}.should eq({expected.low64, expected.high64})
    end

    it "hashes short and medium inputs" do
      ["", "a", "hello", "hello world test message extra", ("x" * 1024)].each do |s|
        data = s.to_slice
        result = XXH::Dispatch.hash_xxh128(data, 0_u64)
        expected = LibXXH.XXH3_128bits(data.to_unsafe, data.size)
        {result[0], result[1]}.should eq({expected.low64, expected.high64})
      end
    end

    it "matches vendor for lengths 0..128" do
      (0..128).each do |len|
        input = Bytes.new(len) { |i| (i % 256).to_u8 }
        result = XXH::Dispatch.hash_xxh128(input, 0_u64)
        expected = LibXXH.XXH3_128bits(input.to_unsafe, input.size)
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
        expected = LibXXH.XXH3_128bits_withSeed(input.to_unsafe, input.size, seed_u64)
        result.should eq({expected.low64, expected.high64})
      end
    end
  end

  describe "Streamed hashing via FFI oracle" do
    it "matches streaming digest for large input" do
      input = Bytes.new(65536) { |i| (i % 256).to_u8 }

      # Oracle streaming via FFI
      state = LibXXH.XXH3_createState
      code = LibXXH.XXH3_128bits_reset(state)
      raise "FFI reset failed" if code != LibXXH::XXH_errorcode::XXH_OK
      code = LibXXH.XXH3_128bits_update(state, input.to_unsafe, input.size)
      raise "FFI update failed" if code != LibXXH::XXH_errorcode::XXH_OK
      expected = LibXXH.XXH3_128bits_digest(state)

      # One-shot via dispatch should match
      result = XXH::Dispatch.hash_xxh128(input, 0_u64)
      result.should eq({expected.low64, expected.high64})

      LibXXH.XXH3_freeState(state)
    end
  end
end
