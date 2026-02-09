require "./spec_helper"

describe "XXH3 Streaming shared behavior" do
  it "has same basic state after updates for State and State128" do
    s64 = XXH::XXH3.new_state(123_u64)
    s128 = XXH::XXH3.new_state128(123_u64)

    bytes = Bytes.new(300, 0)
    (0...300).each { |i| bytes[i] = (i & 0xFF).to_u8 }

    s64.update(bytes)
    s128.update(bytes)

    s64.debug_state[:total_len].should eq s128.debug_state[:total_len]
    s64.debug_state[:buffered_size].should eq s128.debug_state[:buffered_size]
    s64.test_debug_secret[:use_seed].should eq s128.test_debug_secret[:use_seed]
  end

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
