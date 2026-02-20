require "spec"
require "../src/bindings/lib_xxh"

describe "FFI Bindings Smoke Test" do
  it "can call XXH32 C function directly" do
    input = "test".to_slice
    hash = LibXXH.XXH32(input.to_unsafe, input.size, 0_u32)
    hash.should be_a(UInt32)
    hash.should_not eq(0_u32)
  end

  it "can call XXH64 C function directly" do
    input = "test".to_slice
    hash = LibXXH.XXH64(input.to_unsafe, input.size, 0_u64)
    hash.should be_a(UInt64)
    hash.should_not eq(0_u64)
  end

  it "can call XXH3_64bits C function directly" do
    input = "test".to_slice
    hash = LibXXH.XXH3_64bits(input.to_unsafe, input.size)
    hash.should be_a(UInt64)
    hash.should_not eq(0_u64)
  end

  it "can call XXH3_128bits C function directly" do
    input = "test".to_slice
    hash = LibXXH.XXH3_128bits(input.to_unsafe, input.size)
    hash.low.should be_a(UInt64)
    hash.high.should be_a(UInt64)
  end

  it "reports correct library version" do
    version = LibXXH.versionNumber
    version.should be > 0_u32
    # xxHash version format: 0xMMmmpp (Major.minor.patch)
    # Example: 0.8.2 = 0x000802
    (version >> 16).should be >= 0 # Major version >= 0
  end
end
