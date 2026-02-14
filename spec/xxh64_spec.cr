require "./spec_helper"

describe XXH::XXH64 do
  describe ".hash" do
    it "matches official test vectors (no seed)" do
      TEST_VECTORS_XXH64.each do |(input, seed), expected|
        next unless seed == 0_u64
        XXH::XXH64.hash(input).should eq(expected)
      end
    end

    it "matches official test vectors (with seed)" do
      TEST_VECTORS_XXH64.each do |(input, seed), expected|
        XXH::XXH64.hash(input, seed).should eq(expected)
      end
    end

    it "accepts String input" do
      result = XXH::XXH64.hash("test")
      result.should be_a(UInt64)
    end

    it "accepts Bytes input" do
      result = XXH::XXH64.hash("test".to_slice)
      result.should be_a(UInt64)
    end

    it "string and bytes produce same hash" do
      XXH::XXH64.hash("test").should eq(XXH::XXH64.hash("test".to_slice))
    end

    it "uses default seed of 0" do
      XXH::XXH64.hash("test").should eq(XXH::XXH64.hash("test", 0_u64))
    end

    it "produces different hashes for different seeds" do
      hash1 = XXH::XXH64.hash("test", 0_u64)
      hash2 = XXH::XXH64.hash("test", 1_u64)
      hash1.should_not eq(hash2)
    end

    it "handles empty input" do
      XXH::XXH64.hash("").should eq(0xef46db3751d8e999_u64)
    end

    it "handles large input (1MB)" do
      large_data = incremental_bytes(1_000_000)
      hash = XXH::XXH64.hash(large_data)
      hash.should be_a(UInt64)
    end

    it "handles random data" do
      random_data = random_bytes(1024)
      hash = XXH::XXH64.hash(random_data)
      hash.should be_a(UInt64)
    end

    it "distinguishes from XXH32" do
      data = "test"
      hash32 = XXH::XXH32.hash(data)
      hash64 = XXH::XXH64.hash(data)
      # The hashes should be different algorithms
      hash32.should_not eq(hash64)
    end
  end

  describe ".hash(io)" do
    it "hashes IO stream" do
      io = IO::Memory.new("test data")
      hash = XXH::XXH64.hash(io)
      expected = XXH::XXH64.hash("test data")
      hash.should eq(expected)
    end

    it "hashes large IO stream" do
      large_data = incremental_bytes(100_000)
      io = IO::Memory.new(large_data)
      hash = XXH::XXH64.hash(io)
      expected = XXH::XXH64.hash(large_data)
      hash.should eq(expected)
    end

    it "accepts seed parameter" do
      hash_seed0 = XXH::XXH64.hash(IO::Memory.new("test"), 0_u64)
      hash_seed1 = XXH::XXH64.hash(IO::Memory.new("test"), 1_u64)
      hash_seed0.should_not eq(hash_seed1)
    end
  end

  describe ".hash_file" do
    it "hashes file contents" do
      with_tempfile("test data") do |path|
        hash = XXH::XXH64.hash_file(path)
        expected = XXH::XXH64.hash("test data")
        hash.should eq(expected)
      end
    end

    it "accepts Path argument" do
      with_tempfile("test") do |path|
        hash = XXH::XXH64.hash_file(Path.new(path))
        expected = XXH::XXH64.hash("test")
        hash.should eq(expected)
      end
    end

    it "accepts String argument" do
      with_tempfile("test") do |path|
        hash = XXH::XXH64.hash_file(path)
        expected = XXH::XXH64.hash("test")
        hash.should eq(expected)
      end
    end

    it "hashes large file" do
      large_data = incremental_bytes(1_000_000)
      with_tempfile(String.new(large_data)) do |path|
        file_hash = XXH::XXH64.hash_file(path)
        memory_hash = XXH::XXH64.hash(large_data)
        file_hash.should eq(memory_hash)
      end
    end

    it "accepts seed parameter" do
      with_tempfile("test") do |path|
        hash_seed0 = XXH::XXH64.hash_file(path, 0_u64)
        hash_seed1 = XXH::XXH64.hash_file(path, 1_u64)
        hash_seed0.should_not eq(hash_seed1)
      end
    end
  end

  describe "consistency" do
    it "one-shot, io, and file produce same hash" do
      data = "test data for consistency"

      hash1 = XXH::XXH64.hash(data)
      io = IO::Memory.new(data)
      hash2 = XXH::XXH64.hash(io)

      with_tempfile(data) do |path|
        hash3 = XXH::XXH64.hash_file(path)

        hash1.should eq(hash2)
        hash1.should eq(hash3)
      end
    end

    it "chunked io matches streaming state" do
      data = "chunk1" + "chunk2" + "chunk3"

      io_hash = XXH::XXH64.hash(IO::Memory.new(data))

      state = XXH::XXH64::State.new
      state.update("chunk1".to_slice)
      state.update("chunk2".to_slice)
      state.update("chunk3".to_slice)
      state_hash = state.digest

      io_hash.should eq(state_hash)
    end
  end

  describe "large input performance check" do
    it "can hash 100MB without error" do
      size = 100_000_000
      # Create chunks to avoid memory issues
      sum = 0_u64
      chunk_size = 1_000_000
      (size // chunk_size).times do |i|
        chunk = Bytes.new(chunk_size) { |j| ((i * chunk_size + j) % 256).to_u8 }
        hash = XXH::XXH64.hash(chunk)
        sum = sum &+ hash # Track that we're running
      end
      sum.should be_a(UInt64)
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
