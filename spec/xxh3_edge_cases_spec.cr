require "spec"
require "../src/common/primitives.cr"
require "../src/common/common.cr"
require "../src/dispatch.cr"
require "../src/xxh3/wrapper.cr"

describe "XXH3 Edge Cases" do
  describe "Seed initialization (64-bit)" do
    it "state reset with various seeds equals one-shot" do
      input = "the quick brown fox".to_slice
      [0_u64, 1_u64, 0xFFFFFFFFFFFFFFFF_u64, 0xCAFEBABECAFEBABE_u64].each do |seed|
        state = XXH::XXH3.new_state(seed)
        state.update(input)
        state.digest.should eq(XXH::XXH3.hash_with_seed(input, seed))

        # reset/ reuse
        state.reset(seed)
        state.update(input)
        state.digest.should eq(XXH::XXH3.hash_with_seed(input, seed))
      end
    end

    it "empty input with seed matches one-shot" do
      seed = 0xDEADBEEFu64
      state = XXH::XXH3.new_state(seed)
      state.update(Bytes.new(0))
      state.digest.should eq(XXH::XXH3.hash_with_seed(Bytes.new(0), seed))
    end
  end

  describe "129..240 offsets (64 & 128)" do
    [129, 160, 192, 224, 240].each do |len|
      it "64-bit one-shot matches vendor for #{len} bytes" do
        input = Bytes.new(len) { |i| (i % 256).to_u8 }
        result = XXH::XXH3.hash(input)
        expected = LibXXH.XXH3_64bits(input.to_unsafe, input.size)
        result.should eq(expected)
      end

      it "64-bit one-shot with seed matches vendor for #{len} bytes" do
        input = Bytes.new(len) { |i| (i % 256).to_u8 }
        seed = 0x1234567890ABCDEF_u64
        result = XXH::XXH3.hash_with_seed(input, seed)
        expected = LibXXH.XXH3_64bits_withSeed(input.to_unsafe, input.size, seed)
        result.should eq(expected)
      end

      it "128-bit one-shot matches vendor for #{len} bytes" do
        input = Bytes.new(len) { |i| (i % 256).to_u8 }
        expected = LibXXH.XXH3_128bits(input.to_unsafe, input.size)
        result = XXH::Dispatch.hash_xxh128(input)
        result.should eq({expected.low64, expected.high64})
      end
    end
  end

  describe "Streaming chunk transitions (64-bit)" do
    it "matches one-shot for stripe-sized updates" do
      input = Bytes.new(1024) { |i| (i % 256).to_u8 }
      expected = XXH::XXH3.hash(input)
      state = XXH::XXH3.new_state
      off = 0
      while off < input.size
        chunk = input[off, [64, input.size - off].min]
        state.update(chunk)
        off += 64
      end
      state.digest.should eq(expected)
    end

    it "reset with seed produces same as hash_with_seed" do
      input = Bytes.new(100) { |i| (i % 256).to_u8 }
      seed = 0xCAFE_BABE_CAFE_BABE_u64
      expected = XXH::XXH3.hash_with_seed(input, seed)
      state = XXH::XXH3.new_state
      state.reset(seed)
      state.update(input)
      state.digest.should eq(expected)
    end
  end

  describe "Streaming chunk transitions (128-bit)" do
    it "128-bit streaming (FFI) matches one-shot" do
      input = Bytes.new(300) { |i| (i % 256).to_u8 }
      expected = XXH::XXH3.hash128(input)

      got = XXH::XXH3.hash128_stream(input)

      {got.low64, got.high64}.should eq({expected.low64, expected.high64})
    end

    it "128-bit streaming with seed (FFI) matches one-shot" do
      input = Bytes.new(300) { |i| (i % 256).to_u8 }
      seed = 0xDEAD_BEEF_DEAD_BEEFu64
      expected = XXH::XXH3.hash128_with_seed(input, seed)

      got = XXH::XXH3.hash128_stream_with_seed(input, seed)

      {got.low64, got.high64}.should eq({expected.low64, expected.high64})
    end

    it "matches one-shot when fed in many 1-byte chunks" do
      input = Bytes.new(300) { |i| (i % 256).to_u8 }
      expected = XXH::XXH3.hash(input)
      state = XXH::XXH3.new_state
      input.each { |byte| state.update(Bytes[byte]) }
      state.digest.should eq(expected)
    end

    it "matches one-shot when crossing internal buffer boundary" do
      # Feed 200 bytes, then 100 more (total 300, crossing buffer)
      input = Bytes.new(300) { |i| (i % 256).to_u8 }
      expected = XXH::XXH3.hash(input)
      state = XXH::XXH3.new_state
      state.update(input[0, 200])
      state.update(input[200, 100])
      state.digest.should eq(expected)
    end
  end
end
