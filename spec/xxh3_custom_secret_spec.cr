require "spec"
require "../src/common/primitives.cr"
require "../src/common/common.cr"
require "../src/xxh3/wrapper.cr"

describe "XXH3 custom secret helper" do
  it "seeds the default secret correctly for non-zero seed" do
    dest = Bytes.new(XXH::Constants::SECRET_DEFAULT_SIZE, 0)
    secret = XXH::Buffers.default_secret.as(Bytes)
    seed = 42_u64

    XXH::XXH3.init_custom_secret(dest.to_unsafe, secret.to_unsafe, secret.size, seed)

    expected = Bytes.new(secret.size, 0)
    nrounds = secret.size / 16
    i = 0
    while i < nrounds
      lo = XXH::Primitives.read_u64_le(secret.to_unsafe + (16 * i)) &+ seed
      hi = XXH::Primitives.read_u64_le(secret.to_unsafe + (16 * i + 8)) &- seed
      XXH::Primitives.write_u64_le(expected.to_unsafe + (16 * i), lo)
      XXH::Primitives.write_u64_le(expected.to_unsafe + (16 * i + 8), hi)
      i += 1
    end

    dest.to_a.should eq(expected.to_a)
  end

  it "produces identical bytes when seed is zero" do
    dest = Bytes.new(XXH::Constants::SECRET_DEFAULT_SIZE, 0)
    secret = XXH::Buffers.default_secret.as(Bytes)

    XXH::XXH3.init_custom_secret(dest.to_unsafe, secret.to_unsafe, secret.size, 0_u64)

    dest.to_a.should eq(secret.to_a)
  end
end
