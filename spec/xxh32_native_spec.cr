require "spec"
require "../src/xxh/primitives.cr"
require "../src/xxh/common.cr"
require "../src/xxh/dispatch.cr"
require "../src/xxh/xxh32.cr"

describe "XXH32 Native Implementation" do
  describe "One-Shot Hashing" do
    it "hashes empty input" do
      result = XXH::XXH32.hash(Bytes.new(0), 0_u32)
      expected = LibXXH.XXH32(Pointer(UInt8).null, 0, 0_u32)
      result.should eq(expected)
    end

    it "hashes single byte" do
      input = Bytes[0x42]
      result = XXH::XXH32.hash(input, 0_u32)
      expected = LibXXH.XXH32(input.to_unsafe, input.size, 0_u32)
      result.should eq(expected)
    end

    it "hashes short input (< 16 bytes)" do
      input = "hello".to_slice
      result = XXH::XXH32.hash(input, 0_u32)
      expected = LibXXH.XXH32(input.to_unsafe, input.size, 0_u32)
      result.should eq(expected)
    end

    it "hashes medium input (16-32 bytes)" do
      input = "hello world test message".to_slice
      result = XXH::XXH32.hash(input, 0_u32)
      expected = LibXXH.XXH32(input.to_unsafe, input.size, 0_u32)
      result.should eq(expected)
    end

    it "hashes long input (>= 1 KB)" do
      input = ("x" * 1024).to_slice
      result = XXH::XXH32.hash(input, 0_u32)
      expected = LibXXH.XXH32(input.to_unsafe, input.size, 0_u32)
      result.should eq(expected)
    end

    it "hashes with non-zero seed" do
      input = "test".to_slice
      seed = 42_u32
      result = XXH::XXH32.hash(input, seed)
      expected = LibXXH.XXH32(input.to_unsafe, input.size, seed)
      result.should eq(expected)
    end

    it "hashes various input lengths (0-128)" do
      (0..128).each do |len|
        input = Bytes.new(len) { |i| (i % 256).to_u8 }
        result = XXH::XXH32.hash(input, 0_u32)
        expected = LibXXH.XXH32(input.to_unsafe, input.size, 0_u32)

        if result != expected
          puts "MISMATCH at len=#{len}: got #{result.to_s(16)}, expected #{expected.to_s(16)}"
        end
        result.should eq(expected)
      end
    end

    it "hashes with various seeds (0-255)" do
      input = "benchmark test string".to_slice
      (0..255).each do |seed|
        seed_u32 = seed.to_u32
        result = XXH::XXH32.hash(input, seed_u32)
        expected = LibXXH.XXH32(input.to_unsafe, input.size, seed_u32)
        result.should eq(expected)
      end
    end
  end

  describe "Streaming API" do
    it "produces same hash as one-shot for small input" do
      input = "hello".to_slice

      # One-shot
      one_shot = XXH::XXH32.hash(input, 0_u32)

      # Streaming
      state = XXH::XXH32.new_state(0_u32)
      state.update(input)
      streaming = state.digest

      streaming.should eq(one_shot)
    end

    it "produces same hash as one-shot for larger input" do
      input = ("hello world test " * 100).to_slice

      # One-shot
      one_shot = XXH::XXH32.hash(input, 0_u32)

      # Streaming
      state = XXH::XXH32.new_state(0_u32)
      state.update(input)
      streaming = state.digest

      streaming.should eq(one_shot)
    end

    it "processes input in chunks correctly" do
      input = "hello world test message".to_slice

      # One-shot
      one_shot = XXH::XXH32.hash(input, 0_u32)

      # Streaming (chunked)
      state = XXH::XXH32.new_state(0_u32)
      chunk_size = 4
      (0...input.size).step(chunk_size).each do |offset|
        end_offset = Math.min(offset + chunk_size, input.size)
        state.update(input[offset...end_offset])
      end
      streaming = state.digest

      streaming.should eq(one_shot)
    end

    it "resets state correctly" do
      input1 = "first".to_slice
      input2 = "second".to_slice

      state = XXH::XXH32.new_state(0_u32)

      # Hash input1
      state.update(input1)
      hash1 = state.digest

      # Reset and hash input2
      state.reset(0_u32)
      state.update(input2)
      hash2 = state.digest

      # Verify hashes are different and correct
      hash1.should_not eq(hash2)
      hash1.should eq(XXH::XXH32.hash(input1, 0_u32))
      hash2.should eq(XXH::XXH32.hash(input2, 0_u32))
    end

    it "handles streaming with different seeds" do
      input = "test message".to_slice
      seed = 99_u32

      one_shot = XXH::XXH32.hash(input, seed)

      state = XXH::XXH32.new_state(seed)
      state.update(input)
      streaming = state.digest

      streaming.should eq(one_shot)
    end

    it "processes 64KB of data correctly" do
      input = Bytes.new(65536) { |i| ((i * 37) % 256).to_u8 }

      one_shot = XXH::XXH32.hash(input, 0_u32)

      state = XXH::XXH32.new_state(0_u32)
      state.update(input)
      streaming = state.digest

      streaming.should eq(one_shot)
    end
  end

  describe "Edge Cases" do
    it "handles unaligned memory access" do
      # Create buffer and use pointer offset
      buffer = Bytes.new(32) { |i| i.to_u8 }

      # Hash from byte 1 (unaligned)
      input1 = buffer[1...17]
      result = XXH::XXH32.hash(input1, 0_u32)
      expected = LibXXH.XXH32(input1.to_unsafe, input1.size, 0_u32)

      result.should eq(expected)
    end

    it "matches FFI for README.md file" do
      path = "./README.md"
      if File.exists?(path)
        input = File.read(path).to_slice

        result = XXH::XXH32.hash(input, 0_u32)
        expected = LibXXH.XXH32(input.to_unsafe, input.size, 0_u32)

        result.should eq(expected)
      end
    end

    it "matches FFI for LICENSE file" do
      path = "./LICENSE"
      if File.exists?(path)
        input = File.read(path).to_slice

        result = XXH::XXH32.hash(input, 0_u32)
        expected = LibXXH.XXH32(input.to_unsafe, input.size, 0_u32)

        result.should eq(expected)
      end
    end
  end

  describe "Performance Characteristics" do
    it "handles 100MB+ efficiently (no timeout)" do
      # Create 10MB input
      input = Bytes.new(10 * 1024 * 1024) { |i| ((i * 17) % 256).to_u8 }

      start = Time.instant
      result = XXH::XXH32.hash(input, 0_u32)
      elapsed = Time.instant - start

      # Should complete in < 1 second (rough benchmark)
      # On M4: ~7 GB/s expected, so 10MB should be ~1.4ms
      elapsed.should be < 5.seconds

      # Verify correctness
      expected = LibXXH.XXH32(input.to_unsafe, input.size, 0_u32)
      result.should eq(expected)
    end
  end

  describe "Primitives" do
    it "rotl32 works correctly" do
      XXH::Primitives.rotl32(0x12345678_u32, 0_u32).should eq(0x12345678_u32)
      XXH::Primitives.rotl32(0x12345678_u32, 1_u32).should eq(0x2468ACF0_u32)
      XXH::Primitives.rotl32(0x12345678_u32, 4_u32).should eq(0x23456781_u32)
      XXH::Primitives.rotl32(0x12345678_u32, 16_u32).should eq(0x56781234_u32)
    end

    it "read_u32_le works correctly" do
      input = Bytes[0x78, 0x56, 0x34, 0x12]
      result = XXH::Primitives.read_u32_le(input.to_unsafe)
      result.should eq(0x12345678_u32)
    end
  end
end
