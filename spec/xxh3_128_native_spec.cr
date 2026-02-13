require "spec"
require "../src/xxh/dispatch.cr"

describe "XXH3 128-bit (FFI-backed)" do
  it "returns a 128-bit tuple for example input" do
    input = "test".to_slice
    result = XXH::Dispatch.hash_xxh128(input, 0_u64)
    result.should be_a(Tuple(UInt64, UInt64))
  end
end
