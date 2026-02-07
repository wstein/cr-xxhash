require "./spec_helper"

describe "XXH Bindings" do
  it "version_string returns proper format" do
    version_str = XXH.version_string
    # Should be in format "X.Y.Z"
    version_str.should match(/\d+\.\d+\.\d+/)
  end

  it "version number is accessible" do
    version = XXH.version
    version.should be > 0_u32
  end

  it "XXH32 one-shot hash works" do
    input = "hello world"
    hash = LibXXH.XXH32(input.bytes, input.bytesize, 0_u32)
    hash.should be > 0_u32
  end

  it "XXH64 one-shot hash works" do
    input = "hello world"
    hash = LibXXH.XXH64(input.bytes, input.bytesize, 0_u64)
    hash.should be > 0_u64
  end

  it "XXH128 one-shot hash works" do
    input = "hello world"
    hash = LibXXH.XXH128(input.bytes, input.bytesize, 0_u64)
    hash.low64.should be > 0_u64
  end

  it "Consistent hashes for same input" do
    input = "hello"
    hash1 = LibXXH.XXH64(input.bytes, input.bytesize, 0_u64)
    hash2 = LibXXH.XXH64(input.bytes, input.bytesize, 0_u64)
    hash1.should eq(hash2)
  end
end
