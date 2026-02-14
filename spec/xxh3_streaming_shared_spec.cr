require "./spec_helper"

describe "XXH3 Streaming shared behavior" do
  it "digest for long input returns proper types" do
    bytes = Bytes.new(512, 0)
    (0...512).each { |i| bytes[i] = (i & 0xFF).to_u8 }

    s64 = XXH::XXH3.new_state
    s128 = XXH::XXH3.new_state128

    s64.update(bytes)
    s128.update(bytes)

    h64 = s64.digest
    h128 = s128.digest

    h64.is_a?(UInt64).should be_true
    h128.is_a?(XXH::XXH3::Hash128).should be_true
  end
end
