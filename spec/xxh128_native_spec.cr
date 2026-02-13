require "spec"
require "../src/vendor/bindings"
require "../src/common/primitives.cr"
require "../src/xxh3/wrapper.cr"

describe "XXH128 Dispatch (XXH3-based)" do
  describe "Streamed hashing via FFI oracle" do
    it "matches streaming digest for large input" do
      input = Bytes.new(65536) { |i| (i % 256).to_u8 }

      # Oracle streaming via centralized LibXXH helper
      expected = XXH::XXH3.hash128_stream(input)

      # One-shot via direct XXH3 API should match
      result = XXH::XXH3.hash128(input).to_tuple
      result.should eq({expected.low64, expected.high64})
    end
  end
end
