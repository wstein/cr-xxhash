require "spec"
require "../src/xxh/primitives.cr"
require "../src/xxh/common.cr"
require "../src/xxh/dispatch.cr"
require "../src/xxh/xxh64.cr"
require "../src/ffi/bindings.cr"

describe "XXH64 Native Implementation" do
  describe "One-Shot Hashing" do
    it "hashes empty input" do
      result = XXH::XXH64.hash(Bytes.new(0), 0_u64)
      expected = LibXXH.XXH64(Pointer(UInt8).null, 0, 0_u64)
      result.should eq(expected)
    end

    it "hashes single byte" do
      input = Bytes[0x42]
      result = XXH::XXH64.hash(input, 0_u64)
      expected = LibXXH.XXH64(input.to_unsafe, input.size, 0_u64)
      result.should eq(expected)
    end

    it "hashes short input (< 32 bytes)" do
      input = "hello".to_slice
      result = XXH::XXH64.hash(input, 0_u64)
      expected = LibXXH.XXH64(input.to_unsafe, input.size, 0_u64)
      result.should eq(expected)
    end

    it "hashes medium input (32-64 bytes)" do
      input = "hello world test message extra".to_slice
      result = XXH::XXH64.hash(input, 0_u64)
      expected = LibXXH.XXH64(input.to_unsafe, input.size, 0_u64)
      result.should eq(expected)
    end

    it "hashes long input (>= 1 KB)" do
      input = ("x" * 1024).to_slice
      result = XXH::XXH64.hash(input, 0_u64)
      expected = LibXXH.XXH64(input.to_unsafe, input.size, 0_u64)
      result.should eq(expected)
    end

    it "hashes with non-zero seed" do
      input = "test".to_slice
      seed = 42_u64
      result = XXH::XXH64.hash(input, seed)
      expected = LibXXH.XXH64(input.to_unsafe, input.size, seed)
      result.should eq(expected)
    end

    it "hashes various input lengths (0-128)" do
      (0..128).each do |len|
        input = Bytes.new(len) { |i| (i % 256).to_u8 }
        result = XXH::XXH64.hash(input, 0_u64)
        expected = LibXXH.XXH64(input.to_unsafe, input.size, 0_u64)

        if result != expected
          puts "MISMATCH at len=#{len}: got 0x#{result.to_s(16)}, expected 0x#{expected.to_s(16)}"
        end
        result.should eq(expected)
      end
    end

    it "hashes with various seeds (0-255)" do
      input = "benchmark test string".to_slice
      (0..255).each do |seed|
        seed_u64 = seed.to_u64
        result = XXH::XXH64.hash(input, seed_u64)
        expected = LibXXH.XXH64(input.to_unsafe, input.size, seed_u64)
        result.should eq(expected)
      end
    end
  end

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
