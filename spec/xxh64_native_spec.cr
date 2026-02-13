require "spec"
require "../src/common/primitives.cr"
require "../src/common/common.cr"
require "../src/dispatch.cr"
require "../src/xxh64/xxh64.cr"

describe "XXH64 Native Implementation" do
  describe "Streaming API" do
    it "produces same hash as one-shot for small input" do
      input = "hello".to_slice

      # One-shot
      expected = XXH::XXH64.hash(input)

      # Streaming
      state = XXH::XXH64.new_state
      state.update(input)
      result = state.digest

      result.should eq(expected)
    end

    it "produces same hash for chunked input" do
      input = ("chunk" * 100).to_slice
      expected = XXH::XXH64.hash(input)

      # Process in 17-byte chunks
      state = XXH::XXH64.new_state
      offset = 0
      while offset < input.size
        chunk_size = Math.min(17, input.size - offset)
        state.update(input[offset, chunk_size])
        offset += chunk_size
      end
      result = state.digest

      result.should eq(expected)
    end

    it "allows state reset" do
      state = XXH::XXH64.new_state(42_u64)
      state.update("first".to_slice)
      state.reset(0_u64)
      state.update("test".to_slice)

      expected = XXH::XXH64.hash("test".to_slice, 0_u64)
      result = state.digest

      result.should eq(expected)
    end

    it "handles large 64KB buffer" do
      input = Bytes.new(65536) { |i| (i % 256).to_u8 }
      expected = XXH::XXH64.hash(input)

      state = XXH::XXH64.new_state
      state.update(input)
      result = state.digest

      result.should eq(expected)
    end
  end

  describe "Edge Cases" do
    it "handles unaligned memory access" do
      buffer = Bytes.new(50)
      (0...50).each { |i| buffer[i] = (i % 256).to_u8 }

      # Test with offset +1 (unaligned)
      input = buffer[1, 20]
      result = XXH::XXH64.hash(input)
      expected = LibXXH.XXH64(input.to_unsafe, input.size, 0_u64)

      result.should eq(expected)
    end

    it "matches FFI for README.md file" do
      file_path = File.expand_path("../README.md", __DIR__)
      if File.exists?(file_path)
        data = File.read(file_path).to_slice
        result = XXH::XXH64.hash(data)
        expected = LibXXH.XXH64(data.to_unsafe, data.size, 0_u64)
        result.should eq(expected)
      end
    end

    it "matches FFI for LICENSE file" do
      file_path = File.expand_path("../LICENSE", __DIR__)
      if File.exists?(file_path)
        data = File.read(file_path).to_slice
        result = XXH::XXH64.hash(data)
        expected = LibXXH.XXH64(data.to_unsafe, data.size, 0_u64)
        result.should eq(expected)
      end
    end
  end

  describe "Performance Characteristics" do
    it "handles large input efficiently" do
      input = Bytes.new(1_000_000) { |i| (i % 256).to_u8 }
      expected = LibXXH.XXH64(input.to_unsafe, input.size, 0_u64)

      result = XXH::XXH64.hash(input)
      result.should eq(expected)
    end
  end
end
