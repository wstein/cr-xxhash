require "./spec_helper"

describe "generate_vectors fixture and loader" do
  it "per-algorithm fixture files exist and contain entries and meta" do
    %w[xxh32 xxh64 xxh3 xxh128].each do |name|
      path = File.expand_path("fixtures/vendor_vectors_#{name}.json", __DIR__)
      File.exists?(path).should be_true
      parsed = JSON.parse(File.read(path)).as_h
      parsed["vectors"].as_a.size.should be > 0
      parsed.has_key?("sanity_buffer_max_len").should be_true
      parsed["sanity_buffer_max_len"].as_i.should be > 0
    end
  end

  it "XXH::VectorLoader parses fixtures and returns numeric values" do
    # ensure loader parses hex strings correctly and maps to numeric hashes
    parsed = JSON.parse(File.read(File.expand_path("fixtures/vendor_vectors_xxh32.json", __DIR__))).as_h
    first = parsed["vectors"].as_a.first
    first["seed"].as_s.starts_with?("0x").should be_true
    first["result"].as_s.starts_with?("0x").should be_true

    # sanity check: loader returns the expected numeric hash for len=0, seed=0
    XXH::VectorLoader.xxh32_vectors[{0, 0_u32}].should eq(0x02cc5d05_u32)
  end
end
