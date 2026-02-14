#!/usr/bin/env crystal
# Alias integration tests: ensure alias binaries (xxh32sum, xxh64sum, xxh128sum, xxh3sum)
# produce the same output as the vendor reference with the corresponding -H flag.

require "file"

class AliasIntegrationTester
  property crystal_bin_dir = "./bin"
  property vendor_bin = "vendor/xxHash/xxhsum"
  property test_files = [] of String
  property passed = 0
  property failed = 0

  def initialize
    # Default test files
    @test_files = ["README.md", "LICENSE", "shard.yml"].select { |file| File.exists?(file) }
  end

  def run
    if @test_files.empty?
      puts "ERROR: No test files found. Provide files or add README.md/LICENSE."
      exit 1
    end

    aliases = {"xxh32sum" => 0, "xxh64sum" => 1, "xxh128sum" => 2, "xxh3sum" => 3}

    puts "Alias Integration Tests"
    puts "================================"
    puts "Vendor: #{@vendor_bin}"
    puts "Files: #{@test_files.join(", ")}"
    puts "================================"

    @test_files.each do |file|
      aliases.each do |alias_name, algo|
        alias_path = File.join(@crystal_bin_dir, alias_name)
        expanded = File.expand_path(alias_path)

        if !File.exists?(expanded)
          puts "[⊘ SKIP] #{alias_name} not found (#{alias_path})"
          next
        end

        crystal_out = run_command(alias_path, [file]).strip
        vendor_out = run_command(@vendor_bin, ["-H#{algo}", file]).strip

        if crystal_out == vendor_out
          puts "[✓ PASS] #{alias_name} #{File.basename(file)} (algo #{algo})"
          @passed += 1
        else
          puts "[✗ FAIL] #{alias_name} #{File.basename(file)} (algo #{algo})"
          puts "  crystal: #{crystal_out}"
          puts "  vendor : #{vendor_out}"
          @failed += 1
        end
      end
    end

    puts
    puts "Results: #{@passed} passed, #{@failed} failed"
    exit @failed > 0 ? 1 : 0
  end

  private def run_command(bin : String, args : Array(String)) : String
    tmp = "/tmp/xxhash_alias_test_#{Process.pid}_#{Random.rand(1_000_000)}.out"
    File.open(tmp, "w") do |out_io|
      Process.run(bin, args, output: out_io)
    end
    begin
      File.read(tmp)
    ensure
      File.delete(tmp) if File.exists?(tmp)
    end
  rescue ex
    "ERROR: #{ex.message}"
  end
end

tester = AliasIntegrationTester.new
tester.run
