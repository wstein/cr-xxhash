require "./spec_helper"

describe XXH::XXH3::Secret do
  describe ".default" do
    it "returns Bytes" do
      secret = XXH::XXH3::Secret.default
      secret.should be_a(Bytes)
    end

    it "has correct default size" do
      secret = XXH::XXH3::Secret.default
      secret.size.should eq(LibXXH::XXH3_SECRET_DEFAULT_SIZE)
    end

    it "meets minimum size requirement" do
      secret = XXH::XXH3::Secret.default
      secret.size.should be >= LibXXH::XXH3_SECRET_SIZE_MIN
    end

    it "produces deterministic result" do
      secret1 = XXH::XXH3::Secret.default
      secret2 = XXH::XXH3::Secret.default
      secret1.should eq(secret2)
    end

    it "contains non-zero bytes" do
      secret = XXH::XXH3::Secret.default
      has_nonzero = secret.any? { |b| b != 0_u8 }
      has_nonzero.should be_true
    end
  end

  describe ".valid?" do
    it "returns true for default secret" do
      secret = XXH::XXH3::Secret.default
      XXH::XXH3::Secret.valid?(secret).should be_true
    end

    it "returns true for large enough secret" do
      secret = Bytes.new(200)
      XXH::XXH3::Secret.valid?(secret).should be_true
    end

    it "returns false for too-small secret" do
      short_secret = Bytes.new(50)
      XXH::XXH3::Secret.valid?(short_secret).should be_false
    end

    it "returns false for empty secret" do
      XXH::XXH3::Secret.valid?(Bytes.empty).should be_false
    end

    it "returns true for minimum-size secret" do
      min_secret = Bytes.new(LibXXH::XXH3_SECRET_SIZE_MIN)
      XXH::XXH3::Secret.valid?(min_secret).should be_true
    end
  end
end
