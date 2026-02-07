#!/usr/bin/env crystal
# Benchmark variant integration tests
# Tests: all 28 benchmark variants, aligned/unaligned, seeded, secret, streaming

require "option_parser"

class BenchmarkVariantTester
  property crystal_bin = "./bin/xxhsum"
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
      parser.on("--verbose", "Verbose output") { @verbose = true }
      parser.on("-h", "--help", "Show help") do
        puts "Benchmark Variant Tester"
        puts parser
        exit
      end
    end
  end

  def run
    unless File.exists?(@crystal_bin)
      puts "ERROR: Crystal binary not found: #{@crystal_bin}"
      exit 1
    end

    puts "Benchmark Variant Tests"
    puts "================================"
    puts "Binary: #{@crystal_bin}"
    puts "================================"
    puts

    # Test all 28 variants exist
    test_all_28_variants

    # Test single variant selection
    test_single_variant_selection

    # Test multiple variant selection
    test_multiple_variant_selection

    # Test variant properties
    test_variant_properties

    # Test aligned vs unaligned
    test_aligned_vs_unaligned

    # Test seeded variants
    test_seeded_variants

    # Test secret variants
    test_secret_variants

    # Test streaming variants
    test_streaming_variants

    # Test auto-tuning with no iterations
    test_auto_tuning

    # Test specific iteration count
    test_specific_iterations

    puts
    puts "Results: #{@passed} passed, #{@failed} failed, #{@skipped} skipped"
    exit @failed > 0 ? 1 : 0
  end

  private def test_all_28_variants
    result = run_command(@crystal_bin, ["-q", "-b", "-i1"])

    variant_count = result.lines.count { |line| line.includes?("#") }
    expected_count = 28

    if variant_count == expected_count
      status = "✓ PASS"
      @passed += 1
    else
      status = "✗ FAIL"
      @failed += 1
    end

    puts "[#{status}] all 28 variants (expected #{expected_count}, got #{variant_count})"
  end

  private def test_single_variant_selection
    # Test -b1 runs only variant 1
    result = run_command(@crystal_bin, ["-q", "-b1", "-i1"])

    if result.includes?("1#XXH32") && !result.includes?("2#") && !result.includes?("3#")
      status = "✓ PASS"
      @passed += 1
    else
      status = "✗ FAIL"
      @failed += 1
    end

    puts "[#{status}] single variant selection (-b1)"
  end

  private def test_multiple_variant_selection
    # Test -b1,5,11 runs only those variants
    result = run_command(@crystal_bin, ["-q", "-b1,5,11", "-i1"])

    has_1 = result.includes?("1#XXH32")
    has_5 = result.includes?("5#XXH3_64b")
    has_11 = result.includes?("11#XXH128")
    has_2 = result.includes?("2#")
    has_3 = result.includes?("3#")

    if has_1 && has_5 && has_11 && !has_2 && !has_3
      status = "✓ PASS"
      @passed += 1
    else
      status = "✗ FAIL"
      @failed += 1
    end

    puts "[#{status}] multiple variant selection (-b1,5,11)"
  end

  private def test_variant_properties
    result = run_command(@crystal_bin, ["-q", "-b1,2,3,4", "-i1"])

    # Check that output includes the expected format with #, sample size, it/s, MB/s
    lines = result.lines.select { |l| l.includes?("#") }

    if lines.all? { |l| l.includes?("it/s") && l.includes?("MB/s") }
      status = "✓ PASS"
      @passed += 1
    else
      status = "✗ FAIL"
      @failed += 1
    end

    puts "[#{status}] variant output properties (format check)"
  end

  private def test_aligned_vs_unaligned
    # ID 1 is aligned XXH32, ID 2 is unaligned XXH32
    result_aligned = run_command(@crystal_bin, ["-q", "-b1", "-i1"])
    result_unaligned = run_command(@crystal_bin, ["-q", "-b2", "-i1"])

    has_aligned = result_aligned.includes?("1#XXH32")
    has_unaligned = result_unaligned.includes?("2#XXH32 unaligned")

    if has_aligned && has_unaligned
      status = "✓ PASS"
      @passed += 1
    else
      status = "✗ FAIL"
      @failed += 1
    end

    puts "[#{status}] aligned/unaligned variants (1 vs 2)"
  end

  private def test_seeded_variants
    # ID 7 is XXH3_64b w/seed, ID 8 is unaligned version
    result = run_command(@crystal_bin, ["-q", "-b7,8", "-i1"])

    has_7 = result.includes?("7#XXH3_64b w/seed")
    has_8 = result.includes?("8#XXH3_64b w/seed unaligned")

    if has_7 && has_8
      status = "✓ PASS"
      @passed += 1
    else
      status = "✗ FAIL"
      @failed += 1
    end

    puts "[#{status}] seeded variants (7-8)"
  end

  private def test_secret_variants
    # ID 9 is XXH3_64b w/secret, ID 10 is unaligned version
    result = run_command(@crystal_bin, ["-q", "-b9,10", "-i1"])

    has_9 = result.includes?("9#XXH3_64b w/secret")
    has_10 = result.includes?("10#XXH3_64b w/secret unaligned")

    if has_9 && has_10
      status = "✓ PASS"
      @passed += 1
    else
      status = "✗ FAIL"
      @failed += 1
    end

    puts "[#{status}] secret variants (9-10)"
  end

  private def test_streaming_variants
    # ID 17-28 are streaming variants
    result = run_command(@crystal_bin, ["-q", "-b17,19,21,25", "-i1"])

    has_17 = result.includes?("17#XXH32_stream")
    has_19 = result.includes?("19#XXH64_stream")
    has_21 = result.includes?("21#XXH3_stream")
    has_25 = result.includes?("25#XXH128_stream")

    if has_17 && has_19 && has_21 && has_25
      status = "✓ PASS"
      @passed += 1
    else
      status = "✗ FAIL"
      @failed += 1
    end

    puts "[#{status}] streaming variants (17,19,21,25)"
  end

  private def test_auto_tuning
    # Run without -i flag to test auto-tuning
    result = run_command(@crystal_bin, ["-q", "-b1"], timeout_secs: 5)

    if result.includes?("it/s") && !result.includes?("Error")
      status = "✓ PASS"
      @passed += 1
    else
      status = "✗ FAIL"
      @failed += 1
    end

    puts "[#{status}] auto-tuning iterations (no -i flag)"
  end

  private def test_specific_iterations
    # Run with specific iteration count
    result = run_command(@crystal_bin, ["-q", "-b1,3,5", "-i5"])

    # Each variant should show results
    if result.includes?("1#") && result.includes?("3#") && result.includes?("5#")
      status = "✓ PASS"
      @passed += 1
    else
      status = "✗ FAIL"
      @failed += 1
    end

    puts "[#{status}] specific iteration count (-i5)"
  end

  private def run_command(bin : String, args : Array(String), timeout_secs : Int32 = 3) : String
    result = IO::Memory.new
    Process.run(bin, args, output: result, error: result)
    result.to_s
  rescue ex
    "ERROR: #{ex.message}"
  end
end

tester = BenchmarkVariantTester.new
tester.run
