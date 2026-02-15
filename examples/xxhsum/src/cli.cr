require "cr-xxhash/src/xxh"
require "./options"
require "./benchmark"
require "./hasher"
require "./formatter"
require "./checker"

module XXHSum
  module CLI
    def self.run(
      argv : Array(String),
      stdin : IO = STDIN,
      stdout : IO = STDOUT,
      stderr : IO = STDERR,
      stdin_tty : Bool = STDIN.tty?,
    ) : Int32
      options = Options.parse(argv)

      if options.benchmark
        return Benchmark.run(options, stdout)
      end

      # If the user provided no arguments and nothing is piped, show help
      if argv.empty? && stdin_tty
        stdout.puts Options.help_text
        return 1
      end

      # Handle check mode
      if options.check_mode
        # If no files given, read checksums from stdin
        if options.files.empty?
          return Checker.verify_stdin(options, stdin: stdin, out_io: stdout, err_io: stderr)
        end
        return Checker.verify(options.files, options, out_io: stdout, err_io: stderr)
      end

      # Regular hashing mode
      # If no files given -> read from stdin
      if options.files.empty?
        hex = Hasher.hash_stdin(options.algorithm, options.seed, input: stdin)
        output = options.bsd ? Formatter.format_bsd(Formatter.algo_name(options.algorithm), hex, "stdin") : Formatter.format_gnu(hex, "stdin", options.algorithm)
        stdout.puts output
        return 0
      end

      options.files.each do |f|
        if f == "-"
          hex = Hasher.hash_stdin(options.algorithm, options.seed, input: stdin)
          stdout.puts options.bsd ? Formatter.format_bsd(Formatter.algo_name(options.algorithm), hex, "stdin") : Formatter.format_gnu(hex, "stdin", options.algorithm)
          next
        end

        begin
          hex = Hasher.hash_path(f, options.algorithm, options.seed)
          stdout.puts options.bsd ? Formatter.format_bsd(Formatter.algo_name(options.algorithm), hex, f) : Formatter.format_gnu(hex, f, options.algorithm)
        rescue ex : Exception
          stderr.puts "xxhsum: #{f}: #{ex.message}"
          return 1
        end
      end

      0
    end
  end
end
