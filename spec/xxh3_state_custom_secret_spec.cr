require "spec"
require "../src/xxh/primitives.cr"
require "../src/xxh/common.cr"
require "../src/xxh/xxh3.cr"

describe "XXH3 Streaming seeded secret usage" do
  it "State uses custom_secret when seeded (64-bit)" do
    seed = 42_u64
    secret = XXH::Buffers.default_secret.as(Bytes)

    expected = Bytes.new(secret.size, 0)
    XXH::XXH3.init_custom_secret(expected.to_unsafe, secret.to_unsafe, secret.size, seed)

    state = XXH::XXH3.new_state(seed)
    debug = state.test_debug_secret

    debug[:use_seed].should eq(true)
    debug[:custom_secret].should eq(expected.to_a)
    debug[:ext_secret].should be_nil
  end

  it "State128 uses custom_secret when seeded (128-bit)" do
    seed = 1337_u64
    secret = XXH::Buffers.default_secret.as(Bytes)

    expected = Bytes.new(secret.size, 0)
    XXH::XXH3.init_custom_secret(expected.to_unsafe, secret.to_unsafe, secret.size, seed)

    state = XXH::XXH3.new_state128(seed)
    debug = state.test_debug_secret

    debug[:use_seed].should eq(true)
    debug[:custom_secret].should eq(expected.to_a)
    debug[:ext_secret].should be_nil
  end
end
