require "./spec_helper"

describe "Safe Bindings Layer" do
  describe "XXH32 Bindings consistency" do
    it "hash(bytes) == hash(string)" do
      data = "test data"
      bytes_hash = XXH::Bindings::XXH32.hash(data.to_slice)
      string_hash = XXH::Bindings::XXH32.hash(data)
      bytes_hash.should eq(string_hash)
    end

    it "hash(io) == hash(bytes)" do
      data = "test data"
      bytes_hash = XXH::Bindings::XXH32.hash(data.to_slice)
      io_hash = XXH::Bindings::XXH32.hash(IO::Memory.new(data))
      bytes_hash.should eq(io_hash)
    end

    it "hash_file() == hash(bytes)" do
      data = "test data"
      bytes_hash = XXH::Bindings::XXH32.hash(data.to_slice)

      with_tempfile(data) do |path|
        file_hash = XXH::Bindings::XXH32.hash_file(path)
        bytes_hash.should eq(file_hash)
      end
    end

    it "seeded variants match" do
      data = "test"
      seed = 0x12345678_u32

      bytes_hash = XXH::Bindings::XXH32.hash(data.to_slice, seed)
      io_hash = XXH::Bindings::XXH32.hash(IO::Memory.new(data), seed)

      bytes_hash.should eq(io_hash)
    end
  end

  describe "XXH64 Bindings consistency" do
    it "hash(bytes) == hash(string)" do
      data = "test data"
      bytes_hash = XXH::Bindings::XXH64.hash(data.to_slice)
      string_hash = XXH::Bindings::XXH64.hash(data)
      bytes_hash.should eq(string_hash)
    end

    it "hash(io) == hash(bytes)" do
      data = "test data"
      bytes_hash = XXH::Bindings::XXH64.hash(data.to_slice)
      io_hash = XXH::Bindings::XXH64.hash(IO::Memory.new(data))
      bytes_hash.should eq(io_hash)
    end

    it "hash_file() == hash(bytes)" do
      data = "test data"
      bytes_hash = XXH::Bindings::XXH64.hash(data.to_slice)

      with_tempfile(data) do |path|
        file_hash = XXH::Bindings::XXH64.hash_file(path)
        bytes_hash.should eq(file_hash)
      end
    end

    it "seeded variants match" do
      data = "test"
      seed = 0x123456789ABCDEF0_u64

      bytes_hash = XXH::Bindings::XXH64.hash(data.to_slice, seed)
      io_hash = XXH::Bindings::XXH64.hash(IO::Memory.new(data), seed)

      bytes_hash.should eq(io_hash)
    end
  end

  describe "XXH3_64 Bindings consistency" do
    it "hash(bytes) == hash(string)" do
      data = "test data"
      bytes_hash = XXH::Bindings::XXH3_64.hash(data.to_slice)
      string_hash = XXH::Bindings::XXH3_64.hash(data)
      bytes_hash.should eq(string_hash)
    end

    it "hash(io) == hash(bytes)" do
      data = "test data"
      bytes_hash = XXH::Bindings::XXH3_64.hash(data.to_slice)
      io_hash = XXH::Bindings::XXH3_64.hash(IO::Memory.new(data))
      bytes_hash.should eq(io_hash)
    end

    it "hash_file() == hash(bytes)" do
      data = "test data"
      bytes_hash = XXH::Bindings::XXH3_64.hash(data.to_slice)

      with_tempfile(data) do |path|
        file_hash = XXH::Bindings::XXH3_64.hash_file(path)
        bytes_hash.should eq(file_hash)
      end
    end

    it "seeded variants match" do
      data = "test"
      seed = 0x123456789ABCDEF0_u64

      bytes_hash = XXH::Bindings::XXH3_64.hash(data.to_slice, seed)
      io_hash = XXH::Bindings::XXH3_64.hash(IO::Memory.new(data), seed)

      bytes_hash.should eq(io_hash)
    end
  end

  describe "XXH3_128 Bindings consistency" do
    it "hash(bytes) == hash(string)" do
      data = "test data"
      bytes_hash = XXH::Bindings::XXH3_128.hash(data.to_slice)
      string_hash = XXH::Bindings::XXH3_128.hash(data)
      bytes_hash.should eq(string_hash)
    end

    it "hash(io) == hash(bytes)" do
      data = "test data"
      bytes_hash = XXH::Bindings::XXH3_128.hash(data.to_slice)
      io_hash = XXH::Bindings::XXH3_128.hash(IO::Memory.new(data))
      bytes_hash.should eq(io_hash)
    end

    it "hash_file() == hash(bytes)" do
      data = "test data"
      bytes_hash = XXH::Bindings::XXH3_128.hash(data.to_slice)

      with_tempfile(data) do |path|
        file_hash = XXH::Bindings::XXH3_128.hash_file(path)
        bytes_hash.should eq(file_hash)
      end
    end

    it "seeded variants match" do
      data = "test"
      seed = 0x123456789ABCDEF0_u64

      bytes_hash = XXH::Bindings::XXH3_128.hash(data.to_slice, seed)
      io_hash = XXH::Bindings::XXH3_128.hash(IO::Memory.new(data), seed)

      bytes_hash.should eq(io_hash)
    end
  end

  describe "Version helpers" do
    it "Version.number returns UInt32" do
      version = XXH::Bindings::Version.number
      version.should be_a(UInt32)
    end

    it "Version.to_s returns String" do
      version_str = XXH::Bindings::Version.to_s
      version_str.should be_a(String)
      version_str.should match(/\d+\.\d+\.\d+/)
    end

    it "Version number is consistent" do
      v1 = XXH::Bindings::Version.number
      v2 = XXH::Bindings::Version.number
      v1.should eq(v2)
    end

    it "Version string is consistent" do
      v1 = XXH::Bindings::Version.to_s
      v2 = XXH::Bindings::Version.to_s
      v1.should eq(v2)
    end
  end

  describe "Large file handling via bindings" do
    it "handles 10MB file with XXH32" do
      size = 10_000_000
      data = incremental_bytes(size)

      bytes_hash = XXH::Bindings::XXH32.hash(data)

      with_tempfile(String.new(data)) do |path|
        file_hash = XXH::Bindings::XXH32.hash_file(path)
        file_hash.should eq(bytes_hash)
      end
    end

    it "handles 10MB file with XXH64" do
      size = 10_000_000
      data = incremental_bytes(size)

      bytes_hash = XXH::Bindings::XXH64.hash(data)

      with_tempfile(String.new(data)) do |path|
        file_hash = XXH::Bindings::XXH64.hash_file(path)
        file_hash.should eq(bytes_hash)
      end
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
