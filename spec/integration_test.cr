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
  property test_options = ["basic", "bsd", "stdin", "check", "little-endian"] of String
  property verbose = false
  property passed = 0
  property failed = 0
  property skipped = 0

  def initialize
    parse_args
  end

  def parse_args
    OptionParser.parse do |parser|
      parser.on("-c", "--crystal=PATH", "Path to Crystal xxhsum") { |p| @crystal_bin = p }
      parser.on("-v", "--vendor=PATH", "Path to vendor xxhsum") { |p| @vendor_bin = p }
      parser.on("-f", "--file=FILE", "Test file (can specify multiple times)") { |f| @test_files << f }
      parser.on("-a", "--algorithm=NUM", "Algorithm to test (0,1,2,3 or all)") do |a|
        if a == "all"
          @algorithms = [0, 1, 2, 3]
        else
          @algorithms = [a.to_i32]
        end
      end
      parser.on("-t", "--test=TYPE", "Test type (basic, bsd, stdin, check, little-endian, or all)") do |t|
        if t == "all"
          @test_options = ["basic", "bsd", "stdin", "check", "little-endian"]
        else
          @test_options = [t]
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
      ].select { |f| File.exists?(f) }

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
          end
        end
      end
    end

    puts
    puts "Results: #{@passed} passed, #{@failed} failed, #{@skipped} skipped"
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

    Process.run("cat", [file], output: Process.new(@crystal_bin, ["-H#{algo}"], input: Process::Redirect::Pipe, output: crystal_result).input.not_nil!)
    Process.run("cat", [file], output: Process.new(@vendor_bin, ["-H#{algo}"], input: Process::Redirect::Pipe, output: vendor_result).input.not_nil!)

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

  private def run_command(bin : String, args : Array(String)) : String
    result = IO::Memory.new
    Process.run(bin, args, output: result)
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
