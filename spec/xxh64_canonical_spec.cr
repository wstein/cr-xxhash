require "./spec_helper"

describe "XXH64 Canonical Representation" do
  describe "#canonical_from_hash" do
    it "converts hash to 8-byte canonical form" do
      hash = 0x123456789ABCDEF0_u64
      canonical = XXH::XXH64.canonical_from_hash(hash)
      canonical.should be_a(Bytes)
      canonical.size.should eq(8)
    end

    it "produces big-endian byte order" do
      hash = 0x123456789ABCDEF0_u64
      canonical = XXH::XXH64.canonical_from_hash(hash)
      # Big-endian: most significant byte first
      canonical[0].should eq(0x12)
      canonical[1].should eq(0x34)
      canonical[2].should eq(0x56)
      canonical[3].should eq(0x78)
      canonical[4].should eq(0x9A)
      canonical[5].should eq(0xBC)
      canonical[6].should eq(0xDE)
      canonical[7].should eq(0xF0)
    end

    it "handles all-zero hash" do
      hash = 0x0000000000000000_u64
      canonical = XXH::XXH64.canonical_from_hash(hash)
      canonical.should eq(Bytes[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    end

    it "handles all-ones hash" do
      hash = 0xFFFFFFFFFFFFFFFF_u64
      canonical = XXH::XXH64.canonical_from_hash(hash)
      canonical.should eq(Bytes[0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
    end
  end

  describe "#hash_from_canonical" do
    it "reconstructs hash from canonical bytes" do
      original_hash = 0x123456789ABCDEF0_u64
      canonical = XXH::XXH64.canonical_from_hash(original_hash)
      restored_hash = XXH::XXH64.hash_from_canonical(canonical)
      restored_hash.should eq(original_hash)
    end

    it "raises on wrong byte length (< 8)" do
      expect_raises(ArgumentError, /requires 8 bytes/) do
        XXH::XXH64.hash_from_canonical(Bytes[0x12, 0x34, 0x56, 0x78])
      end
    end

    it "raises on wrong byte length (> 8)" do
      expect_raises(ArgumentError, /requires 8 bytes/) do
        bytes = Bytes.new(9) { 0x00_u8 }
        XXH::XXH64.hash_from_canonical(bytes)
      end
    end

    it "raises on empty bytes" do
      expect_raises(ArgumentError, /requires 8 bytes/) do
        XXH::XXH64.hash_from_canonical(Bytes.empty)
      end
    end
  end

  describe "round-trip conversion" do
    it "hash -> canonical -> hash produces original" do
      [
        0x0000000000000000_u64,
        0x123456789ABCDEF0_u64,
        0xDEADBEEFCAFEBABE_u64,
        0xFFFFFFFFFFFFFFFF_u64,
        0x9e3779b185ebca87_u64, # Prime from xxHash
      ].each do |original|
        canonical = XXH::XXH64.canonical_from_hash(original)
        restored = XXH::XXH64.hash_from_canonical(canonical)
        restored.should eq(original), "Failed for #{original.to_s(16)}"
      end
    end

    it "handles test vectors" do
      TEST_VECTORS_XXH64.each do |(input, seed), hash|
        canonical = XXH::XXH64.canonical_from_hash(hash)
        canonical.size.should eq(8)
        restored = XXH::XXH64.hash_from_canonical(canonical)
        restored.should eq(hash)
      end
    end
  end

  describe "canonical consistency" do
    it "same hash produces identical canonical bytes each time" do
      hash = 0x123456789ABCDEF0_u64
      canonical1 = XXH::XXH64.canonical_from_hash(hash)
      canonical2 = XXH::XXH64.canonical_from_hash(hash)
      canonical1.should eq(canonical2)
    end

    it "different hashes produce different canonical bytes" do
      canonical1 = XXH::XXH64.canonical_from_hash(0x123456789ABCDEF0_u64)
      canonical2 = XXH::XXH64.canonical_from_hash(0x0FEDCBA987654321_u64)
      canonical1.should_not eq(canonical2)
    end
  end

  describe "cross-platform compatibility" do
    it "canonical form is portable (big-endian IEEE)" do
      hash = 0xAABBCCDDEEFF0011_u64
      canonical = XXH::XXH64.canonical_from_hash(hash)

      reconstructed = (canonical[0].to_u64 << 56) |
                      (canonical[1].to_u64 << 48) |
                      (canonical[2].to_u64 << 40) |
                      (canonical[3].to_u64 << 32) |
                      (canonical[4].to_u64 << 24) |
                      (canonical[5].to_u64 << 16) |
                      (canonical[6].to_u64 << 8) |
                      (canonical[7].to_u64)

      reconstructed.should eq(0xAABBCCDDEEFF0011_u64)
    end
  end

  describe "byte-by-byte reconstruction" do
    it "correctly reconstructs from individual bytes" do
      hash = 0x0102030405060708_u64
      canonical = XXH::XXH64.canonical_from_hash(hash)

      # Verify each byte
      canonical[0].should eq(0x01)
      canonical[1].should eq(0x02)
      canonical[2].should eq(0x03)
      canonical[3].should eq(0x04)
      canonical[4].should eq(0x05)
      canonical[5].should eq(0x06)
      canonical[6].should eq(0x07)
      canonical[7].should eq(0x08)

      # Verify reconstruction
      restored = XXH::XXH64.hash_from_canonical(canonical)
      restored.should eq(hash)
    end
  end
end
