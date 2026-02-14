#!/usr/bin/env crystal
# Integration test: Compare xxhsum output against vendor C implementation
# Tests: hash output, formats, options, stdin, checksum verification

require "option_parser"
require "file"

class IntegrationTester
  property crystal_bin = "./bin/xxhsum"
  property vendor_bin = "vendor/xxHash/xxhsum"
  property test_files = [] of String
  property algorithms = [0, 1, 2, 3]
  property test_options = ["basic", "bsd", "stdin", "check", "little-endian", "benchmark", "benchmark-variants", "iterations", "block-size", "quiet", "status", "strict", "warn", "ignore-missing", "version"] of String
  property? verbose = false
  property passed = 0
  property failed = 0
  property skipped = 0
  property expected_failures = 0
  property? binary_mode_unsupported = false # Track if --binary is unsupported in our version

  def initialize
    parse_args
  end

  def parse_args
    OptionParser.parse do |parser|
      parser.on("-c", "--crystal=PATH", "Path to Crystal xxhsum") { |path| @crystal_bin = path }
      parser.on("-v", "--vendor=PATH", "Path to vendor xxhsum") { |path| @vendor_bin = path }
      parser.on("-f", "--file=FILE", "Test file (can specify multiple times)") { |file| @test_files << file }
      parser.on("-a", "--algorithm=NUM", "Algorithm to test (0,1,2,3 or all)") do |algo_str|
        if algo_str == "all"
          @algorithms = [0, 1, 2, 3]
        else
          @algorithms = [algo_str.to_i32]
        end
      end
      parser.on("-t", "--test=TYPE", "Test type (basic, bsd, stdin, check, little-endian, benchmark, benchmark-variants, iterations, block-size, quiet, status, strict, warn, ignore-missing, version, or all)") do |test_type|
        if test_type == "all"
          @test_options = ["basic", "bsd", "stdin", "check", "little-endian", "benchmark", "benchmark-variants", "iterations", "block-size", "quiet", "status", "strict", "warn", "ignore-missing", "version"]
        else
          @test_options = [test_type]
        end
      end
      parser.on("--verbose", "Verbose output") { @verbose = true }
      parser.on("-h", "--help", "Show help") { puts parser; exit }
    end
  end

  def run
    unless File.exists?(@crystal_bin)
      puts "ERROR: Crystal binary not found: #{@crystal_bin}"
      exit 1
    end

    unless File.exists?(@vendor_bin)
      puts "ERROR: Vendor binary not found: #{@vendor_bin}"
      exit 1
    end

    if @test_files.empty?
      # Use default test files
      @test_files = [
        "README.md",
        "LICENSE",
        "shard.yml",
      ].select { |file| File.exists?(file) }

      if @test_files.empty?
        puts "ERROR: No test files found. Provide with -f option."
        exit 1
      end
    end

    puts "Integration Test: xxhsum"
    puts "================================"
    puts "Crystal:  #{@crystal_bin}"
    puts "Vendor:   #{@vendor_bin}"
    puts "Files:    #{@test_files.join(", ")}"
    puts "Algos:    #{@algorithms.join(", ")}"
    puts "Tests:    #{@test_options.join(", ")}"
    puts "================================"
    puts

    @test_files.each do |file|
      @algorithms.each do |algo|
        @test_options.each do |test_type|
          execute_test_type(test_type, file, algo)
        end
      end
    end

    puts
    puts "Results: #{@passed} passed, #{@failed} failed, #{@skipped} skipped, #{@expected_failures} expected failures"
    exit @failed > 0 ? 1 : 0
  end

  private def test_hash(file : String, algo : Int32)
    algo_name = algo_to_name(algo)

    crystal_result = run_hash(@crystal_bin, file, algo)
    vendor_result = run_hash(@vendor_bin, file, algo)

    if crystal_result == vendor_result
      status = "✓ PASS"
      @passed += 1
    else
      status = "✗ FAIL"
      @failed += 1
    end

    puts "[#{status}] basic     #{File.basename(file)}  (#{algo_name})"
    if @verbose && crystal_result != vendor_result
      puts "       Crystal: #{crystal_result}"
      puts "       Vendor:  #{vendor_result}"
    end
  end

  # New test methods for additional flags

  private def test_benchmark
    crystal_result = run_command(@crystal_bin, ["-b", "-i3"])

    # Just check if output is valid (has expected format)
    if crystal_result.includes?("it/s") && !crystal_result.includes?("Error")
      status = "✓ PASS"
      @passed += 1
    else
      status = "✗ FAIL"
      @failed += 1
    end

    puts "[#{status}] benchmark all algorithms (-b)"
  rescue ex
    status = "⊘ SKIP"
    @skipped += 1
    puts "[#{status}] benchmark - #{ex.message}"
  end

  private def test_benchmark_variants
    # Test -b1,3,5 (comma-separated variants)
    crystal_result = run_command(@crystal_bin, ["-b1,3,5", "-i2"])

    # Check if all variants are in output
    status = if crystal_result.includes?("1#") && crystal_result.includes?("3#") && crystal_result.includes?("5#")
               @passed += 1
               "✓ PASS"
             else
               @failed += 1
               "✗ FAIL"
             end

    puts "[#{status}] benchmark variants (-b1, -b3, -b5)"
  rescue ex
    status = "⊘ SKIP"
    @skipped += 1
    puts "[#{status}] benchmark variants - #{ex.message}"
  end

  private def test_iterations
    # Test -i flag with fixed iteration count
    crystal_result = run_command(@crystal_bin, ["-b1", "-i50"])

    # Check if output has valid benchmark format
    if crystal_result.includes?("it/s") && !crystal_result.includes?("Error")
      status = "✓ PASS"
      @passed += 1
    else
      status = "✗ FAIL"
      @failed += 1
    end

    puts "[#{status}] iterations flag (-i#)"
  rescue ex
    status = "⊘ SKIP"
    @skipped += 1
    puts "[#{status}] iterations - #{ex.message}"
  end

  private def test_block_size
    # Test -B flag with various sizes
    crystal_result = run_command(@crystal_bin, ["-b1", "-B4K", "-i20"])

    # Check if output has valid benchmark format
    if crystal_result.includes?("it/s") && !crystal_result.includes?("Error")
      status = "✓ PASS"
      @passed += 1
    else
      status = "✗ FAIL"
      @failed += 1
    end

    puts "[#{status}] block-size flag (-B#)"
  rescue ex
    status = "⊘ SKIP"
    @skipped += 1
    puts "[#{status}] block-size - #{ex.message}"
  end

  # ameba:disable Metrics/CyclomaticComplexity
  private def execute_test_type(test_type : String, file : String, algo : Int32)
    case test_type
    when "basic"
      test_hash(file, algo)
    when "bsd"
      test_bsd_format(file, algo)
    when "stdin"
      test_stdin(file, algo)
    when "check"
      test_checksum_verification(file, algo)
    when "little-endian"
      test_little_endian(file, algo)
    when "benchmark"
      test_benchmark if algo == 0 # Only test once, not per algorithm
    when "benchmark-variants"
      test_benchmark_variants if algo == 0
    when "iterations"
      test_iterations if algo == 0
    when "block-size"
      test_block_size if algo == 0
    when "quiet"
      test_quiet_flag if algo == 0
    when "status"
      test_status_flag(file, algo)
    when "strict"
      test_strict_flag if algo == 0
    when "warn"
      test_warn_flag if algo == 0
    when "ignore-missing"
      test_ignore_missing_flag if algo == 0
    when "version"
      test_version if algo == 0
    end
  end

  private def test_quiet_flag
    # -q should suppress the version header in benchmark mode
    crystal_with_q = run_command(@crystal_bin, ["-b", "-q", "-i2"])
    crystal_without_q = run_command(@crystal_bin, ["-b", "-i2"])

    # With -q: no version header
    # Without -q: version header present ("xxhsum 0.8.3")
    has_version_without_q = crystal_without_q.includes?("xxhsum 0.8.3")
    has_version_with_q = crystal_with_q.includes?("xxhsum 0.8.3")

    if has_version_without_q && !has_version_with_q
      status = "✓ PASS"
      @passed += 1
    else
      status = "✗ FAIL"
      @failed += 1
    end

    puts "[#{status}] quiet flag (-q)"
  rescue ex
    status = "⊘ SKIP"
    @skipped += 1
    puts "[#{status}] quiet - #{ex.message}"
  end

  private def test_status_flag(file : String, algo : Int32)
    # Create a checksum file
    checksum_output = IO::Memory.new
    Process.run(@vendor_bin, ["-H#{algo}", file], output: checksum_output)
    checksum_line = checksum_output.to_s.strip

    checksum_file = "/tmp/xxhsum_status_#{Process.pid}_#{algo}.txt"
    File.write(checksum_file, "#{checksum_line}\n")

    begin
      # Test with --status flag (should have success exit code)
      crystal_status = Process.run(@crystal_bin, ["-c", "--status", checksum_file]).success?
      vendor_status = Process.run(@vendor_bin, ["-c", "--status", checksum_file]).success?

      if crystal_status == vendor_status
        status = "✓ PASS"
        @passed += 1
      else
        status = "✗ FAIL"
        @failed += 1
      end

      puts "[#{status}] status    (--status flag)"
    ensure
      File.delete(checksum_file) if File.exists?(checksum_file)
    end
  rescue ex
    status = "⊘ SKIP"
    @skipped += 1
    puts "[#{status}] status - #{ex.message}"
  end

  private def test_strict_flag
    # Create a malformed checksum file
    strict_file = "/tmp/xxhsum_strict_#{Process.pid}.txt"
    File.write(strict_file, "invalid checksum line\n")

    begin
      crystal_exit = Process.run(@crystal_bin, ["-c", "--strict", strict_file]).exit_code
      vendor_exit = Process.run(@vendor_bin, ["-c", "--strict", strict_file]).exit_code

      # Both should fail (non-zero exit code)
      if (crystal_exit != 0) && (vendor_exit != 0)
        status = "✓ PASS"
        @passed += 1
      else
        status = "✗ FAIL"
        @failed += 1
      end

      puts "[#{status}] strict    (--strict flag)"
    ensure
      File.delete(strict_file) if File.exists?(strict_file)
    end
  rescue ex
    status = "⊘ SKIP"
    @skipped += 1
    puts "[#{status}] strict - #{ex.message}"
  end

  private def test_warn_flag
    # Create a checksum file with a warning (e.g., extra spaces)
    warn_file = "/tmp/xxhsum_warn_#{Process.pid}.txt"
    File.write(warn_file, "abcd1234 file.txt  \n") # Extra spaces

    begin
      crystal_result = run_command(@crystal_bin, ["-c", "--warn", warn_file])
      vendor_result = run_command(@vendor_bin, ["-c", "--warn", warn_file])

      # Both should produce some output
      if crystal_result.size > 0 && vendor_result.size > 0
        status = "✓ PASS"
        @passed += 1
      else
        status = "✗ FAIL"
        @failed += 1
      end

      puts "[#{status}] warn      (--warn flag)"
    ensure
      File.delete(warn_file) if File.exists?(warn_file)
    end
  rescue ex
    status = "⊘ SKIP"
    @skipped += 1
    puts "[#{status}] warn - #{ex.message}"
  end

  private def test_ignore_missing_flag
    # Test with non-existent file
    checksum_file = "/tmp/xxhsum_ignore_#{Process.pid}.txt"
    File.write(checksum_file, "abcd1234 /nonexistent/file\n")

    begin
      crystal_status = Process.run(@crystal_bin, ["-c", "--ignore-missing", checksum_file]).success?
      vendor_status = Process.run(@vendor_bin, ["-c", "--ignore-missing", checksum_file]).success?

      if crystal_status == vendor_status
        status = "✓ PASS"
        @passed += 1
      else
        status = "✗ FAIL"
        @failed += 1
      end

      puts "[#{status}] ignore-missing (--ignore-missing flag)"
    ensure
      File.delete(checksum_file) if File.exists?(checksum_file)
    end
  rescue ex
    status = "⊘ SKIP"
    @skipped += 1
    puts "[#{status}] ignore-missing - #{ex.message}"
  end

  private def test_version
    crystal_result = run_command(@crystal_bin, ["-V"], 10)

    # Crystal should display version information
    crystal_has_version = !crystal_result.includes?("Error") && crystal_result.includes?("xxhsum")

    if crystal_has_version
      status = "✓ PASS"
      @passed += 1
    else
      status = "✗ FAIL"
      @failed += 1
    end

    puts "[#{status}] version   (-V flag)"
    if @verbose
      puts "       Crystal: #{crystal_result[0..50]}"
    end
  rescue ex
    status = "⊘ SKIP"
    @skipped += 1
    puts "[#{status}] version - #{ex.message}"
  end

  private def test_bsd_format(file : String, algo : Int32)
    algo_name = algo_to_name(algo)

    crystal_result = run_command(@crystal_bin, ["--tag", "-H#{algo}", file])
    vendor_result = run_command(@vendor_bin, ["--tag", "-H#{algo}", file])

    if crystal_result == vendor_result
      status = "✓ PASS"
      @passed += 1
    else
      status = "✗ FAIL"
      @failed += 1
    end

    puts "[#{status}] bsd       #{File.basename(file)}  (#{algo_name})"
    if @verbose && crystal_result != vendor_result
      puts "       Crystal: #{crystal_result.lines.first? || "ERROR"}"
      puts "       Vendor:  #{vendor_result.lines.first? || "ERROR"}"
    end
  end

  private def test_stdin(file : String, algo : Int32)
    algo_name = algo_to_name(algo)

    # Compare stdin hashing
    crystal_result = IO::Memory.new
    vendor_result = IO::Memory.new

    crystal_proc = Process.new(@crystal_bin, ["-H#{algo}"], input: Process::Redirect::Pipe, output: crystal_result)
    Process.run("cat", [file], output: crystal_proc.input)
    vendor_proc = Process.new(@vendor_bin, ["-H#{algo}"], input: Process::Redirect::Pipe, output: vendor_result)
    Process.run("cat", [file], output: vendor_proc.input)

    crystal_hash = crystal_result.to_s.split(" ")[0]
    vendor_hash = vendor_result.to_s.split(" ")[0]

    if crystal_hash == vendor_hash
      status = "✓ PASS"
      @passed += 1
    else
      status = "✗ FAIL"
      @failed += 1
    end

    puts "[#{status}] stdin     #{File.basename(file)}  (#{algo_name})"
    if @verbose && crystal_hash != vendor_hash
      puts "       Crystal: #{crystal_hash}"
      puts "       Vendor:  #{vendor_hash}"
    end
  rescue ex
    status = "⊘ SKIP"
    @skipped += 1
    puts "[#{status}] stdin     #{File.basename(file)}  (#{algo_name}) - #{ex.message}"
  end

  private def test_checksum_verification(file : String, algo : Int32)
    algo_name = algo_to_name(algo)

    # Generate checksum file
    checksum_output = IO::Memory.new
    Process.run(@vendor_bin, ["-H#{algo}", file], output: checksum_output)
    checksum_line = checksum_output.to_s.strip

    # Write to temp file in /tmp
    checksum_file = "/tmp/xxhsum_check_#{Process.pid}_#{algo}.txt"
    File.write(checksum_file, "#{checksum_line}\n")

    begin
      # Test both implementations
      crystal_check = Process.run(@crystal_bin, ["-c", checksum_file]).success?
      vendor_check = Process.run(@vendor_bin, ["-c", checksum_file]).success?

      if crystal_check == vendor_check
        status = "✓ PASS"
        @passed += 1
      else
        status = "✗ FAIL"
        @failed += 1
      end

      puts "[#{status}] check     #{File.basename(file)}  (#{algo_name})"
      if @verbose
        puts "       Crystal success: #{crystal_check}"
        puts "       Vendor success:  #{vendor_check}"
      end
    ensure
      File.delete(checksum_file) if File.exists?(checksum_file)
    end
  rescue ex
    status = "⊘ SKIP"
    @skipped += 1
    puts "[#{status}] check     #{File.basename(file)}  (#{algo_name}) - #{ex.message}"
  end

  private def test_little_endian(file : String, algo : Int32)
    algo_name = algo_to_name(algo)

    crystal_result = run_command(@crystal_bin, ["--little-endian", "-H#{algo}", file])
    vendor_result = run_command(@vendor_bin, ["--little-endian", "-H#{algo}", file])

    if crystal_result == vendor_result
      status = "✓ PASS"
      @passed += 1
    else
      status = "✗ FAIL"
      @failed += 1
    end

    puts "[#{status}] le-endian #{File.basename(file)}  (#{algo_name})"
    if @verbose && crystal_result != vendor_result
      puts "       Crystal: #{crystal_result.lines.first? || "ERROR"}"
      puts "       Vendor:  #{vendor_result.lines.first? || "ERROR"}"
    end
  rescue ex
    status = "⊘ SKIP"
    @skipped += 1
    puts "[#{status}] le-endian #{File.basename(file)}  (#{algo_name}) - #{ex.message}"
  end

  private def algo_to_name(algo : Int32) : String
    case algo
    when 0 then "XXH32"
    when 1 then "XXH64"
    when 2 then "XXH128"
    when 3 then "XXH3"
    else        "UNKNOWN"
    end
  end

  private def run_hash(bin : String, file : String, algo : Int32) : String
    result = IO::Memory.new
    Process.run(bin, ["-H#{algo}", file], output: result)
    result.to_s.split(" ")[0]
  rescue ex
    "ERROR: #{ex.message}"
  end

  private def run_command(bin : String, args : Array(String), timeout_secs : Int32 = 3) : String
    result = IO::Memory.new
    error = IO::Memory.new

    # Use shell timeout to limit execution
    cmd = ["timeout", timeout_secs.to_s, bin] + args
    Process.run(cmd[0], cmd[1..], output: result, error: error)
    result.to_s.strip
  rescue ex
    "ERROR: #{ex.message}"
  end
end

if ARGV.includes?("-h") || ARGV.includes?("--help")
  puts "Usage: spec/integration_test.cr [options]"
  puts ""
  puts "Options:"
  puts "  -c PATH, --crystal=PATH    Path to Crystal xxhsum (default: ./bin/xxhsum)"
  puts "  -v PATH, --vendor=PATH     Path to vendor xxhsum"
  puts "  -f FILE, --file=FILE       Test file (can specify multiple times)"
  puts "  -a NUM, --algorithm=NUM    Algorithm 0-3 or 'all' (default: all)"
  puts "  -t TYPE, --test=TYPE       Test type: basic, bsd, stdin, check, little-endian, or 'all'"
  puts "  --verbose                  Show detailed comparison"
  exit
end

tester = IntegrationTester.new
tester.run
