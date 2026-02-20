require "./spec_helper"

describe "XXHSum benchmark mode" do
  it "runs default benchmark set with -b" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    code = XXHSum::CLI.run(["-b", "-i1", "-B1K"], stdout: stdout, stderr: stderr, stdin_tty: true)

    code.should eq(0)
    output = stdout.to_s
    output.should contain("Sample of")
    output.should contain("1#XXH32")
    output.should contain("3#XXH64")
    output.should contain("5#XXH3_64b")
    output.should contain("11#XXH128")
    stderr.to_s.should eq("")
  end

  it "runs one selected variant with -b#" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    code = XXHSum::CLI.run(["-b7", "-i1", "-B1K", "-q"], stdout: stdout, stderr: stderr, stdin_tty: true)

    code.should eq(0)
    output = stdout.to_s
    output.should_not contain("xxhsum Crystal benchmark mode")
    output.should contain("7#XXH3_64b w/seed")
    output.should_not contain("1#XXH32")
    stderr.to_s.should eq("")
  end

  it "runs amortized streaming XXH3 with -b29" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    code = XXHSum::CLI.run(["-b29", "-i1", "-B1K", "-q"], stdout: stdout, stderr: stderr, stdin_tty: true)

    code.should eq(0)
    output = stdout.to_s
    output.should contain("29#XXH3_stream amortized")
    stderr.to_s.should eq("")
  end

  it "runs amortized streaming XXH64 with -b31" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    code = XXHSum::CLI.run(["-b31", "-i1", "-B1K", "-q"], stdout: stdout, stderr: stderr, stdin_tty: true)

    code.should eq(0)
    output = stdout.to_s
    output.should contain("31#XXH64_stream amortized")
    stderr.to_s.should eq("")
  end

  it "runs amortized streaming XXH128 with -b33" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    code = XXHSum::CLI.run(["-b33", "-i1", "-B1K", "-q"], stdout: stdout, stderr: stderr, stdin_tty: true)

    code.should eq(0)
    output = stdout.to_s
    output.should contain("33#XXH128_stream amortized")
    stderr.to_s.should eq("")
  end

  it "runs all variants with -b0" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    code = XXHSum::CLI.run(["-b0", "-i1", "-B1K", "-q"], stdout: stdout, stderr: stderr, stdin_tty: true)

    code.should eq(0)
    output = stdout.to_s
    output.should contain(" 1#XXH32")
    output.should contain("28#XXH128_stream w/seed unaligned")
    # New amortized streaming variants (realistic streaming throughput)
    output.should contain("29#XXH3_stream amortized")
    output.should contain("30#XXH3_stream amortized unaligned")
    output.should contain("31#XXH64_stream amortized")
    output.should contain("32#XXH64_stream amortized unaligned")
    output.should contain("33#XXH128_stream amortized")
    output.should contain("34#XXH128_stream amortized unaligned")
    stderr.to_s.should eq("")
  end

  it "parses block-size suffixes for -B#" do
    opts = XXHSum::CLI::Options.parse(["-b", "-B64K", "-i2"])
    opts.benchmark.should be_true
    opts.benchmark_size.should eq(64_u64 * 1024_u64) # 1024-based binary kilobytes
    opts.benchmark_iterations.should eq(2)
  end

  it "runs all variants with --bench-all" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    code = XXHSum::CLI.run(["--bench-all", "-i1", "-B1K", "-q"], stdout: stdout, stderr: stderr, stdin_tty: true)

    code.should eq(0)
    output = stdout.to_s
    output.should contain(" 1#XXH32")
    output.should contain("28#XXH128_stream w/seed unaligned")
    stderr.to_s.should eq("")
  end

  it "parses --bench-all option" do
    opts = XXHSum::CLI::Options.parse(["--bench-all", "-i2"])
    opts.benchmark.should be_true
    opts.benchmark_all.should be_true
    opts.benchmark_ids.should be_empty
    opts.benchmark_iterations.should eq(2)
  end

  it "outputs carriage return for live-update during calibration" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    # Use -i2 to ensure at least one live-update (\r) before final result (\n)
    code = XXHSum::CLI.run(["-b7", "-i2", "-B1K", "-q"], stdout: stdout, stderr: stderr, stdin_tty: true)

    code.should eq(0)
    output = stdout.to_s
    # Should contain at least one carriage return from the first iteration
    output.should contain("\r")
    # Should also contain the final newline
    output.should contain("\n")
    # Verify that -i2 ran both iterations (intermediate and final)
    output.should contain("7#XXH3_64b w/seed")
    stderr.to_s.should eq("")
  end

  it "parses comma-separated benchmark IDs with -b1,3,5,11" do
    opts = XXHSum::CLI::Options.parse(["-b1,3,5,11", "-i2"])
    opts.benchmark.should be_true
    opts.benchmark_ids.should eq([1, 3, 5, 11])
    opts.benchmark_iterations.should eq(2)
  end

  it "parses -bi1 compact form" do
    opts = XXHSum::CLI::Options.parse(["-bi1", "-B64K"])
    opts.benchmark.should be_true
    opts.benchmark_iterations.should eq(1)
    opts.benchmark_ids.should be_empty
  end

  it "parses range -b1-3" do
    opts = XXHSum::CLI::Options.parse(["-b1-3", "-i2"])
    opts.benchmark.should be_true
    opts.benchmark_ids.should eq([1, 2, 3])
    opts.benchmark_iterations.should eq(2)
  end

  it "runs comma-separated benchmark variants" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    code = XXHSum::CLI.run(["-b1,3,5", "-i1", "-B1K", "-q"], stdout: stdout, stderr: stderr, stdin_tty: true)

    code.should eq(0)
    output = stdout.to_s
    output.should contain("1#XXH32")
    output.should contain("3#XXH64")
    output.should contain("5#XXH3_64b")
    output.should_not contain("11#XXH128") # Not in the comma-separated list
    stderr.to_s.should eq("")
  end
end
