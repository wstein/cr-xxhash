require "./spec_helper"

describe "XXH32 Canonical Representation" do
  describe "#canonical_from_hash" do
    it "converts hash to 4-byte canonical form" do
      hash = 0x12345678_u32
      canonical = XXH::XXH32.canonical_from_hash(hash)
      canonical.should be_a(Bytes)
      canonical.size.should eq(4)
    end

    it "produces big-endian byte order" do
      hash = 0x12345678_u32
      canonical = XXH::XXH32.canonical_from_hash(hash)
      # Big-endian: most significant byte first
      canonical[0].should eq(0x12)
      canonical[1].should eq(0x34)
      canonical[2].should eq(0x56)
      canonical[3].should eq(0x78)
    end

    it "handles all-zero hash" do
      hash = 0x00000000_u32
      canonical = XXH::XXH32.canonical_from_hash(hash)
      canonical.should eq(Bytes[0x00, 0x00, 0x00, 0x00])
    end

    it "handles all-ones hash" do
      hash = 0xFFFFFFFF_u32
      canonical = XXH::XXH32.canonical_from_hash(hash)
      canonical.should eq(Bytes[0xFF, 0xFF, 0xFF, 0xFF])
    end
  end

  describe "#hash_from_canonical" do
    it "reconstructs hash from canonical bytes" do
      original_hash = 0x12345678_u32
      canonical = XXH::XXH32.canonical_from_hash(original_hash)
      restored_hash = XXH::XXH32.hash_from_canonical(canonical)
      restored_hash.should eq(original_hash)
    end

    it "raises on wrong byte length (< 4)" do
      expect_raises(ArgumentError, /requires 4 bytes/) do
        XXH::XXH32.hash_from_canonical(Bytes[0x12, 0x34, 0x56])
      end
    end

    it "raises on wrong byte length (> 4)" do
      expect_raises(ArgumentError, /requires 4 bytes/) do
        XXH::XXH32.hash_from_canonical(Bytes[0x12, 0x34, 0x56, 0x78, 0x9A])
      end
    end

    it "raises on empty bytes" do
      expect_raises(ArgumentError, /requires 4 bytes/) do
        XXH::XXH32.hash_from_canonical(Bytes.empty)
      end
    end
  end

  describe "round-trip conversion" do
    it "hash -> canonical -> hash produces original" do
      [
        0x00000000_u32,
        0x12345678_u32,
        0xDEADBEEF_u32,
        0xFFFFFFFF_u32,
        0x9e3779b1_u32, # Prime from xxHash
      ].each do |original|
        canonical = XXH::XXH32.canonical_from_hash(original)
        restored = XXH::XXH32.hash_from_canonical(canonical)
        restored.should eq(original), "Failed for #{original.to_s(16)}"
      end
    end

    it "handles test vectors" do
      TEST_VECTORS_XXH32.each do |(input, seed), hash|
        canonical = XXH::XXH32.canonical_from_hash(hash)
        canonical.size.should eq(4)
        restored = XXH::XXH32.hash_from_canonical(canonical)
        restored.should eq(hash)
      end
    end
  end

  describe "canonical consistency" do
    it "same hash produces identical canonical bytes each time" do
      hash = 0x12345678_u32
      canonical1 = XXH::XXH32.canonical_from_hash(hash)
      canonical2 = XXH::XXH32.canonical_from_hash(hash)
      canonical1.should eq(canonical2)
    end

    it "different hashes produce different canonical bytes" do
      canonical1 = XXH::XXH32.canonical_from_hash(0x12345678_u32)
      canonical2 = XXH::XXH32.canonical_from_hash(0x87654321_u32)
      canonical1.should_not eq(canonical2)
    end
  end

  describe "cross-platform compatibility" do
    it "canonical form is portable (big-endian IEEE)" do
      # Canonical form is always big-endian regardless of platform
      hash = 0xAABBCCDD_u32
      canonical = XXH::XXH32.canonical_from_hash(hash)

      # Reconstruct manually as big-endian
      reconstructed = (canonical[0].to_u32 << 24) |
                      (canonical[1].to_u32 << 16) |
                      (canonical[2].to_u32 << 8) |
                      (canonical[3].to_u32)

      reconstructed.should eq(0xAABBCCDD_u32)
    end
  end
end
