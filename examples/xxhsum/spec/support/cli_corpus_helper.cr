require "json"
require "../spec_helper"

struct CLICorpusCase
  include JSON::Serializable

  getter name : String
  getter args : Array(String)
  getter stdin_fixture : String?
  getter stdin_tty : Bool = false
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

  def self.run_case(kase : CLICorpusCase) : CLICorpusResult
    stdin_io = if (fixture = kase.stdin_fixture)
                 IO::Memory.new(File.read(File.join(FIXTURES_DIR, fixture)))
               else
                 IO::Memory.new
               end

    stdout_io = IO::Memory.new
    stderr_io = IO::Memory.new

    exit_code = 0
    Dir.cd(FIXTURES_DIR) do
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

  def self.assert_snapshot(snapshot_name : String, actual : String)
    snapshot_path = File.join(SNAPSHOTS_DIR, snapshot_name)

    if ENV["UPDATE_SNAPSHOTS"]? == "1"
      File.write(snapshot_path, actual)
    end

    unless File.exists?(snapshot_path)
      raise "Missing snapshot: #{snapshot_name}. Re-run with UPDATE_SNAPSHOTS=1"
    end

    expected = File.read(snapshot_path)
    actual.should eq(expected)
  end
end
