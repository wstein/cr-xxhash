require "../../../src/xxh"
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

      # Handle filelist mode
      if options.filelist_mode
        # If no file given, read filenames from stdin
        if options.files.empty?
          return filelist_from_stdin(options, stdin: stdin, stdout: stdout, stderr: stderr)
        end
        return filelist_from_file(options.files[0], options, stdout: stdout, stderr: stderr)
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
        hex = Hasher.hash_stdin(options.algorithm, options.seed, options.simd_mode, input: stdin)
        output = options.bsd ? Formatter.format_bsd(Formatter.algo_name(options.algorithm), hex, "stdin", options.little_endian) : Formatter.format_gnu(hex, "stdin", options.algorithm, options.little_endian)
        stdout.puts output
        return 0
      end

      options.files.each do |f|
        if f == "-"
          hex = Hasher.hash_stdin(options.algorithm, options.seed, options.simd_mode, input: stdin)
          stdout.puts options.bsd ? Formatter.format_bsd(Formatter.algo_name(options.algorithm), hex, "stdin", options.little_endian) : Formatter.format_gnu(hex, "stdin", options.algorithm, options.little_endian)
          next
        end

        begin
          hex = Hasher.hash_path(f, options.algorithm, options.seed, options.simd_mode)
          stdout.puts options.bsd ? Formatter.format_bsd(Formatter.algo_name(options.algorithm), hex, f, options.little_endian) : Formatter.format_gnu(hex, f, options.algorithm, options.little_endian)
        rescue ex : Exception
          stderr.puts "xxhsum: #{f}: #{ex.message}"
          return 1
        end
      end

      0
    end

    # Hash files listed in a filelist file
    def self.filelist_from_file(filelist_path : String, options : Options, stdout : IO, stderr : IO) : Int32
      exit_code = 0
      begin
        File.each_line(filelist_path) do |line|
          line = line.chomp
          next if line.empty?

          if line == "-"
            # Read from stdin is not typical for filelist, but handle it anyway
            hex = Hasher.hash_stdin(options.algorithm, options.seed, options.simd_mode)
            output = options.bsd ? Formatter.format_bsd(Formatter.algo_name(options.algorithm), hex, "stdin", options.little_endian) : Formatter.format_gnu(hex, "stdin", options.algorithm, options.little_endian)
            stdout.puts output
            next
          end

          begin
            unless File.exists?(line)
              stderr.puts "xxhsum: #{line}: No such file or directory"
              exit_code = 1
              next
            end

            hex = Hasher.hash_path(line, options.algorithm, options.seed, options.simd_mode)
            output = options.bsd ? Formatter.format_bsd(Formatter.algo_name(options.algorithm), hex, line, options.little_endian) : Formatter.format_gnu(hex, line, options.algorithm, options.little_endian)
            stdout.puts output
          rescue ex : Exception
            stderr.puts "xxhsum: #{line}: #{ex.message}"
            exit_code = 1
          end
        end
      rescue ex : Exception
        stderr.puts "xxhsum: #{filelist_path}: #{ex.message}"
        return 1
      end
      exit_code
    end

    # Hash files listed from stdin (filelist mode)
    def self.filelist_from_stdin(options : Options, stdin : IO, stdout : IO, stderr : IO) : Int32
      exit_code = 0
      stdin.each_line do |line|
        line = line.chomp
        next if line.empty?

        if line == "-"
          # Nested stdin read; skip to avoid confusion
          next
        end

        begin
          unless File.exists?(line)
            stderr.puts "xxhsum: #{line}: No such file or directory"
            exit_code = 1
            next
          end

          hex = Hasher.hash_path(line, options.algorithm, options.seed, options.simd_mode)
          output = options.bsd ? Formatter.format_bsd(Formatter.algo_name(options.algorithm), hex, line, options.little_endian) : Formatter.format_gnu(hex, line, options.algorithm, options.little_endian)
          stdout.puts output
        rescue ex : Exception
          stderr.puts "xxhsum: #{line}: #{ex.message}"
          exit_code = 1
        end
      end
      exit_code
    end
  end
end
