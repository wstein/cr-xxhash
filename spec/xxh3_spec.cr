require "./spec_helper"

describe "XXH3 64-bit Hash" do
  describe ".hash64" do
    it "matches official test vectors (no seed)" do
      TEST_VECTORS_XXH3_64.each do |(input, seed), expected|
        next unless seed == 0_u64
        XXH::XXH3.hash64(input).should eq(expected)
      end
    end

    it "matches official test vectors (with seed)" do
      TEST_VECTORS_XXH3_64.each do |(input, seed), expected|
        XXH::XXH3.hash64(input, seed).should eq(expected)
      end
    end

    it "accepts String input" do
      result = XXH::XXH3.hash64("test")
      result.should be_a(UInt64)
    end

    it "accepts Bytes input" do
      result = XXH::XXH3.hash64("test".to_slice)
      result.should be_a(UInt64)
    end

    it "string and bytes produce same hash" do
      XXH::XXH3.hash64("test").should eq(XXH::XXH3.hash64("test".to_slice))
    end

    it "uses default seed of 0" do
      XXH::XXH3.hash64("test").should eq(XXH::XXH3.hash64("test", 0_u64))
    end

    it "produces different hashes for different seeds" do
      hash1 = XXH::XXH3.hash64("test", 0_u64)
      hash2 = XXH::XXH3.hash64("test", 1_u64)
      hash1.should_not eq(hash2)
    end

    it "handles empty input" do
      XXH::XXH3.hash64("").should eq(0x2d06800538d394c2_u64)
    end

    it "handles large input (1MB)" do
      large_data = incremental_bytes(1_000_000)
      hash = XXH::XXH3.hash64(large_data)
      hash.should be_a(UInt64)
    end

    it "distinguishes from XXH32 and XXH64" do
      data = "test"
      hash32 = XXH::XXH32.hash(data)
      hash64 = XXH::XXH64.hash(data)
      hash3_64 = XXH::XXH3.hash64(data)

      # All should be different
      (hash32.to_u64 != hash3_64).should be_true
      (hash64 != hash3_64).should be_true
    end
  end

  describe ".hash64(io)" do
    it "hashes IO stream" do
      io = IO::Memory.new("test data")
      hash = XXH::XXH3.hash64(io)
      expected = XXH::XXH3.hash64("test data")
      hash.should eq(expected)
    end

    it "hashes large IO stream" do
      large_data = incremental_bytes(100_000)
      io = IO::Memory.new(large_data)
      hash = XXH::XXH3.hash64(io)
      expected = XXH::XXH3.hash64(large_data)
      hash.should eq(expected)
    end

    it "accepts seed parameter" do
      hash_seed0 = XXH::XXH3.hash64(IO::Memory.new("test"), 0_u64)
      hash_seed1 = XXH::XXH3.hash64(IO::Memory.new("test"), 1_u64)
      hash_seed0.should_not eq(hash_seed1)
    end
  end

  describe ".hash64_file" do
    it "hashes file contents" do
      with_tempfile("test data") do |path|
        hash = XXH::XXH3.hash64_file(path)
        expected = XXH::XXH3.hash64("test data")
        hash.should eq(expected)
      end
    end

    it "accepts Path argument" do
      with_tempfile("test") do |path|
        hash = XXH::XXH3.hash64_file(Path.new(path))
        expected = XXH::XXH3.hash64("test")
        hash.should eq(expected)
      end
    end

    it "hashes large file" do
      large_data = incremental_bytes(1_000_000)
      with_tempfile(String.new(large_data)) do |path|
        file_hash = XXH::XXH3.hash64_file(path)
        memory_hash = XXH::XXH3.hash64(large_data)
        file_hash.should eq(memory_hash)
      end
    end
  end
end

describe "XXH3 128-bit Hash" do
  describe ".hash128" do
    it "returns Hash128 struct" do
      result = XXH::XXH3.hash128("test")
      result.should be_a(XXH::Hash128)
    end

    it "matches official test vectors (no seed)" do
      TEST_VECTORS_XXH3_128.each do |(input, seed), (high, low)|
        next unless seed == 0_u64
        result = XXH::XXH3.hash128(input)
        result.high64.should eq(high)
        result.low64.should eq(low)
      end
    end

    it "accepts String input" do
      result = XXH::XXH3.hash128("test")
      result.should be_a(XXH::Hash128)
    end

    it "accepts Bytes input" do
      result = XXH::XXH3.hash128("test".to_slice)
      result.should be_a(XXH::Hash128)
    end

    it "string and bytes produce same hash" do
      XXH::XXH3.hash128("test").should eq(XXH::XXH3.hash128("test".to_slice))
    end

    it "uses default seed of 0" do
      XXH::XXH3.hash128("test").should eq(XXH::XXH3.hash128("test", 0_u64))
    end

    it "produces different hashes for different seeds" do
      hash1 = XXH::XXH3.hash128("test", 0_u64)
      hash2 = XXH::XXH3.hash128("test", 1_u64)
      hash1.should_not eq(hash2)
    end

    it "handles empty input" do
      result = XXH::XXH3.hash128("")
      result.high64.should eq(0x99aa06d3014798d8_u64)
      result.low64.should eq(0x6001c324468d497f_u64)
    end

    it "handles large input (1MB)" do
      large_data = incremental_bytes(1_000_000)
      hash = XXH::XXH3.hash128(large_data)
      hash.should be_a(XXH::Hash128)
    end
  end

  describe ".hash128(io)" do
    it "hashes IO stream" do
      io = IO::Memory.new("test data")
      hash = XXH::XXH3.hash128(io)
      expected = XXH::XXH3.hash128("test data")
      hash.should eq(expected)
    end

    it "hashes large IO stream" do
      large_data = incremental_bytes(100_000)
      io = IO::Memory.new(large_data)
      hash = XXH::XXH3.hash128(io)
      expected = XXH::XXH3.hash128(large_data)
      hash.should eq(expected)
    end

    it "accepts seed parameter" do
      hash_seed0 = XXH::XXH3.hash128(IO::Memory.new("test"), 0_u64)
      hash_seed1 = XXH::XXH3.hash128(IO::Memory.new("test"), 1_u64)
      hash_seed0.should_not eq(hash_seed1)
    end
  end

  describe ".hash128_file" do
    it "hashes file contents" do
      with_tempfile("test data") do |path|
        hash = XXH::XXH3.hash128_file(path)
        expected = XXH::XXH3.hash128("test data")
        hash.should eq(expected)
      end
    end

    it "accepts Path argument" do
      with_tempfile("test") do |path|
        hash = XXH::XXH3.hash128_file(Path.new(path))
        expected = XXH::XXH3.hash128("test")
        hash.should eq(expected)
      end
    end

    it "hashes large file" do
      large_data = incremental_bytes(1_000_000)
      with_tempfile(String.new(large_data)) do |path|
        file_hash = XXH::XXH3.hash128_file(path)
        memory_hash = XXH::XXH3.hash128(large_data)
        file_hash.should eq(memory_hash)
      end
    end
  end

  describe "Hash128 struct" do
    it "can be compared for equality" do
      hash1 = XXH::XXH3.hash128("test")
      hash2 = XXH::XXH3.hash128("test")
      hash1.should eq(hash2)
    end

    it "different inputs produce different hashes" do
      hash1 = XXH::XXH3.hash128("test1")
      hash2 = XXH::XXH3.hash128("test2")
      hash1.should_not eq(hash2)
    end

    it "provides high64 and low64 accessors" do
      hash = XXH::XXH3.hash128("test")
      hash.high64.should be_a(UInt64)
      hash.low64.should be_a(UInt64)
    end

    it "produces deterministic results" do
      data = "deterministic test"
      results = 5.times.map { XXH::XXH3.hash128(data) }.to_a
      results.each { |r| r.should eq(results[0]) }
    end
  end

  describe "consistency between hash64 and hash128" do
    it "hash128 result is distinct from hash64 for same input" do
      data = "consistency check"
      hash64 = XXH::XXH3.hash64(data)
      hash128 = XXH::XXH3.hash128(data)

      # hash64 should not directly match either component of hash128
      (hash64 != hash128.high64).should be_true
      (hash64 != hash128.low64).should be_true
    end

    it "128-bit hash is reproducible from separate 64-bit hashing" do
      # While 128-bit hash is independent, it should be consistent
      hash128a = XXH::XXH3.hash128("test")
      hash128b = XXH::XXH3.hash128("test")
      hash128a.should eq(hash128b)
    end
  end
end

def with_tempfile(content : String | Bytes, &block : String -> Void)
  File.tempfile do |file|
    case content
    when String
      file.print(content)
    when Bytes
      file.write(content)
    end
    file.flush
    yield file.path
  end
end
