require "json"
require "../spec_helper"

struct CLICorpusMutation
  include JSON::Serializable

  getter file : String
  getter content : String
end

struct CLICorpusCase
  include JSON::Serializable

  getter name : String
  getter args : Array(String)
  getter stdin_fixture : String?
  getter stdin_tty : Bool = false
  getter mutations : Array(CLICorpusMutation) = [] of CLICorpusMutation
  getter expected_exit : Int32
  getter stdout_snapshot : String
  getter stderr_snapshot : String
end

record CLICorpusResult, exit_code : Int32, stdout : String, stderr : String

module CLICorpusHelper
  FIXTURES_DIR       = File.expand_path("../fixtures", __DIR__)
  EXPECTED_SNAPSHOTS = File.expand_path("../snapshots/expected", __DIR__)
  CORPUS_PATH        = File.expand_path("../corpus/cli_cases.json", __DIR__)

  def self.load_cases : Array(CLICorpusCase)
    Array(CLICorpusCase).from_json(File.read(CORPUS_PATH))
  end

  # Restore all tracked fixtures to their original state
  def self.restore_all_fixtures
    # Copy canonical originals from committed `originals/` directory
    originals_dir = File.join(FIXTURES_DIR, "originals")

    fixtures = [
      "alpha.txt",
      "beta.txt",
      "gamma.txt",
      "mutable.txt",
      "checksums_gnu.txt",
      "checksums_h3_stdin.txt",
      "checksums_bad.txt",
      "checksums_missing.txt",
      "checksums_mixed_missing.txt",
      "mutable_checksum.txt",
      "stdin_payload.txt",
      "filelist.txt",
      "filelist_missing.txt",
      "filelist_stdin.txt",
    ]

    fixtures.each do |filename|
      source = File.join(originals_dir, filename)
      target = File.join(FIXTURES_DIR, filename)
      File.copy(source, target) if File.exists?(source)
    end
  end

  def self.run_case(kase : CLICorpusCase) : CLICorpusResult
    # Restore all fixtures before running this case (before reading stdin_fixture!)
    restore_all_fixtures

    stdin_io = if (fixture = kase.stdin_fixture)
                 IO::Memory.new(File.read(File.join(FIXTURES_DIR, fixture)))
               else
                 IO::Memory.new
               end

    stdout_io = IO::Memory.new
    stderr_io = IO::Memory.new

    exit_code = 0
    Dir.cd(FIXTURES_DIR) do
      # Apply mutations before running CLI
      kase.mutations.each do |mutation|
        File.write(mutation.file, mutation.content)
      end

      exit_code = XXHSum::CLI.run(
        kase.args,
        stdin: stdin_io,
        stdout: stdout_io,
        stderr: stderr_io,
        stdin_tty: kase.stdin_tty
      )
    end

    CLICorpusResult.new(exit_code, stdout_io.to_s, stderr_io.to_s)
  end

  def self.normalize_eol(s : String) : String
    # Normalize CRLF and lone CR to LF for cross-OS snapshot comparisons
    had_trailing_newline = s.ends_with?("\n") || s.ends_with?("\r")
    normalized = s.gsub("\r\n", "\n").gsub("\r", "\n")

    # Trim trailing spaces/tabs at the end of each line (helpful for mixed-OS editors)
    lines = normalized.split("\n").map { |ln| ln.rstrip }
    result = lines.join("\n")

    # Preserve original trailing-newline state
    result += "\n" if had_trailing_newline && !result.ends_with?("\n")
    result
  end

  def self.assert_snapshot(snapshot_name : String, actual : String)
    snapshot_path = File.join(EXPECTED_SNAPSHOTS, snapshot_name)

    if ENV["UPDATE_SNAPSHOTS"]? == "1"
      # Read old snapshot for diff (if it exists)
      old_content = File.exists?(snapshot_path) ? File.read(snapshot_path) : ""

      # Show diff before updating
      if old_content != actual
        puts "\n  📝 Snapshot updated: #{snapshot_name}"
        show_diff(old_content, actual, snapshot_name)
      end

      # Write updated snapshot to expected/ directory
      File.write(snapshot_path, actual)
      return
    end

    unless File.exists?(snapshot_path)
      raise "Missing snapshot: #{snapshot_name}. Re-run with UPDATE_SNAPSHOTS=1 to auto-review and create"
    end

    expected = File.read(snapshot_path)

    # Optional normalization toggle for CRLF/line-ending differences on mixed-OS CI
    if ENV["NORMALIZE_EOL"]? == "1"
      expected = normalize_eol(expected)
      actual = normalize_eol(actual)
    end

    # Normalize SIMD backends in help message which varies by processor architecture
    if snapshot_name.includes?("help")
      # Mask the list of backends after "Available: "
      simd_mask = /Available: .+/
      expected = expected.gsub(simd_mask, "Available: [SIMD_BACKENDS]")
      actual = actual.gsub(simd_mask, "Available: [SIMD_BACKENDS]")
    end

    actual.should eq(expected)
  end

  private def self.show_diff(expected : String, actual : String, snapshot_name : String)
    # Simple unified diff-style output
    exp_lines = expected.lines
    act_lines = actual.lines
    max_lines = {exp_lines.size, act_lines.size}.max

    diff_lines = [] of String
    diff_lines << "  --- expected"
    diff_lines << "  +++ actual"

    (0...max_lines).each do |i|
      exp = exp_lines[i]?
      act = act_lines[i]?

      if exp.nil? && act.nil?
        break
      elsif exp.nil?
        diff_lines << "  + #{act.inspect}"
      elsif act.nil?
        diff_lines << "  - #{exp.inspect}"
      elsif exp != act
        diff_lines << "  - #{exp.inspect}"
        diff_lines << "  + #{act.inspect}"
      end
    end

    # Limit diff output to first 20 differences
    if diff_lines.size > 20
      diff_lines = diff_lines[0..19] + ["  ... (diff truncated)"]
    end

    puts diff_lines.join("\n") unless diff_lines.empty?
  end
end
