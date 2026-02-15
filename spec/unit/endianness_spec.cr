require "../spec_helper"

describe "Endianness & Cross-platform Determinism" do
  describe "XXH32 canonical endianness" do
    it "always uses big-endian byte order in canonical form" do
      # Test with representative values across the full 32-bit range
      [
        {hash: 0x12345678_u32, expected_bytes: Bytes[0x12, 0x34, 0x56, 0x78]},
        {hash: 0xFF00FF00_u32, expected_bytes: Bytes[0xFF, 0x00, 0xFF, 0x00]},
        {hash: 0x00FF00FF_u32, expected_bytes: Bytes[0x00, 0xFF, 0x00, 0xFF]},
        {hash: 0x0_u32, expected_bytes: Bytes[0x00, 0x00, 0x00, 0x00]},
        {hash: 0xFFFFFFFF_u32, expected_bytes: Bytes[0xFF, 0xFF, 0xFF, 0xFF]},
        {hash: 0x80000000_u32, expected_bytes: Bytes[0x80, 0x00, 0x00, 0x00]},
        {hash: 0x00000001_u32, expected_bytes: Bytes[0x00, 0x00, 0x00, 0x01]},
      ].each do |test_case|
        canonical = XXH::XXH32.canonical_from_hash(test_case[:hash])
        canonical.should eq(test_case[:expected_bytes]), "Hash #{test_case[:hash].to_s(16)} produced #{canonical.map { |b| b.to_s(16) }.join(",")} instead of #{test_case[:expected_bytes].map { |b| b.to_s(16) }.join(",")}"
      end
    end

    it "round-trip canonical conversion is deterministic" do
      # Use pre-computed test values to avoid arithmetic overflow
      test_values = (0u32..49u32).map { |i| (i ^ (i &* 15u32)) | (i.rotate_left(3u32) &* 7u32) }
      test_values.each do |original|
        canonical = XXH::XXH32.canonical_from_hash(original)
        restored = XXH::XXH32.hash_from_canonical(canonical)
        restored.should eq(original), "Roundtrip failed for #{original.to_s(16)}"
      end
    end
  end

  describe "XXH64 canonical endianness" do
    it "always uses big-endian byte order in canonical form" do
      [
        {hash: 0x123456789ABCDEF0_u64, expected_bytes: Bytes[0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0]},
        {hash: 0xFF00FF00FF00FF00_u64, expected_bytes: Bytes[0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00]},
        {hash: 0x00FFFFFF00FFFFFF_u64, expected_bytes: Bytes[0x00, 0xFF, 0xFF, 0xFF, 0x00, 0xFF, 0xFF, 0xFF]},
        {hash: 0x0_u64, expected_bytes: Bytes[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]},
        {hash: 0xFFFFFFFFFFFFFFFF_u64, expected_bytes: Bytes[0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]},
        {hash: 0x8000000000000000_u64, expected_bytes: Bytes[0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]},
        {hash: 0x0000000000000001_u64, expected_bytes: Bytes[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]},
      ].each do |test_case|
        canonical = XXH::XXH64.canonical_from_hash(test_case[:hash])
        canonical.should eq(test_case[:expected_bytes]), "Hash #{test_case[:hash].to_s(16)} mismatch"
      end
    end

    it "round-trip canonical conversion is deterministic" do
      # Use pre-computed test values to avoid arithmetic overflow
      test_values = (0u64..49u64).map { |i| (i ^ (i &* 15u64)) | (i.rotate_left(5u64) &* 7u64) }
      test_values.each do |original|
        canonical = XXH::XXH64.canonical_from_hash(original)
        restored = XXH::XXH64.hash_from_canonical(canonical)
        restored.should eq(original)
      end
    end
  end

  describe "XXH3 (128-bit) canonical endianness" do
    it "encodes both low64 and high64 in big-endian form" do
      [
        {
          hash: UInt128.from_halves(0x0_u64, 0x0_u64),
          expected: Bytes[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
        },
        {
          hash: UInt128.from_halves(0xFFFFFFFFFFFFFFFF_u64, 0xFFFFFFFFFFFFFFFF_u64),
          expected: Bytes[0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF],
        },
        {
          hash: UInt128.from_halves(0x123456789ABCDEF0_u64, 0xFEDCBA9876543210_u64),
          expected: Bytes[0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0, 0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10],
        },
        {
          hash: UInt128.from_halves(0xFF00FF00FF00FF00_u64, 0x00FF00FF00FF00FF_u64),
          expected: Bytes[0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF],
        },

      ].each do |test_case|
        canonical = XXH::XXH3.canonical_from_hash(test_case[:hash])
        canonical.should eq(test_case[:expected]), "UInt128(high=#{test_case[:hash].high64.to_s(16)}, low=#{test_case[:hash].low64.to_s(16)}) mismatch"
      end
    end

    it "round-trip canonical conversion maintains determinism for 128-bit" do
      # Use pre-computed test values to avoid arithmetic overflow
      test_values = (0u64..49u64).map { |i|
        {
          high: (i ^ (i &* 15u64)) | (i.rotate_left(5u64) &* 7u64),
          low: (i ^ (i &* 23u64)) | (i.rotate_left(13u64) &* 11u64)
        }
      }
      test_values.each do |pair|
        original = UInt128.from_halves(pair[:high], pair[:low])
        canonical = XXH::XXH3.canonical_from_hash(original)
        restored = XXH::XXH3.hash_from_canonical(canonical)
        restored.should eq(original)
      end
    end
  end

  describe "Vendor vector canonical parity" do
    it "produces correct canonical form for all XXH32 vendor vectors" do
      TEST_VECTORS_XXH32.each do |(input, seed), expected_hash|
        canonical = XXH::XXH32.canonical_from_hash(expected_hash)
        # Verify big-endian encoding
        result_BE = (canonical[0].to_u32 << 24) |
                    (canonical[1].to_u32 << 16) |
                    (canonical[2].to_u32 << 8) |
                    canonical[3].to_u32
        result_BE.should eq(expected_hash), "Canonical form for XXH32(#{input[0..10].inspect}..., #{seed}) is incorrect"
      end
    end

    it "produces correct canonical form for all XXH64 vendor vectors" do
      TEST_VECTORS_XXH64.each do |(input, seed), expected_hash|
        canonical = XXH::XXH64.canonical_from_hash(expected_hash)
        result_BE = (canonical[0].to_u64 << 56) |
                    (canonical[1].to_u64 << 48) |
                    (canonical[2].to_u64 << 40) |
                    (canonical[3].to_u64 << 32) |
                    (canonical[4].to_u64 << 24) |
                    (canonical[5].to_u64 << 16) |
                    (canonical[6].to_u64 << 8) |
                    canonical[7].to_u64
        result_BE.should eq(expected_hash), "Canonical form for XXH64 is incorrect"
      end
    end

    it "produces correct canonical form for all XXH3 64-bit vendor vectors" do
      TEST_VECTORS_XXH3_64.each do |(input, seed), expected_hash|
        # XXH3 64-bit does not have a canonical form; only 128-bit does
        # This test validates that the 64-bit output is stable across runs
        hash1 = XXH::XXH3.hash64(input, seed)
        hash2 = XXH::XXH3.hash64(input, seed)
        hash1.should eq(hash2), "XXH3_64 output not deterministic"
        hash1.should eq(expected_hash), "XXH3_64 output differs from vendor vector"
      end
    end

    it "produces correct canonical form for all XXH3 128-bit vendor vectors" do
      TEST_VECTORS_XXH3_128.each do |(input, seed), (expected_high, expected_low)|
        hash = UInt128.from_halves(expected_high, expected_low)
        canonical = XXH::XXH3.canonical_from_hash(hash)
        # Reconstruct from big-endian bytes
        result_high = (canonical[0].to_u64 << 56) |
                      (canonical[1].to_u64 << 48) |
                      (canonical[2].to_u64 << 40) |
                      (canonical[3].to_u64 << 32) |
                      (canonical[4].to_u64 << 24) |
                      (canonical[5].to_u64 << 16) |
                      (canonical[6].to_u64 << 8) |
                      canonical[7].to_u64
        result_low = (canonical[8].to_u64 << 56) |
                     (canonical[9].to_u64 << 48) |
                     (canonical[10].to_u64 << 40) |
                     (canonical[11].to_u64 << 32) |
                     (canonical[12].to_u64 << 24) |
                     (canonical[13].to_u64 << 16) |
                     (canonical[14].to_u64 << 8) |
                     canonical[15].to_u64
        result_high.should eq(expected_high), "High64 canonical form incorrect"
        result_low.should eq(expected_low), "Low64 canonical form incorrect"
      end
    end
  end

  describe "Cross-platform determinism" do
    it "canonical form is identical across multiple calls (no randomization)" do
      test_hashes_32 = [0_u32, 0x12345678_u32, 0xFFFFFFFF_u32]
      test_hashes_64 = [0_u64, 0x123456789ABCDEF0_u64, 0xFFFFFFFFFFFFFFFF_u64]
      test_hashes_128 = [
        UInt128.from_halves(0_u64, 0_u64),
        UInt128.from_halves(0x123456789ABCDEF0_u64, 0xFEDCBA9876543210_u64),
      ]

      # Run multiple times and verify consistency
      5.times do
        test_hashes_32.each do |h|
          canonical1 = XXH::XXH32.canonical_from_hash(h)
          canonical2 = XXH::XXH32.canonical_from_hash(h)
          canonical1.should eq(canonical2), "XXH32 canonical inconsistent"
        end

        test_hashes_64.each do |h|
          canonical1 = XXH::XXH64.canonical_from_hash(h)
          canonical2 = XXH::XXH64.canonical_from_hash(h)
          canonical1.should eq(canonical2), "XXH64 canonical inconsistent"
        end

        test_hashes_128.each do |h|
          canonical1 = XXH::XXH3.canonical_from_hash(h)
          canonical2 = XXH::XXH3.canonical_from_hash(h)
          canonical1.should eq(canonical2), "XXH3_128 canonical inconsistent"
        end
      end
    end

    it "canonical bytes are independent of platform byte-order assumptions" do
      # Test that canonical format is always big-endian
      test_value_64 = 0x0102030405060708_u64
      canonical = XXH::XXH64.canonical_from_hash(test_value_64)
      # If it's truly big-endian, bytes should be in this exact order
      expected = Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
      canonical.should eq(expected)

      # Verify that a different bit pattern also follows big-endian
      test_value_64_alt = 0x0011223344556677_u64
      canonical_alt = XXH::XXH64.canonical_from_hash(test_value_64_alt)
      expected_alt = Bytes[0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77]
      canonical_alt.should eq(expected_alt)
    end
  end

  describe "Canonical form stability across endian systems" do
    it "ensures canonical bytes are platform-independent" do
      # This test ensures that even on little-endian systems,
      # the canonical form is always produced in big-endian byte order
      hash = 0x0102030405060708_u64
      canonical = XXH::XXH64.canonical_from_hash(hash)

      # Each byte should map directly according to big-endian interpretation
      canonical[0].should eq(0x01)
      canonical[1].should eq(0x02)
      canonical[2].should eq(0x03)
      canonical[3].should eq(0x04)
      canonical[4].should eq(0x05)
      canonical[5].should eq(0x06)
      canonical[6].should eq(0x07)
      canonical[7].should eq(0x08)
    end

    it "produces output that matches C implementation byte order" do
      # Verify against known C behavior by round-tripping
      test_values = [
        {bytes: Bytes[0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0], expected_hash: 0x123456789ABCDEF0_u64},
        {bytes: Bytes[0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00], expected_hash: 0xFF00FF00FF00FF00_u64},
      ]

      test_values.each do |test_case|
        hash = XXH::XXH64.hash_from_canonical(test_case[:bytes])
        hash.should eq(test_case[:expected_hash])

        # And back again
        canonical = XXH::XXH64.canonical_from_hash(hash)
        canonical.should eq(test_case[:bytes])
      end
    end
  end
end
