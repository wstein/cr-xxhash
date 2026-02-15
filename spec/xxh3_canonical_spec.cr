require "./spec_helper"

describe "XXH3 128-bit Canonical Representation" do
  describe "#canonical_from_hash" do
    it "converts UInt128 to 16-byte canonical form" do
      hash = UInt128.from_halves(0x0123456789ABCDEF_u64, 0xFEDCBA9876543210_u64)
      canonical = XXH::XXH3.canonical_from_hash(hash)
      canonical.should be_a(Bytes)
      canonical.size.should eq(16)
    end

    it "produces big-endian byte order for high64" do
      hash = UInt128.from_halves(0x123456789ABCDEF0_u64, 0xFF00FF00FF00FF00_u64)
      canonical = XXH::XXH3.canonical_from_hash(hash)

      # High 64 bits in big-endian
      canonical[0].should eq(0x12)
      canonical[1].should eq(0x34)
      canonical[2].should eq(0x56)
      canonical[3].should eq(0x78)
      canonical[4].should eq(0x9A)
      canonical[5].should eq(0xBC)
      canonical[6].should eq(0xDE)
      canonical[7].should eq(0xF0)
    end

    it "produces big-endian byte order for low64" do
      hash = UInt128.from_halves(0x0123456789ABCDEF_u64, 0xFF00FF00FF00FF00_u64)
      canonical = XXH::XXH3.canonical_from_hash(hash)

      # Low 64 bits in big-endian
      canonical[8].should eq(0xFF)
      canonical[9].should eq(0x00)
      canonical[10].should eq(0xFF)
      canonical[11].should eq(0x00)
      canonical[12].should eq(0xFF)
      canonical[13].should eq(0x00)
      canonical[14].should eq(0xFF)
      canonical[15].should eq(0x00)
    end

    it "handles all-zero hash" do
      hash = UInt128.from_halves(0_u64, 0_u64)
      canonical = XXH::XXH3.canonical_from_hash(hash)
      canonical.should eq(Bytes.new(16, 0x00_u8))
    end

    it "handles all-ones hash" do
      hash = UInt128.from_halves(0xFFFFFFFFFFFFFFFF_u64, 0xFFFFFFFFFFFFFFFF_u64)
      canonical = XXH::XXH3.canonical_from_hash(hash)
      canonical.should eq(Bytes.new(16, 0xFF_u8))
    end
  end

  describe "#hash_from_canonical" do
    it "reconstructs Hash128 from canonical bytes" do
      original_hash = UInt128.from_halves(0x123456789ABCDEF0_u64, 0xFEDCBA9876543210_u64)
      canonical = XXH::XXH3.canonical_from_hash(original_hash)
      restored_hash = XXH::XXH3.hash_from_canonical(canonical)
      restored_hash.should eq(original_hash)
    end

    it "raises on wrong byte length (< 16)" do
      expect_raises(ArgumentError, /requires 16 bytes/) do
        XXH::XXH3.hash_from_canonical(Bytes.new(15))
      end
    end

    it "raises on wrong byte length (> 16)" do
      expect_raises(ArgumentError, /requires 16 bytes/) do
        XXH::XXH3.hash_from_canonical(Bytes.new(17))
      end
    end

    it "raises on empty bytes" do
      expect_raises(ArgumentError, /requires 16 bytes/) do
        XXH::XXH3.hash_from_canonical(Bytes.empty)
      end
    end
  end

  describe "round-trip conversion" do
    it "hash -> canonical -> hash produces original" do
      [
        UInt128.from_halves(0_u64, 0_u64),
        UInt128.from_halves(0x123456789ABCDEF0_u64, 0xFEDCBA9876543210_u64),
        UInt128.from_halves(0xDEADBEEFCAFEBABE_u64, 0x0123456789ABCDEF_u64),
        UInt128.from_halves(0xFFFFFFFFFFFFFFFF_u64, 0xFFFFFFFFFFFFFFFF_u64),
      ].each do |original|
        canonical = XXH::XXH3.canonical_from_hash(original)
        restored = XXH::XXH3.hash_from_canonical(canonical)
        restored.should eq(original)
      end
    end

    it "handles test vectors" do
      TEST_VECTORS_XXH3_128.each do |(input, seed), (high, low)|
        hash = UInt128.from_halves(high, low)
        canonical = XXH::XXH3.canonical_from_hash(hash)
        canonical.size.should eq(16)
        restored = XXH::XXH3.hash_from_canonical(canonical)
        restored.should eq(hash)
      end
    end
  end

  describe "canonical consistency" do
    it "same hash produces identical canonical bytes each time" do
      hash = UInt128.from_halves(0x123456789ABCDEF0_u64, 0xFEDCBA9876543210_u64)
      canonical1 = XXH::XXH3.canonical_from_hash(hash)
      canonical2 = XXH::XXH3.canonical_from_hash(hash)
      canonical1.should eq(canonical2)
    end

    it "different hashes produce different canonical bytes" do
      hash1 = UInt128.from_halves(0x123456789ABCDEF0_u64, 0xFEDCBA9876543210_u64)
      hash2 = UInt128.from_halves(0xFEDCBA9876543210_u64, 0x123456789ABCDEF0_u64)
      canonical1 = XXH::XXH3.canonical_from_hash(hash1)
      canonical2 = XXH::XXH3.canonical_from_hash(hash2)
      canonical1.should_not eq(canonical2)
    end
  end

  describe "cross-platform compatibility" do
    it "canonical form is portable (big-endian IEEE)" do
      hash = UInt128.from_halves(0x0123456789ABCDEF_u64, 0xFEDCBA9876543210_u64)
      canonical = XXH::XXH3.canonical_from_hash(hash)

      # Reconstruct high64 from bytes manually
      high64_reconstructed = (canonical[0].to_u64 << 56) |
                             (canonical[1].to_u64 << 48) |
                             (canonical[2].to_u64 << 40) |
                             (canonical[3].to_u64 << 32) |
                             (canonical[4].to_u64 << 24) |
                             (canonical[5].to_u64 << 16) |
                             (canonical[6].to_u64 << 8) |
                             (canonical[7].to_u64)

      # Reconstruct low64 from bytes manually
      low64_reconstructed = (canonical[8].to_u64 << 56) |
                            (canonical[9].to_u64 << 48) |
                            (canonical[10].to_u64 << 40) |
                            (canonical[11].to_u64 << 32) |
                            (canonical[12].to_u64 << 24) |
                            (canonical[13].to_u64 << 16) |
                            (canonical[14].to_u64 << 8) |
                            (canonical[15].to_u64)

      high64_reconstructed.should eq(0x0123456789ABCDEF_u64)
      low64_reconstructed.should eq(0xFEDCBA9876543210_u64)
    end
  end

  describe "Hash128 equality in canonical round-trip" do
    it "maintains equality through serialization" do
      hash1 = XXH::XXH3.hash128("test")
      hash2 = XXH::XXH3.hash128("test")

      canonical1 = XXH::XXH3.canonical_from_hash(hash1)
      canonical2 = XXH::XXH3.canonical_from_hash(hash2)

      canonical1.should eq(canonical2)

      restored1 = XXH::XXH3.hash_from_canonical(canonical1)
      restored2 = XXH::XXH3.hash_from_canonical(canonical2)

      restored1.should eq(restored2)
    end
  end
end
