require "../spec_helper"

describe "Alignment & SIMD Path Coverage" do
  describe "XXH32 alignment invariants" do
    it "produces identical hashes for aligned and unaligned buffers (various sizes)" do
      [8, 16, 32, 64, 128, 256, 512].each do |size|
        data = incremental_bytes(size)
        ref = XXH::XXH32.hash(data)

        # Test with offsets 0..7 to simulate unaligned access
        (0..7).each do |offset|
          buf = Bytes.new(offset + size)
          offset.times { |i| buf[i] = 0_u8 }
          size.times { |i| buf[offset + i] = data[i] }
          slice = buf[offset, size]
          result = XXH::XXH32.hash(slice)
          result.should eq(ref), "Alignment offset #{offset} with size #{size} produced different hash"
        end
      end
    end

    it "handles 4-byte boundary alignment" do
      sizes = [4, 8, 12, 16, 20, 24, 28, 32]
      seeds = [0_u32, 1_u32, 0xFFFFFFFF_u32]
      
      sizes.each do |size|
        data = incremental_bytes(size)
        seeds.each do |seed|
          ref = XXH::XXH32.hash(data, seed)
          
          # Test offset by 1, 2, 3 bytes (crosses 4-byte boundary)
          [1, 2, 3].each do |offset|
            buf = Bytes.new(offset + size)
            offset.times { |i| buf[i] = 0_u8 }
            size.times { |i| buf[offset + i] = data[i] }
            slice = buf[offset, size]
            result = XXH::XXH32.hash(slice, seed)
            result.should eq(ref), "4-byte boundary misalignment at offset #{offset} with size #{size} seed #{seed.to_s(16)}"
          end
        end
      end
    end
  end

  describe "XXH64 alignment invariants" do
    it "produces identical hashes for aligned and unaligned 8-byte boundaries" do
      [8, 16, 24, 32, 64, 128, 256, 512].each do |size|
        data = incremental_bytes(size)
        ref = XXH::XXH64.hash(data)

        (0..7).each do |offset|
          buf = Bytes.new(offset + size)
          offset.times { |i| buf[i] = 0_u8 }
          size.times { |i| buf[offset + i] = data[i] }
          slice = buf[offset, size]
          result = XXH::XXH64.hash(slice)
          result.should eq(ref), "XXH64 alignment offset #{offset} size #{size} mismatch"
        end
      end
    end

    it "handles 8-byte boundary misalignment with various seeds" do
      size = 64
      data = incremental_bytes(size)
      seeds = [0_u64, 1_u64, 0xFFFFFFFFFFFFFFFF_u64]

      seeds.each do |seed|
        ref = XXH::XXH64.hash(data, seed)
        
        [1, 3, 5, 7].each do |offset|
          buf = Bytes.new(offset + size)
          offset.times { |i| buf[i] = 0_u8 }
          size.times { |i| buf[offset + i] = data[i] }
          slice = buf[offset, size]
          result = XXH::XXH64.hash(slice, seed)
          result.should eq(ref), "XXH64 8-byte misalignment offset #{offset}"
        end
      end
    end
  end

  describe "XXH3 64-bit alignment & SIMD paths" do
    # XXH3 has distinct size-class paths:
    # - 0-16B: no SIMD
    # - 17-240B: medium SIMD (stripe processing)
    # - 240B+: long SIMD (vectorized accumulators)
    
    it "maintains alignment invariants across all size classes" do
      # Test representative sizes from each path
      test_sizes = [
        1, 8, 16,          # Short path (0-16B)
        17, 64, 128, 240,  # Medium path (17-240B)
        241, 512, 1024     # Long path (240B+)
      ]
      
      test_sizes.each do |size|
        data = incremental_bytes(size)
        ref = XXH::XXH3.hash64(data)
        
        (0..7).each do |offset|
          buf = Bytes.new(offset + size)
          offset.times { |i| buf[i] = 0_u8 }
          size.times { |i| buf[offset + i] = data[i] }
          slice = buf[offset, size]
          result = XXH::XXH3.hash64(slice)
          result.should eq(ref), "XXH3_64 size-class #{size} offset #{offset} mismatch"
        end
      end
    end

    it "handles size-class boundary transitions (16B→17B, 240B→241B)" do
      boundaries = [
        {size: 16, next_size: 17},     # Short to medium
        {size: 240, next_size: 241}    # Medium to long
      ]
      
      boundaries.each do |boundary|
        size = boundary[:size]
        next_size = boundary[:next_size]
        
        data1 = incremental_bytes(size)
        data2 = incremental_bytes(next_size)
        
        hash1 = XXH::XXH3.hash64(data1)
        hash2 = XXH::XXH3.hash64(data2)
        
        # Hashes should differ (sanity check)
        hash1.should_not eq(hash2)
        
        # Both should work with unaligned access
        [1, 3, 5, 7].each do |offset|
          buf1 = Bytes.new(offset + size)
          size.times { |i| buf1[offset + i] = data1[i] }
          result1 = XXH::XXH3.hash64(buf1[offset, size])
          result1.should eq(hash1), "Unaligned hash at boundary size #{size} offset #{offset}"
          
          buf2 = Bytes.new(offset + next_size)
          next_size.times { |i| buf2[offset + i] = data2[i] }
          result2 = XXH::XXH3.hash64(buf2[offset, next_size])
          result2.should eq(hash2), "Unaligned hash at boundary size #{next_size} offset #{offset}"
        end
      end
    end
  end

  describe "XXH3 128-bit alignment & SIMD paths" do
    it "maintains alignment invariants across all size classes (128-bit)" do
      test_sizes = [
        1, 8, 16,          # Short path (0-16B)
        17, 64, 128, 240,  # Medium path (17-240B)
        241, 512, 1024     # Long path (240B+)
      ]
      
      test_sizes.each do |size|
        data = incremental_bytes(size)
        ref = XXH::XXH3.hash128(data)
        
        (0..7).each do |offset|
          buf = Bytes.new(offset + size)
          offset.times { |i| buf[i] = 0_u8 }
          size.times { |i| buf[offset + i] = data[i] }
          slice = buf[offset, size]
          result = XXH::XXH3.hash128(slice)
          result.should eq(ref), "XXH3_128 size-class #{size} offset #{offset} mismatch"
        end
      end
    end
  end

  describe "Alignment with streaming APIs" do
    it "streaming state produces same result as one-shot regardless of update boundaries" do
      data = incremental_bytes(512)
      one_shot = XXH::XXH64.hash(data)
      
      # Multiple ways to update the streaming state
      [
        [256, 256],        # 2 x 256B
        [128, 128, 256],   # 128+128+256
        [1, 255, 256],     # Various sizes
        [64, 64, 64, 64, 64, 64, 64, 64]  # 8 x 64B
      ].each do |chunk_sizes|
        state = XXH::XXH64::State.new
        offset = 0
        chunk_sizes.each do |chunk_size|
          slice = data[offset, chunk_size]
          state.update(slice)
          offset += chunk_size
        end
        result = state.digest
        result.should eq(one_shot), "Streaming with chunks #{chunk_sizes.inspect} produced different result"
      end
    end

    it "XXH3 streaming respects alignment across size-class transitions" do
      # Large data that crosses size-class boundaries
      data = incremental_bytes(512)
      one_shot = XXH::XXH3.hash64(data)
      
      # Update at boundaries
      state = XXH::XXH3::State64.new
      state.update(data[0, 16])    # Short path
      state.update(data[16, 224])  # Medium path to 240B
      state.update(data[240, 272]) # Long path
      result = state.digest
      result.should eq(one_shot)
    end
  end

  describe "Vendor vector alignment invariants" do
    it "all XXH32 vendor vectors pass alignment checks" do
      TEST_VECTORS_XXH32.each do |(input, seed), expected|
        input_bytes = input.to_slice
        # Test with various alignments
        (0..7).each do |offset|
          buf = Bytes.new(offset + input_bytes.size)
          offset.times { |i| buf[i] = 0_u8 }
          input_bytes.size.times { |i| buf[offset + i] = input_bytes[i] }
          slice = buf[offset, input_bytes.size]
          result = XXH::XXH32.hash(slice, seed)
          result.should eq(expected), "Vendor XXH32 vector alignment offset #{offset} mismatch"
        end
      end
    end

    it "all XXH64 vendor vectors pass alignment checks" do
      TEST_VECTORS_XXH64.each do |(input, seed), expected|
        input_bytes = input.to_slice
        (0..7).each do |offset|
          buf = Bytes.new(offset + input_bytes.size)
          offset.times { |i| buf[i] = 0_u8 }
          input_bytes.size.times { |i| buf[offset + i] = input_bytes[i] }
          slice = buf[offset, input_bytes.size]
          result = XXH::XXH64.hash(slice, seed)
          result.should eq(expected), "Vendor XXH64 vector alignment offset #{offset} mismatch"
        end
      end
    end

    it "all XXH3 64-bit vendor vectors pass alignment checks" do
      TEST_VECTORS_XXH3_64.each do |(input, seed), expected|
        input_bytes = input.to_slice
        (0..7).each do |offset|
          buf = Bytes.new(offset + input_bytes.size)
          offset.times { |i| buf[i] = 0_u8 }
          input_bytes.size.times { |i| buf[offset + i] = input_bytes[i] }
          slice = buf[offset, input_bytes.size]
          result = XXH::XXH3.hash64(slice, seed)
          result.should eq(expected), "Vendor XXH3_64 vector alignment offset #{offset} mismatch"
        end
      end
    end

    it "all XXH3 128-bit vendor vectors pass alignment checks" do
      TEST_VECTORS_XXH3_128.each do |(input, seed), (expected_high, expected_low)|
        input_bytes = input.to_slice
        (0..7).each do |offset|
          buf = Bytes.new(offset + input_bytes.size)
          offset.times { |i| buf[i] = 0_u8 }
          input_bytes.size.times { |i| buf[offset + i] = input_bytes[i] }
          slice = buf[offset, input_bytes.size]
          result = XXH::XXH3.hash128(slice, seed)
          result.high64.should eq(expected_high), "Vendor XXH3_128 high64 alignment offset #{offset} mismatch"
          result.low64.should eq(expected_low), "Vendor XXH3_128 low64 alignment offset #{offset} mismatch"
        end
      end
    end
  end

  describe "Alignment edge cases" do
    it "handles single-byte reads across misaligned boundaries" do
      data = Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
      
      (0..7).each do |offset|
        if offset + 1 <= data.size
          slice = data[offset, 1]
          hash32 = XXH::XXH32.hash(slice)
          hash64 = XXH::XXH64.hash(slice)
          hash3_64 = XXH::XXH3.hash64(slice)
          
          # Just verify they produce consistent results
          hash32.should be_a(UInt32)
          hash64.should be_a(UInt64)
          hash3_64.should be_a(UInt64)
        end
      end
    end

    it "buffers with leading/trailing padding do not affect hash" do
      core_data = incremental_bytes(100)
      ref = XXH::XXH64.hash(core_data)
      
      padding_sizes = [1, 3, 7, 15]
      padding_sizes.each do |pad_size|
        buf = Bytes.new(pad_size + core_data.size)
        core_data.size.times { |i| buf[pad_size + i] = core_data[i] }
        result = XXH::XXH64.hash(buf[pad_size, core_data.size])
        result.should eq(ref), "Padding #{pad_size} affected hash"
      end
    end
  end

  describe "SIMD path confidence (size-class coverage)" do
    it "verifies XXH3 uses appropriate paths for all tested sizes" do
      # This test documents which size classes should be used
      # (actual SIMD usage depends on CPU; test just verifies determinism)
      
      {
        0..16 => "short (0-16B path)",
        17..240 => "medium (17-240B path with stripes)",
        241..4096 => "long (240B+ path with accumulators)"
      }.each do |range, path_name|
        range.each do |size|
          next if size > 1024  # Limit iteration for performance
          
          data = incremental_bytes(size)
          hash1 = XXH::XXH3.hash64(data)
          hash2 = XXH::XXH3.hash64(data)
          
          # Deterministic: same input → same output
          hash1.should eq(hash2), "XXH3 #{path_name} size #{size} non-deterministic"
          
          # Verified: unaligned access gives same result
          buf = Bytes.new(1 + size)
          size.times { |i| buf[1 + i] = data[i] }
          hash_unaligned = XXH::XXH3.hash64(buf[1, size])
          hash_unaligned.should eq(hash1), "XXH3 #{path_name} size #{size} unaligned mismatch"
        end
      end
    end
  end
end
