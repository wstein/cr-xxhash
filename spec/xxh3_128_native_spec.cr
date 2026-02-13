require "spec"

describe "XXH3 128-bit (FFI-backed)" do
  it "returns a 128-bit tuple for example input" do
    input = "test".to_slice
    result = XXH::XXH3.hash128(input).to_tuple
    result.should be_a(Tuple(UInt64, UInt64))
  end
end
