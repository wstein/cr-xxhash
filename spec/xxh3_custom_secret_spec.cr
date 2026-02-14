require "spec"
require "../src/common/buffers.cr"
require "../src/xxh3/wrapper.cr"

require "../src/vendor/bindings"

describe "XXH3 custom secret helper" do
  it "seeds the default secret correctly for non-zero seed" do
    dest = Bytes.new(LibXXH::XXH3_SECRET_DEFAULT_SIZE, 0)
    secret = XXH::Buffers.default_secret.as(Bytes)
    seed = 42_u64

    # Use public helper to initialize the custom secret from seed
    XXH::XXH3.init_custom_secret(dest.to_unsafe, secret.to_unsafe, secret.size, seed)

    # Compute expected result using FFI directly (the same way vendor does it)
    expected = Bytes.new(secret.size, 0)
    expected.copy_from(secret)
    LibXXH.XXH3_generateSecret_fromSeed(expected.to_unsafe, seed)

    dest.to_a.should eq(expected.to_a)
  end

  it "produces identical bytes when seed is zero" do
    dest = Bytes.new(LibXXH::XXH3_SECRET_DEFAULT_SIZE, 0)
    secret = XXH::Buffers.default_secret.as(Bytes)

    XXH::XXH3.init_custom_secret(dest.to_unsafe, secret.to_unsafe, secret.size, 0_u64)

    # With seed=0, result should equal the original secret
    dest.to_a.should eq(secret.to_a)
  end
end
