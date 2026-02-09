require "spec"
require "../src/xxh/primitives.cr"
require "../src/xxh/common.cr"
require "../src/xxh/dispatch.cr"
require "../src/xxh/xxh64.cr"
require "../src/xxh/xxh3.cr"
require "./support/libxxh_helper"

describe "XXH3 Native Implementation" do
  describe "One-Shot Hashing - Edge Cases" do
    it "hashes empty input" do
      input = Bytes.new(0)
      result = XXH::XXH3.hash(input)
      expected = SpecFFI.xxh3_64(Bytes.new(0))
      result.should eq(expected)
    end

    it "hashes single byte" do
      input = Bytes[0x42]
      result = XXH::XXH3.hash(input)
      expected = LibXXH.XXH3_64bits(input.to_unsafe, input.size)
      result.should eq(expected)
    end
  end

  describe "One-Shot Hashing - Short Inputs (1-16 bytes)" do
    [
      {name: "2 bytes", input: Bytes[0x01, 0x02]},
      {name: "3 bytes", input: Bytes[0x01, 0x02, 0x03]},
      {name: "4 bytes", input: Bytes[0x01, 0x02, 0x03, 0x04]},
      {name: "5 bytes (hello)", input: "hello".to_slice},
      {name: "8 bytes", input: Bytes.new(8) { |i| (i % 256).to_u8 }},
      {name: "16 bytes", input: Bytes.new(16) { |i| (i % 256).to_u8 }},
    ].each do |test_case|
      it "hashes #{test_case[:name]}" do
        input = test_case[:input]
        result = XXH::XXH3.hash(input)
        expected = LibXXH.XXH3_64bits(input.to_unsafe, input.size)
        result.should eq(expected)
      end
    end
  end

  describe "One-Shot Hashing - Medium Inputs (17-240 bytes)" do
    [
      {name: "17 bytes", input: Bytes.new(17) { |i| (i % 256).to_u8 }},
      {name: "64 bytes", input: Bytes.new(64) { |i| (i % 256).to_u8 }},
      {name: "128 bytes", input: Bytes.new(128) { |i| (i % 256).to_u8 }},
      {name: "240 bytes", input: Bytes.new(240) { |i| (i % 256).to_u8 }},
    ].each do |test_case|
      it "hashes #{test_case[:name]}" do
        input = test_case[:input]
        result = XXH::XXH3.hash(input)
        expected = LibXXH.XXH3_64bits(input.to_unsafe, input.size)
        result.should eq(expected)
      end
    end
  end

  describe "One-Shot Hashing - Long Inputs (>240 bytes)" do
    [
      {name: "241 bytes", input: Bytes.new(241) { |i| (i % 256).to_u8 }},
      {name: "1024 bytes", input: Bytes.new(1024) { |i| (i % 256).to_u8 }},
      {name: "4096 bytes", input: Bytes.new(4096) { |i| (i % 256).to_u8 }},
    ].each do |test_case|
      it "hashes #{test_case[:name]}" do
        input = test_case[:input]
        result = XXH::XXH3.hash(input)
        expected = LibXXH.XXH3_64bits(input.to_unsafe, input.size)
        result.should eq(expected)
      end
    end
  end

  describe "One-Shot Hashing - With Seed" do
    it "hashes with seed 0" do
      input = "test".to_slice
      result = XXH::XXH3.hash_with_seed(input, 0_u64)
      expected = LibXXH.XXH3_64bits(input.to_unsafe, input.size)
      result.should eq(expected)
    end

    it "hashes with seed 42" do
      input = "test".to_slice
      seed = 42_u64
      result = XXH::XXH3.hash_with_seed(input, seed)
      expected = LibXXH.XXH3_64bits_withSeed(input.to_unsafe, input.size, seed)
      result.should eq(expected)
    end

    it "hashes with various seeds" do
      input = "hello".to_slice
      [1_u64, 100_u64, 0xFFFFFFFFFFFFFFFF_u64].each do |seed|
        result = XXH::XXH3.hash_with_seed(input, seed)
        expected = LibXXH.XXH3_64bits_withSeed(input.to_unsafe, input.size, seed)
        result.should eq(expected), "Failed for seed #{seed}"
      end
    end
  end

  describe "Streaming API - Single Update" do
    it "produces same hash as one-shot for small input" do
      input = "hello".to_slice
      expected = XXH::XXH3.hash(input)

      state = XXH::XXH3.new_state
      state.update(input)
      result = state.digest
      result.should eq(expected)
    end

    it "produces same hash as one-shot for medium input" do
      input = Bytes.new(100) { |i| (i % 256).to_u8 }
      expected = XXH::XXH3.hash(input)

      state = XXH::XXH3.new_state
      state.update(input)
      result = state.digest
      result.should eq(expected)
    end

    it "produces same hash as one-shot for large input" do
      input = Bytes.new(4096) { |i| (i % 256).to_u8 }
      expected = XXH::XXH3.hash(input)

      state = XXH::XXH3.new_state
      state.update(input)
      result = state.digest
      result.should eq(expected)
    end

    it "works with seed in streaming mode" do
      input = "test".to_slice
      seed = 42_u64
      expected = XXH::XXH3.hash_with_seed(input, seed)

      state = XXH::XXH3.new_state(seed)
      state.update(input)
      result = state.digest
      result.should eq(expected)
    end
  end

  describe "Streaming API - Multiple Updates" do
    it "handles two updates" do
      input1 = "hello".to_slice
      input2 = "world".to_slice
      combined = input1 + input2
      expected = XXH::XXH3.hash(combined)

      state = XXH::XXH3.new_state
      state.update(input1)
      state.update(input2)
      result = state.digest
      result.should eq(expected)
    end

    it "handles many small updates" do
      input = Bytes.new(100) { |i| (i % 256).to_u8 }
      expected = XXH::XXH3.hash(input)

      state = XXH::XXH3.new_state
      input.each_with_index do |_, i|
        state.update(Bytes.new(1) { input[i] })
      end
      result = state.digest
      result.should eq(expected)
    end
  end

  describe "Streaming API - Reset" do
    it "can reset state for new hash" do
      input1 = "hello".to_slice
      input2 = "world".to_slice

      state = XXH::XXH3.new_state
      state.update(input1)
      result1 = state.digest

      state.reset
      state.update(input2)
      result2 = state.digest

      expected1 = XXH::XXH3.hash(input1)
      expected2 = XXH::XXH3.hash(input2)

      result1.should eq(expected1)
      result2.should eq(expected2)
    end

    it "can reset with new seed" do
      input = "test".to_slice

      state = XXH::XXH3.new_state(0_u64)
      state.update(input)
      result1 = state.digest

      state.reset(42_u64)
      state.update(input)
      result2 = state.digest

      expected1 = XXH::XXH3.hash_with_seed(input, 0_u64)
      expected2 = XXH::XXH3.hash_with_seed(input, 42_u64)

      result1.should eq(expected1)
      result2.should eq(expected2)
    end
  end

  describe "Streaming API - Empty Input" do
    it "handles empty input in streaming mode" do
      state = XXH::XXH3.new_state
      state.update(Bytes.new(0))
      result = state.digest
      expected = XXH::XXH3.hash(Bytes.new(0))
      result.should eq(expected)
    end
  end
end
