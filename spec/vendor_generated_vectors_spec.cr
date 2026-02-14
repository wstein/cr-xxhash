require "./spec_helper"

describe "Vendor-generated sanity vectors" do
  describe "XXH32 vendor vectors" do
    it "matches generated vendor vectors (sanity buffer)" do
      XXH::VectorLoader.xxh32_vectors.each do |(len, seed), expected|
        buf = XXH::VectorLoader.sanity_buffer(len)
        # ensure proper types for API
        XXH::XXH32.hash(buf, seed).should eq(expected)
      end
    end
  end

  describe "XXH64 vendor vectors" do
    it "matches generated vendor vectors (sanity buffer)" do
      XXH::VectorLoader.xxh64_vectors.each do |(len, seed), expected|
        buf = XXH::VectorLoader.sanity_buffer(len)
        XXH::XXH64.hash(buf, seed).should eq(expected)
      end
    end
  end

  describe "XXH3-64 vendor vectors" do
    it "matches generated vendor vectors (sanity buffer)" do
      XXH::VectorLoader.xxh3_vectors.each do |(len, seed), expected|
        buf = XXH::VectorLoader.sanity_buffer(len)
        XXH::XXH3.hash64(buf, seed).should eq(expected)
      end
    end
  end

  describe "XXH3-128 vendor vectors" do
    it "matches generated vendor vectors (sanity buffer)" do
      XXH::VectorLoader.xxh128_vectors.each do |(len, seed), expected|
        buf = XXH::VectorLoader.sanity_buffer(len)
        expect_hash = XXH::Hash128.new(expected[:high], expected[:low])
        XXH::XXH3.hash128(buf, seed).should eq(expect_hash)
      end
    end
  end
end
