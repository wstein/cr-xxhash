require "spec"
require "../src/xxh/primitives.cr"
require "../src/xxh/common.cr"
require "../src/xxh/dispatch.cr"
require "../src/xxh/xxh64.cr"
require "../src/xxh/xxh3.cr"

describe "XXH3 128-bit Native Implementation" do
  describe "Phase 1: Simple Paths (0-16 bytes)" do
    it "handles empty input (0 bytes)" do
      input = Bytes.new(0)
      result = XXH::XXH3.hash128(input)
      ffi_result = LibXXH.XXH3_128bits(input.to_unsafe, 0)

      result.low64.should eq(ffi_result.low64)
      result.high64.should eq(ffi_result.high64)
    end

    it "handles 1-byte input" do
      input = "x".encode("UTF-8")
      result = XXH::XXH3.hash128(input)
      ffi_result = LibXXH.XXH3_128bits(input.to_unsafe, 1)

      result.low64.should eq(ffi_result.low64)
      result.high64.should eq(ffi_result.high64)
    end

    it "handles 3-byte input (1-3 range)" do
      input = "foo".encode("UTF-8")
      result = XXH::XXH3.hash128(input)
      ffi_result = LibXXH.XXH3_128bits(input.to_unsafe, 3)

      result.low64.should eq(ffi_result.low64)
      result.high64.should eq(ffi_result.high64)
    end

    it "handles 4-byte input (4-8 range)" do
      input = "test".encode("UTF-8")
      result = XXH::XXH3.hash128(input)
      ffi_result = LibXXH.XXH3_128bits(input.to_unsafe, 4)

      result.low64.should eq(ffi_result.low64)
      result.high64.should eq(ffi_result.high64)
    end

    it "handles 8-byte input (4-8 range)" do
      input = "12345678".encode("UTF-8")
      result = XXH::XXH3.hash128(input)
      ffi_result = LibXXH.XXH3_128bits(input.to_unsafe, 8)

      result.low64.should eq(ffi_result.low64)
      result.high64.should eq(ffi_result.high64)
    end

    it "handles 9-byte input (9-16 range)" do
      input = "123456789".encode("UTF-8")
      result = XXH::XXH3.hash128(input)
      ffi_result = LibXXH.XXH3_128bits(input.to_unsafe, 9)

      result.low64.should eq(ffi_result.low64)
      result.high64.should eq(ffi_result.high64)
    end

    it "handles 16-byte input (9-16 range)" do
      input = "0123456789ABCDEF".encode("UTF-8")
      result = XXH::XXH3.hash128(input)
      ffi_result = LibXXH.XXH3_128bits(input.to_unsafe, 16)

      result.low64.should eq(ffi_result.low64)
      result.high64.should eq(ffi_result.high64)
    end

    it "handles 2-byte input (1-3 range)" do
      input = "xy".encode("UTF-8")
      result = XXH::XXH3.hash128(input)
      ffi_result = LibXXH.XXH3_128bits(input.to_unsafe, 2)

      result.low64.should eq(ffi_result.low64)
      result.high64.should eq(ffi_result.high64)
    end

    it "handles 5-byte input (4-8 range)" do
      input = "abcde".encode("UTF-8")
      result = XXH::XXH3.hash128(input)
      ffi_result = LibXXH.XXH3_128bits(input.to_unsafe, 5)

      result.low64.should eq(ffi_result.low64)
      result.high64.should eq(ffi_result.high64)
    end

    it "handles 10-byte input (9-16 range)" do
      input = "0123456789".encode("UTF-8")
      result = XXH::XXH3.hash128(input)
      ffi_result = LibXXH.XXH3_128bits(input.to_unsafe, 10)

      result.low64.should eq(ffi_result.low64)
      result.high64.should eq(ffi_result.high64)
    end
  end

  describe "Phase 2a: Medium Paths (17-128 bytes)" do
    [17, 20, 32, 48, 64, 96, 128].each do |size|
      it "handles #{size}-byte input" do
        input = Bytes.new(size) { |i| (i & 0xFF).to_u8 }
        result = XXH::XXH3.hash128(input)
        ffi_result = LibXXH.XXH3_128bits(input.to_unsafe, size)

        result.low64.should eq(ffi_result.low64)
        result.high64.should eq(ffi_result.high64)
      end
    end
  end

  describe "Phase 2b: Midsize Paths (129-240 bytes)" do
    [129, 160, 200, 240].each do |size|
      it "handles #{size}-byte input" do
        input = Bytes.new(size) { |i| (i & 0xFF).to_u8 }
        result = XXH::XXH3.hash128(input)
        ffi_result = LibXXH.XXH3_128bits(input.to_unsafe, size)

        result.low64.should eq(ffi_result.low64)
        result.high64.should eq(ffi_result.high64)
      end
    end
  end

  describe "Phase 3: Long Input Path (240+ bytes)" do
    [241, 256, 300, 512, 1024, 4096, 10000].each do |size|
      it "handles #{size}-byte input" do
        input = Bytes.new(size) { |i| (i & 0xFF).to_u8 }
        result = XXH::XXH3.hash128(input)
        ffi_result = LibXXH.XXH3_128bits(input.to_unsafe, size)

        result.low64.should eq(ffi_result.low64)
        result.high64.should eq(ffi_result.high64)
      end
    end

    it "handles 241-byte input with seed" do
      input = Bytes.new(241) { |i| (i & 0xFF).to_u8 }
      seed = 0x123456789ABCDEF0_u64
      result = XXH::XXH3.hash128_with_seed(input, seed)
      ffi_result = LibXXH.XXH3_128bits_withSeed(input.to_unsafe, 241, seed)

      result.low64.should eq(ffi_result.low64)
      result.high64.should eq(ffi_result.high64)
    end

    it "handles 512-byte input with seed" do
      input = Bytes.new(512) { |i| (i & 0xFF).to_u8 }
      seed = 0xDEADBEEF_u64
      result = XXH::XXH3.hash128_with_seed(input, seed)
      ffi_result = LibXXH.XXH3_128bits_withSeed(input.to_unsafe, 512, seed)

      result.low64.should eq(ffi_result.low64)
      result.high64.should eq(ffi_result.high64)
    end

    it "handles 10000-byte input with seed" do
      input = Bytes.new(10000) { |i| (i & 0xFF).to_u8 }
      seed = 0xCAFEBABE_u64
      result = XXH::XXH3.hash128_with_seed(input, seed)
      ffi_result = LibXXH.XXH3_128bits_withSeed(input.to_unsafe, 10000, seed)

      result.low64.should eq(ffi_result.low64)
      result.high64.should eq(ffi_result.high64)
    end
  end
end
