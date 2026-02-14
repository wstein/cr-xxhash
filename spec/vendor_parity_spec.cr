require "./spec_helper"

describe "Vendor-parity & extended vectors" do
  sizes = [0, 1, 2, 3, 4, 5, 7, 8, 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 128, 129, 240]

  describe "XXH32 extensive parity" do
    it "matches LibXXH and public API for many sizes and seeds" do
      seeds = [0_u32, 0x9e3779b1_u32, 0xFFFFFFFF_u32]
      sizes.each do |n|
        data = incremental_bytes(n)
        seeds.each do |seed|
          expected = LibXXH.XXH32(data.to_slice.to_unsafe, data.size, seed)
          XXH::Bindings::XXH32.hash(data, seed).should eq(expected)
          XXH::XXH32.hash(data, seed).should eq(expected)
        end
      end
    end
  end

  describe "XXH64 extensive parity" do
    it "matches LibXXH and public API for many sizes and seeds" do
      seeds = [0_u64, 0x9e3779b185ebca87_u64, 0xFFFFFFFFFFFFFFFF_u64]
      sizes.each do |n|
        data = incremental_bytes(n)
        seeds.each do |seed|
          expected = LibXXH.XXH64(data.to_slice.to_unsafe, data.size, seed)
          XXH::Bindings::XXH64.hash(data, seed).should eq(expected)
          XXH::XXH64.hash(data, seed).should eq(expected)
        end
      end
    end
  end

  describe "XXH3 parity (64/128)" do
    it "matches LibXXH for hash64 and hash128 over many sizes" do
      sizes.each do |n|
        data = incremental_bytes(n)

        # hash64
        expected64 = LibXXH.XXH3_64bits(data.to_slice.to_unsafe, data.size)
        XXH::Bindings::XXH3_64.hash(data).should eq(expected64)
        XXH::XXH3.hash64(data).should eq(expected64)

        # hash128
        c_hash = LibXXH.XXH3_128bits(data.to_slice.to_unsafe, data.size)
        expected128 = XXH::Hash128.new(c_hash)
        XXH::Bindings::XXH3_128.hash(data).should eq(expected128)
        XXH::XXH3.hash128(data).should eq(expected128)
      end
    end

    it "honors seeds for hash64 and hash128" do
      seeds64 = [0_u64, 1_u64, 0xFFFFFFFFFFFFFFFF_u64]
      sizes.each do |n|
        data = incremental_bytes(n)
        seeds64.each do |seed|
          lib64 = LibXXH.XXH3_64bits_withSeed(data.to_slice.to_unsafe, data.size, seed)
          XXH::Bindings::XXH3_64.hash(data, seed).should eq(lib64)
          XXH::XXH3.hash64(data, seed).should eq(lib64)

          c_hash = LibXXH.XXH3_128bits_withSeed(data.to_slice.to_unsafe, data.size, seed)
          expect_hash = XXH::Hash128.new(c_hash)
          XXH::Bindings::XXH3_128.hash(data, seed).should eq(expect_hash)
          XXH::XXH3.hash128(data, seed).should eq(expect_hash)
        end
      end
    end
  end

  describe "alignment invariants" do
    it "produces same result for different slice alignments" do
      [8, 16, 32].each do |len|
        base = incremental_bytes(len)
        ref = XXH::XXH64.hash(base)
        (0..7).each do |offset|
          buf = Bytes.new(offset + len)
          # prefix filler (alignment offset)
          offset.times { |i| buf[i] = 0_u8 }
          # copy the same payload after the prefix
          len.times { |i| buf[offset + i] = base[i] }
          slice = buf[offset, len]
          XXH::XXH64.hash(slice).should eq(ref)
        end
      end
    end
  end

  describe "seed-boundary checks" do
    it "handles seed edge values for XXH32 and XXH64" do
      data = incremental_bytes(100)
      # XXH32 seeds
      [0_u32, 1_u32, 0xFFFFFFFF_u32].each do |s32|
        XXH::XXH32.hash(data, s32).should eq(XXH::Bindings::XXH32.hash(data, s32))
      end
      # XXH64 seeds
      [0_u64, 1_u64, 0xFFFFFFFFFFFFFFFF_u64].each do |s64|
        XXH::XXH64.hash(data, s64).should eq(XXH::Bindings::XXH64.hash(data, s64))
      end
    end
  end
end
