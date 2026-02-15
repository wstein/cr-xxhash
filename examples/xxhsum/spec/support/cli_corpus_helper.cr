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
  FIXTURES_DIR  = File.expand_path("../fixtures", __DIR__)
  SNAPSHOTS_DIR = File.expand_path("../snapshots", __DIR__)
  CORPUS_PATH   = File.expand_path("../corpus/cli_cases.json", __DIR__)

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
      "mutable.txt",
      "checksums_gnu.txt",
      "checksums_h3_stdin.txt",
      "checksums_bad.txt",
      "checksums_missing.txt",
      "checksums_mixed_missing.txt",
      "mutable_checksum.txt",
      "stdin_payload.txt",
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
    snapshot_path = File.join(SNAPSHOTS_DIR, snapshot_name)

    if ENV["UPDATE_SNAPSHOTS"]? == "1"
      File.write(snapshot_path, actual)
    end

    unless File.exists?(snapshot_path)
      raise "Missing snapshot: #{snapshot_name}. Re-run with UPDATE_SNAPSHOTS=1"
    end

    expected = File.read(snapshot_path)

    # Optional normalization toggle for CRLF/line-ending differences on mixed-OS CI
    if ENV["NORMALIZE_EOL"]? == "1"
      expected = normalize_eol(expected)
      actual = normalize_eol(actual)
    end

    actual.should eq(expected)
  end
end
