require "cr-xxhash/src/xxh"
require "./options"
require "./hasher"
require "./formatter"
require "./checker"

module XXHSum
  module CLI
    def self.run(argv : Array(String))
      options = Options.parse(argv)

      # Handle check mode
      if options.check_mode
        # If no files given, read checksums from stdin
        if options.files.empty?
          return Checker.verify_stdin(options)
        end
        return Checker.verify(options.files, options)
      end

      # Regular hashing mode
      # If no files given -> read from stdin
      if options.files.empty?
        hex = Hasher.hash_stdin(options.algorithm, options.seed)
        output = options.bsd ? Formatter.format_bsd(Formatter.algo_name(options.algorithm), hex, "-") : Formatter.format_gnu(hex, nil, options.algorithm)
        puts output
        return 0
      end

      options.files.each do |f|
        if f == "-"
          hex = Hasher.hash_stdin(options.algorithm, options.seed)
          puts options.bsd ? Formatter.format_bsd(Formatter.algo_name(options.algorithm), hex, "-") : Formatter.format_gnu(hex, "-", options.algorithm)
          next
        end

        begin
          hex = Hasher.hash_path(f, options.algorithm, options.seed)
          puts options.bsd ? Formatter.format_bsd(Formatter.algo_name(options.algorithm), hex, f) : Formatter.format_gnu(hex, f, options.algorithm)
        rescue ex : Exception
          STDERR.puts "xxhsum: #{f}: #{ex.message}"
          return 1
        end
      end

      0
    end
  end
end

# Entry point: run CLI with command-line arguments
exit XXHSum::CLI.run(ARGV)
