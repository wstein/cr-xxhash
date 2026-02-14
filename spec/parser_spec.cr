require "./spec_helper"
require "../src/cli/options"

describe XXH::CLI::Parser do
  describe "file arguments" do
    it "captures single file" do
      parser = XXH::CLI::Parser.new(["/tmp/test.txt"])
      parser.parse.should be_true
      parser.options.files.should eq ["/tmp/test.txt"]
    end

    it "captures multiple files" do
      parser = XXH::CLI::Parser.new(["/tmp/test1.txt", "/tmp/test2.txt"])
      parser.parse.should be_true
      parser.options.files.should eq ["/tmp/test1.txt", "/tmp/test2.txt"]
    end

    it "captures files after options" do
      parser = XXH::CLI::Parser.new(["-H3", "/tmp/test.txt"])
      parser.parse.should be_true
      parser.options.algorithm.should eq XXH::CLI::Algorithm::XXH3
      parser.options.files.should eq ["/tmp/test.txt"]
    end

    it "captures files after multiple options" do
      parser = XXH::CLI::Parser.new(["-H3", "--tag", "/tmp/test.txt", "/tmp/test2.txt"])
      parser.parse.should be_true
      parser.options.algorithm.should eq XXH::CLI::Algorithm::XXH3
      parser.options.tag?.should be_true
      parser.options.files.should eq ["/tmp/test.txt", "/tmp/test2.txt"]
    end
  end

  describe "algorithm selection" do
    it "defaults to XXH64" do
      parser = XXH::CLI::Parser.new([] of String)
      parser.parse.should be_true
      parser.options.algorithm.should eq XXH::CLI::Algorithm::XXH64
    end

    it "selects XXH32 with -H0" do
      parser = XXH::CLI::Parser.new(["-H0"])
      parser.parse.should be_true
      parser.options.algorithm.should eq XXH::CLI::Algorithm::XXH32
    end

    it "selects XXH32 with -H32" do
      parser = XXH::CLI::Parser.new(["-H32"])
      parser.parse.should be_true
      parser.options.algorithm.should eq XXH::CLI::Algorithm::XXH32
    end

    it "selects XXH64 with -H1" do
      parser = XXH::CLI::Parser.new(["-H1"])
      parser.parse.should be_true
      parser.options.algorithm.should eq XXH::CLI::Algorithm::XXH64
    end

    it "selects XXH128 with -H2" do
      parser = XXH::CLI::Parser.new(["-H2"])
      parser.parse.should be_true
      parser.options.algorithm.should eq XXH::CLI::Algorithm::XXH128
    end

    it "selects XXH3 with -H3" do
      parser = XXH::CLI::Parser.new(["-H3"])
      parser.parse.should be_true
      parser.options.algorithm.should eq XXH::CLI::Algorithm::XXH3
    end
  end

  describe "mode selection" do
    it "defaults to Hash mode" do
      parser = XXH::CLI::Parser.new([] of String)
      parser.parse.should be_true
      parser.options.mode.should eq XXH::CLI::Options::Mode::Hash
    end

    it "selects Check mode with -c" do
      parser = XXH::CLI::Parser.new(["-c"])
      parser.parse.should be_true
      parser.options.mode.should eq XXH::CLI::Options::Mode::Check
    end

    it "selects Benchmark mode with -b" do
      parser = XXH::CLI::Parser.new(["-b"])
      parser.parse.should be_true
      parser.options.mode.should eq XXH::CLI::Options::Mode::Benchmark
    end

    it "selects FilesFrom mode with --files-from" do
      parser = XXH::CLI::Parser.new(["--files-from=/tmp/list.txt"])
      parser.parse.should be_true
      parser.options.mode.should eq XXH::CLI::Options::Mode::FilesFrom
      parser.options.files.should eq ["/tmp/list.txt"]
    end

    it "selects FilesFrom mode with --filelist" do
      parser = XXH::CLI::Parser.new(["--filelist=/tmp/list.txt"])
      parser.parse.should be_true
      parser.options.mode.should eq XXH::CLI::Options::Mode::FilesFrom
    end
  end

  describe "output format options" do
    it "defaults to GNU convention" do
      parser = XXH::CLI::Parser.new([] of String)
      parser.parse.should be_true
      parser.options.convention.should eq XXH::CLI::DisplayConvention::GNU
    end

    it "switches to BSD convention with --tag" do
      parser = XXH::CLI::Parser.new(["--tag"])
      parser.parse.should be_true
      parser.options.convention.should eq XXH::CLI::DisplayConvention::BSD
      parser.options.tag?.should be_true
    end

    it "sets little-endian with --little-endian" do
      parser = XXH::CLI::Parser.new(["--little-endian"])
      parser.parse.should be_true
      parser.options.endianness.should eq XXH::CLI::DisplayEndianness::Little
    end

    it "defaults to big-endian" do
      parser = XXH::CLI::Parser.new([] of String)
      parser.parse.should be_true
      parser.options.endianness.should eq XXH::CLI::DisplayEndianness::Big
    end
  end

  describe "benchmark options" do
    it "sets iterations with -i" do
      parser = XXH::CLI::Parser.new(["-b", "-i100"])
      parser.parse.should be_true
      parser.options.iterations.should eq 100
    end

    it "sets iterations with --iterations" do
      parser = XXH::CLI::Parser.new(["-b", "--iterations=50"])
      parser.parse.should be_true
      parser.options.iterations.should eq 50
    end

    it "sets benchmark_all with --bench-all" do
      parser = XXH::CLI::Parser.new(["--bench-all"])
      parser.parse.should be_true
      parser.options.benchmark_all?.should be_true
      parser.options.mode.should eq XXH::CLI::Options::Mode::Benchmark
    end
  end

  describe "quiet and status flags" do
    it "sets quiet with -q" do
      parser = XXH::CLI::Parser.new(["-q"])
      parser.parse.should be_true
      parser.options.quiet?.should be_true
    end

    it "sets status with --status" do
      parser = XXH::CLI::Parser.new(["--status"])
      parser.parse.should be_true
      parser.options.status?.should be_true
    end
  end
end
