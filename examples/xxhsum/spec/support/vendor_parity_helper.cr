require "json"
require "../spec_helper"

# Vendor parity validation: Run corpus cases against both vendor xxhsum and cr-xxhash
# Compare exit codes, stdout, stderr to verify behavioral compatibility

module VendorParityHelper
  FIXTURES_DIR   = File.expand_path("../fixtures", __DIR__)
  CORPUS_PATH    = File.expand_path("../corpus/cli_cases.json", __DIR__)
  VENDOR_XXHSUM  = File.expand_path("../../../../vendor/xxHash/xxhsum", __DIR__)
  CRYSTAL_XXHSUM = File.expand_path("../../bin/xxhsum", __DIR__)

  record ParityResult,
    case_name : String,
    exit_code_match : Bool,
    exit_code_expected : Int32,
    exit_code_actual : Int32,
    stdout_match : Bool,
    stdout_expected : String,
    stdout_actual : String,
    stderr_match : Bool,
    stderr_expected : String,
    stderr_actual : String

  def self.load_cases : Array(CLICorpusCase)
    Array(CLICorpusCase).from_json(File.read(CORPUS_PATH))
  end

  # Run single case against vendor xxhsum via shell subprocess
  def self.run_vendor_case(kase : CLICorpusCase) : {exit_code: Int32, stdout: String, stderr: String}
    # Restore fixtures before running
    CLICorpusHelper.restore_all_fixtures

    Dir.cd(FIXTURES_DIR) do
      # Apply mutations before running
      kase.mutations.each do |mutation|
        File.write(mutation.file, mutation.content)
      end

      # Build stdin content if needed
      stdin_content = if (fixture = kase.stdin_fixture)
                        File.read(File.join(FIXTURES_DIR, fixture))
                      else
                        nil
                      end

      exit_code = 0
      stdout_str = ""
      stderr_str = ""

      begin
        args = kase.args

        if stdin_content
          # With stdin: use temp file and pipe
          temp_stdin = File.tempname("xxhsum_stdin")
          File.write(temp_stdin, stdin_content)

          # Build command and run
          cmd = "cat #{temp_stdin.inspect} | #{VENDOR_XXHSUM} #{args.map(&.inspect).join(" ")} 2>/tmp/vendor_err.txt"
          stdout_str = `#{cmd}`.chomp
          exit_code = $?.exit_code
          stderr_str = File.exists?("/tmp/vendor_err.txt") ? File.read("/tmp/vendor_err.txt").chomp : ""

          File.delete(temp_stdin) if File.exists?(temp_stdin)
          File.delete("/tmp/vendor_err.txt") if File.exists?("/tmp/vendor_err.txt")
        else
          # No stdin - direct file hashing
          cmd = "#{VENDOR_XXHSUM} #{args.map(&.inspect).join(" ")} 2>/tmp/vendor_err.txt"
          stdout_str = `#{cmd}`.chomp
          exit_code = $?.exit_code
          stderr_str = File.exists?("/tmp/vendor_err.txt") ? File.read("/tmp/vendor_err.txt").chomp : ""

          File.delete("/tmp/vendor_err.txt") if File.exists?("/tmp/vendor_err.txt")
        end
      rescue ex
        stderr_str = "Error running vendor xxhsum: #{ex.message}"
        exit_code = 127
      end

      {
        exit_code: exit_code,
        stdout:    stdout_str.empty? ? "" : stdout_str + "\n",
        stderr:    stderr_str.empty? ? "" : stderr_str + "\n",
      }
    end
  end

  # Run single case against cr-xxhash CLI
  def self.run_crystal_case(kase : CLICorpusCase) : {exit_code: Int32, stdout: String, stderr: String}
    stdin_io = if (fixture = kase.stdin_fixture)
                 IO::Memory.new(File.read(File.join(FIXTURES_DIR, fixture)))
               else
                 IO::Memory.new
               end

    stdout_io = IO::Memory.new
    stderr_io = IO::Memory.new

    exit_code = 0
    Dir.cd(FIXTURES_DIR) do
      # Restore and apply mutations
      CLICorpusHelper.restore_all_fixtures
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

    {
      exit_code: exit_code,
      stdout:    stdout_io.to_s,
      stderr:    stderr_io.to_s,
    }
  end

  # Compare vendor vs. crystal outputs with normalization
  def self.compare_outputs(
    vendor_out : {exit_code: Int32, stdout: String, stderr: String},
    crystal_out : {exit_code: Int32, stdout: String, stderr: String},
    case_name : String,
  ) : ParityResult
    # Normalize outputs for comparison (CRLF → LF, trim trailing space)
    vendor_stdout = normalize_output(vendor_out[:stdout])
    vendor_stderr = normalize_output(vendor_out[:stderr])
    crystal_stdout = normalize_output(crystal_out[:stdout])
    crystal_stderr = normalize_output(crystal_out[:stderr])

    ParityResult.new(
      case_name: case_name,
      exit_code_match: vendor_out[:exit_code] == crystal_out[:exit_code],
      exit_code_expected: vendor_out[:exit_code],
      exit_code_actual: crystal_out[:exit_code],
      stdout_match: vendor_stdout == crystal_stdout,
      stdout_expected: vendor_stdout,
      stdout_actual: crystal_stdout,
      stderr_match: vendor_stderr == crystal_stderr,
      stderr_expected: vendor_stderr,
      stderr_actual: crystal_stderr
    )
  end

  private def self.normalize_output(s : String) : String
    # Remove trailing newlines and spaces for comparison
    had_final_newline = s.ends_with?("\n")

    # CRLF → LF normalization
    normalized = s.gsub("\r\n", "\n").gsub("\r", "\n")

    # Trim trailing spaces per line
    lines = normalized.split("\n").map { |ln| ln.rstrip }
    result = lines.join("\n")

    # Restore final newline state if it existed
    result += "\n" if had_final_newline && !result.ends_with?("\n")
    result
  end

  # Generate parity report showing mismatches
  def self.generate_report(results : Array(ParityResult)) : String
    report = String.build do |io|
      io << "Vendor Parity Report\n"
      io << "====================\n\n"

      total = results.size
      passed = results.count { |r| r.exit_code_match && r.stdout_match && r.stderr_match }
      failed = total - passed

      io << "Summary: #{passed}/#{total} cases match vendor xxhsum\n"
      io << "Pass rate: #{(100 * passed / total)}%\n\n"

      if failed > 0
        io << "Mismatches:\n"
        io << "-----------\n\n"

        results.each do |result|
          if !result.exit_code_match || !result.stdout_match || !result.stderr_match
            io << "❌ #{result.case_name}\n"

            unless result.exit_code_match
              io << "  Exit code: vendor=#{result.exit_code_expected}, crystal=#{result.exit_code_actual}\n"
            end

            unless result.stdout_match
              io << "  Stdout mismatch:\n"
              io << "    Expected: #{result.stdout_expected.inspect}\n"
              io << "    Actual:   #{result.stdout_actual.inspect}\n"
            end

            unless result.stderr_match
              io << "  Stderr mismatch:\n"
              io << "    Expected: #{result.stderr_expected.inspect}\n"
              io << "    Actual:   #{result.stderr_actual.inspect}\n"
            end
            io << "\n"
          end
        end
      else
        io << "✅ All cases match vendor xxhsum perfectly!\n"
      end

      io << "\n"
    end

    report
  end
end
