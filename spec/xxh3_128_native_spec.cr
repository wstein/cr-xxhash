require "spec"
require "../src/xxh/primitives.cr"
require "../src/xxh/common.cr"
require "../src/xxh/dispatch.cr"
require "../src/xxh/xxh64.cr"
require "../src/xxh/xxh3.cr"
require "../src/ffi/bindings.cr"

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
end
