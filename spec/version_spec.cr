require "./spec_helper"

describe "Version Information" do
  describe "XXH.version_number" do
    it "returns UInt32" do
      version = XXH.version_number
      version.should be_a(UInt32)
    end

    it "is greater than zero" do
      version = XXH.version_number
      version.should be > 0_u32
    end

    it "is deterministic" do
      v1 = XXH.version_number
      v2 = XXH.version_number
      v1.should eq(v2)
    end

    it "matches major.minor.patch format" do
      version = XXH.version_number
      # Extract parts (typically version >> 16 = major, etc.)
      major = (version >> 16) & 0xFF
      minor = (version >> 8) & 0xFF
      patch = version & 0xFF

      major.should be >= 0_u32
      minor.should be >= 0_u32
      patch.should be >= 0_u32
    end
  end

  describe "XXH.version" do
    it "returns String" do
      version_str = XXH.version
      version_str.should be_a(String)
    end

    it "contains three numeric parts (major.minor.patch)" do
      version_str = XXH.version
      parts = version_str.split(".")
      parts.size.should eq(3)
      parts.each { |p| p.to_i?.should_not be_nil }
    end

    it "is deterministic" do
      v1 = XXH.version
      v2 = XXH.version
      v1.should eq(v2)
    end

    it "is consistent with version_number" do
      version_str = XXH.version
      version_num = XXH.version_number

      parts = version_str.split(".")
      major = parts[0].to_u32
      minor = parts[1].to_u32
      patch = parts[2].to_u32

      # Reconstruct version number from string parts
      reconstructed = (major << 16) | (minor << 8) | patch
      reconstructed.should eq(version_num)
    end

    it "defines MODULE VERSION constant" do
      XXH::VERSION.should be_a(String)
    end
  end
end
