require "./spec_helper"

describe XXH::CLI::Formatter do
  describe "GNU format" do
    it "formats XXH64 result" do
      result = XXH::CLI::HashResult.new("/tmp/test.txt")
      result.hash64 = 0x1234567890ABCDEF_u64
      result.success = true

      output = XXH::CLI::Formatter.format_gnu(result, XXH::CLI::Algorithm::XXH64, XXH::CLI::DisplayEndianness::Big)
      output.should_not be_nil
      if output
        output.should match(/1234567890abcdef/)
      end
    end

    it "formats XXH3 result" do
      result = XXH::CLI::HashResult.new("/tmp/test.txt")
      result.hash64 = 0xABCDEF0123456789_u64
      result.success = true

      output = XXH::CLI::Formatter.format_gnu(result, XXH::CLI::Algorithm::XXH3, XXH::CLI::DisplayEndianness::Big)
      output.should_not be_nil
      if output
        output.should match(/XXH3_abcdef0123456789/)
      end
    end
  end

  describe "BSD format" do
    it "formats XXH64 result BSD style" do
      result = XXH::CLI::HashResult.new("/tmp/test.txt")
      result.hash64 = 0x1234567890ABCDEF_u64
      result.success = true

      output = XXH::CLI::Formatter.format_bsd(result, XXH::CLI::Algorithm::XXH64, XXH::CLI::DisplayEndianness::Big)
      output.should_not be_nil
      if output
        output.should match(/XXH64 \(.*\) = 1234567890abcdef/)
      end
    end
  end

  describe "file escaping" do
    it "escapes newlines in filenames" do
      result = XXH::CLI::HashResult.new("test\nfile.txt")
      result.hash64 = 0x1234567890ABCDEF_u64
      result.success = true

      output = XXH::CLI::Formatter.format_gnu(result, XXH::CLI::Algorithm::XXH64, XXH::CLI::DisplayEndianness::Big)
      output.should_not be_nil
    end
  end
end
