require "spec"
require "../src/xxh/primitives.cr"
require "../src/xxh/common.cr"
require "../src/xxh/dispatch.cr"
require "../src/xxh/xxh64.cr"
require "../src/xxh/xxh3.cr"

describe "XXH3 Native Implementation" do
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
