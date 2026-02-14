require "./spec_helper"

describe XXH::XXH32 do
  describe ".hash" do
    it "matches official test vectors (no seed)" do
      TEST_VECTORS_XXH32.each do |(input, seed), expected|
        next unless seed == 0_u32
        XXH::XXH32.hash(input).should eq(expected)
      end
    end

    it "matches official test vectors (with seed)" do
      TEST_VECTORS_XXH32.each do |(input, seed), expected|
        XXH::XXH32.hash(input, seed).should eq(expected)
      end
    end

    it "accepts String input" do
      result = XXH::XXH32.hash("test")
      result.should be_a(UInt32)
    end

    it "accepts Bytes input" do
      result = XXH::XXH32.hash("test".to_slice)
      result.should be_a(UInt32)
    end

    it "string and bytes produce same hash" do
      XXH::XXH32.hash("test").should eq(XXH::XXH32.hash("test".to_slice))
    end

    it "uses default seed of 0" do
      XXH::XXH32.hash("test").should eq(XXH::XXH32.hash("test", 0_u32))
    end

    it "produces different hashes for different seeds" do
      hash1 = XXH::XXH32.hash("test", 0_u32)
      hash2 = XXH::XXH32.hash("test", 1_u32)
      hash1.should_not eq(hash2)
    end

    it "handles empty input" do
      XXH::XXH32.hash("").should eq(0x02cc5d05_u32)
    end

    it "handles large input (1MB)" do
      large_data = incremental_bytes(1_000_000)
      hash = XXH::XXH32.hash(large_data)
      hash.should be_a(UInt32)
    end

    it "handles random data" do
      random_data = random_bytes(1024)
      hash = XXH::XXH32.hash(random_data)
      hash.should be_a(UInt32)
    end
  end

  describe ".hash(io)" do
    it "hashes IO stream" do
      io = IO::Memory.new("test data")
      hash = XXH::XXH32.hash(io)
      expected = XXH::XXH32.hash("test data")
      hash.should eq(expected)
    end

    it "hashes large IO stream" do
      large_data = incremental_bytes(100_000)
      io = IO::Memory.new(large_data)
      hash = XXH::XXH32.hash(io)
      expected = XXH::XXH32.hash(large_data)
      hash.should eq(expected)
    end

    it "accepts seed parameter" do
      io = IO::Memory.new("test")
      hash_seed0 = XXH::XXH32.hash(IO::Memory.new("test"), 0_u32)
      hash_seed1 = XXH::XXH32.hash(IO::Memory.new("test"), 1_u32)
      hash_seed0.should_not eq(hash_seed1)
    end
  end

  describe ".hash_file" do
    it "hashes file contents" do
      with_tempfile("test data") do |path|
        hash = XXH::XXH32.hash_file(path)
        expected = XXH::XXH32.hash("test data")
        hash.should eq(expected)
      end
    end

    it "accepts Path argument" do
      with_tempfile("test") do |path|
        hash = XXH::XXH32.hash_file(Path.new(path))
        expected = XXH::XXH32.hash("test")
        hash.should eq(expected)
      end
    end

    it "accepts String argument" do
      with_tempfile("test") do |path|
        hash = XXH::XXH32.hash_file(path)
        expected = XXH::XXH32.hash("test")
        hash.should eq(expected)
      end
    end

    it "hashes large file" do
      large_data = incremental_bytes(1_000_000)
      with_tempfile(String.new(large_data)) do |path|
        file_hash = XXH::XXH32.hash_file(path)
        memory_hash = XXH::XXH32.hash(large_data)
        file_hash.should eq(memory_hash)
      end
    end

    it "accepts seed parameter" do
      with_tempfile("test") do |path|
        hash_seed0 = XXH::XXH32.hash_file(path, 0_u32)
        hash_seed1 = XXH::XXH32.hash_file(path, 1_u32)
        hash_seed0.should_not eq(hash_seed1)
      end
    end
  end

  describe "consistency" do
    it "one-shot, io, and file produce same hash" do
      data = "test data for consistency"

      # One-shot
      hash1 = XXH::XXH32.hash(data)

      # IO
      io = IO::Memory.new(data)
      hash2 = XXH::XXH32.hash(io)

      # File
      with_tempfile(data) do |path|
        hash3 = XXH::XXH32.hash_file(path)

        hash1.should eq(hash2)
        hash1.should eq(hash3)
      end
    end

    it "chunked io matches streaming state" do
      data = "chunk1" + "chunk2" + "chunk3"

      # Via IO
      io_hash = XXH::XXH32.hash(IO::Memory.new(data))

      # Via State (manual chunking)
      state = XXH::XXH32::State.new
      state.update("chunk1")
      state.update("chunk2")
      state.update("chunk3")
      state_hash = state.digest

      io_hash.should eq(state_hash)
    end
  end
end

# Helper to create temporary files
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
