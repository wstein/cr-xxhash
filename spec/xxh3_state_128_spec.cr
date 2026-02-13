require "spec"
require "../src/common/primitives.cr"
require "../src/common/common.cr"
require "../src/xxh64/wrapper.cr"
require "../src/xxh3/wrapper.cr"

describe "XXH3 State128 Streaming" do
  describe "Streaming API - Single Update" do
    it "produces same hash as one-shot for small input" do
      input = "hello".to_slice
      expected = XXH::XXH3.hash128(input)

      state = XXH::XXH3.new_state128
      state.update(input)
      result = state.digest
      result.should eq(expected)
    end

    it "produces same hash as one-shot for medium input" do
      input = Bytes.new(100) { |i| (i % 256).to_u8 }
      expected = XXH::XXH3.hash128(input)

      state = XXH::XXH3.new_state128
      state.update(input)
      result = state.digest
      result.should eq(expected)
    end

    it "produces same hash as one-shot for large input" do
      input = Bytes.new(4096) { |i| (i % 256).to_u8 }
      expected = XXH::XXH3.hash128(input)

      state = XXH::XXH3.new_state128
      state.update(input)
      result = state.digest
      result.should eq(expected)
    end

    it "works with seed in streaming mode" do
      input = "test".to_slice
      seed = 42_u64
      expected = XXH::XXH3.hash128_with_seed(input, seed)

      state = XXH::XXH3.new_state128(seed)
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
      expected = XXH::XXH3.hash128(combined)

      state = XXH::XXH3.new_state128
      state.update(input1)
      state.update(input2)
      result = state.digest
      result.should eq(expected)
    end

    it "handles many small updates" do
      input = Bytes.new(100) { |i| (i % 256).to_u8 }
      expected = XXH::XXH3.hash128(input)

      state = XXH::XXH3.new_state128
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

      state = XXH::XXH3.new_state128
      state.update(input1)
      result1 = state.digest

      state.reset
      state.update(input2)
      result2 = state.digest

      expected1 = XXH::XXH3.hash128(input1)
      expected2 = XXH::XXH3.hash128(input2)

      result1.should eq(expected1)
      result2.should eq(expected2)
    end

    it "can reset with new seed" do
      input = "test".to_slice

      state = XXH::XXH3.new_state128(0_u64)
      state.update(input)
      result1 = state.digest

      state.reset(42_u64)
      state.update(input)
      result2 = state.digest

      expected1 = XXH::XXH3.hash128_with_seed(input, 0_u64)
      expected2 = XXH::XXH3.hash128_with_seed(input, 42_u64)

      result1.should eq(expected1)
      result2.should eq(expected2)
    end
  end

  describe "Streaming API - Empty Input" do
    it "handles empty input in streaming mode" do
      state = XXH::XXH3.new_state128
      state.update(Bytes.new(0))
      result = state.digest
      expected = XXH::XXH3.hash128(Bytes.new(0))
      result.should eq(expected)
    end
  end

  describe "Hash128#to_u128" do
    it "converts to UInt128 correctly" do
      h = XXH::XXH3::Hash128.new(0x0123456789ABCDEF_u64, 0xFEDCBA9876543210_u64)
      h.to_u128.should be_a(UInt128)
      # Implementation: (high64 << 64) | low64
      h.to_u128.should eq(0x0123456789ABCDEF_u128 | (0xFEDCBA9876543210_u128 << 64))
    end

    it "works with zero values" do
      h = XXH::XXH3::Hash128.new(0_u64, 0_u64)
      h.to_u128.should eq(0_u128)
    end

    it "works with max UInt64 values" do
      h = XXH::XXH3::Hash128.new(UInt64::MAX, UInt64::MAX)
      h.to_u128.should eq(UInt128::MAX)
    end
  end
end
