require "spec"
require "../src/vendor/bindings"
require "../src/common/primitives.cr"
require "../src/dispatch.cr"
require "../src/xxh3/xxh3.cr"

describe "XXH128 Dispatch (XXH3-based)" do
  describe "Streamed hashing via FFI oracle" do
    it "matches streaming digest for large input" do
      input = Bytes.new(65536) { |i| (i % 256).to_u8 }

      # Oracle streaming via centralized LibXXH helper
      expected = XXH::XXH3.hash128_stream(input)

      # One-shot via dispatch should match
      result = XXH::Dispatch.hash_xxh128(input, 0_u64)
      result.should eq({expected.low64, expected.high64})
    end
  end
end
