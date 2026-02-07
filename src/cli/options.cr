require "option_parser"

module XXH::CLI
  # Algorithm selection enum
  enum Algorithm
    XXH32  # 0
    XXH64  # 1 (default)
    XXH128 # 2
    XXH3   # 3
  end

  # Output format convention
  enum DisplayConvention
    GNU # Default: "XXH3  hash  filename"
    BSD # With --tag: "XXH3 (filename) = hash"
  end

  # Endianness for display
  enum DisplayEndianness
    Big    # Default: big-endian (network byte order)
    Little # With --little-endian: little-endian
  end

  # CLI options parsed from command line
  struct Options
    property algorithm : Algorithm = Algorithm::XXH64
    property mode : Mode = Mode::Hash
    property convention : DisplayConvention = DisplayConvention::GNU
    property endianness : DisplayEndianness = DisplayEndianness::Big
    property quiet : Bool = false
    property status : Bool = false
    property strict : Bool = false
    property warn : Bool = false
    property ignore_missing : Bool = false
    property tag : Bool = false # BSD style output
    property benchmark : Bool = false
    property benchmark_all : Bool = false
    property benchmark_id : Int32 = 0                        # Specific benchmark ID
    property benchmark_variants : Array(Int32) = [] of Int32 # Multiple variants from -b1,2,3
    property iterations : Int32 = 0                          # Benchmark iterations (0 = auto-calibrate)
    property sample_size : UInt64 = 100_u64 * 1024_u64       # 100 KB default sample
    property explicit_stdin : Bool = false
    property files : Array(String) = [] of String

    # Mode of operation
    enum Mode
      Hash      # Default: hash files
      Check     # -c: verify checksums
      FilesFrom # --files-from / --filelist: hash files listed in file
      Benchmark # -b: run benchmark
    end
  end

  # Command-line argument parser using Crystal's OptionParser
  class Parser
    getter options : Options = Options.new

    def initialize(@argv : Array(String))
    end

    def parse : Bool
      # Handle -bX and -bX,Y,Z benchmark options manually
      filtered_argv = @argv.select do |arg|
        if arg.starts_with?("-b") && arg.size > 2
          bench_spec = arg[2..]
          # Check if it's all digits or digits with commas
          if bench_spec.gsub(",", "").chars.all? { |c| c.ascii_number? }
            @options.mode = Options::Mode::Benchmark
            @options.benchmark = true

            # Handle comma-separated variants like -b1,2,3
            if bench_spec.includes?(',')
              # Multiple variants
              @options.benchmark_variants = bench_spec.split(',').map(&.to_i32)
              @options.benchmark_all = true
            else
              # Single variant or "all"
              bench_id = bench_spec.to_i32
              if bench_id == 0 || bench_id >= 29
                # IDs 0, and 29+ are treated as "benchmark all" (vendor behavior)
                @options.benchmark_all = true
              elsif bench_id >= 1 && bench_id <= 28
                # Store the benchmark ID (1-28)
                @options.benchmark_id = bench_id
                @options.benchmark_all = false
              else
                # Invalid ID (negative or outside expected ranges)
                error "Invalid benchmark ID: #{bench_spec}"
                return false
              end
            end
            false # Remove from argv
          else
            true # Keep in argv
          end
        else
          true # Keep in argv
        end
      end
      @argv = filtered_argv

      OptionParser.parse(@argv) do |parser|
        parser.banner = "Usage: xxhsum [options] [files]"

        parser.on("-H#", "--algorithm=N", "Select algorithm (0=XXH32, 1=XXH64, 2=XXH128, 3=XXH3)") do |n|
          case n
          when "0", "32"  then @options.algorithm = Algorithm::XXH32
          when "1", "64"  then @options.algorithm = Algorithm::XXH64
          when "2", "128" then @options.algorithm = Algorithm::XXH128
          when "3"        then @options.algorithm = Algorithm::XXH3
          else
            next false
          end
        end

        parser.on("-c", "--check", "Read xxHash checksum from [files] and check them") do
          @options.mode = Options::Mode::Check
        end

        parser.on("--files-from=FILE", "Generate hashes for files listed in FILE") do |file|
          @options.mode = Options::Mode::FilesFrom
          @options.files << file
        end

        parser.on("--filelist=FILE", "Same as --files-from") do |file|
          @options.mode = Options::Mode::FilesFrom
          @options.files << file
        end

        parser.on("--tag", "Produce BSD-style checksum lines") do
          @options.tag = true
          @options.convention = DisplayConvention::BSD
        end

        parser.on("--little-endian", "Checksum values use little endian convention (default: big endian)") do
          @options.endianness = DisplayEndianness::Little
        end

        parser.on("--strict", "Exit non-zero for improperly formatted lines") do
          @options.strict = true
        end

        parser.on("--status", "Don't output anything, status code shows success") do
          @options.status = true
        end

        parser.on("--warn", "Warn about improperly formatted lines") do
          @options.warn = true
        end

        parser.on("--ignore-missing", "Don't fail or report status for missing files") do
          @options.ignore_missing = true
        end

        parser.on("-q", "--quiet", "Don't print OK for each successfully verified hash") do
          @options.quiet = true
        end

        parser.on("-b", "--benchmark", "Run benchmark. Also supports vendor benchmark IDs: use `-b#` or `-b#,X,Y` to select vendor benchmark IDs (1-28). `-b0`, `-b29` and higher, or `-b77` expand to 'benchmark all'.") do
          @options.mode = Options::Mode::Benchmark
          @options.benchmark = true
          @options.benchmark_all = true
        end

        parser.on("--bench-all", "Benchmark all vendor benchmark IDs (alias for -b0/-b29/-b77)") do
          @options.mode = Options::Mode::Benchmark
          @options.benchmark = true
          @options.benchmark_all = true
        end

        parser.on("-i#", "--iterations=N", "Number of iterations per benchmark run (0=auto-calibrate for 1 second)") do |n|
          @options.iterations = n.to_i32
        end

        parser.on("-B#", "--block-size=N", "Benchmark block size (supports K, KB, KiB, M, MB, MiB suffixes)") do |n|
          @options.sample_size = parse_size(n)
        end

        parser.on("-V", "--version", "Display version information") do
          print_version
          exit 0
        end

        parser.on("-h", "--help", "Display this help message") do
          print_help
          exit 0
        end

        parser.on("-", "Force stdin as input") do
          @options.explicit_stdin = true
        end

        parser.unknown_args do |_args, remaining|
          remaining.each { |arg| @options.files << arg }
        end
      end
      # Add remaining positional args (files) left in @argv
      @argv.each { |arg| @options.files << arg }

      true
    rescue ex : OptionParser::Exception
      error ex.message || "Invalid arguments"
      false
    end

    private def print_help
      puts <<-HELP
        xxhsum - Command line interface for xxhash algorithms
        Usage: xxhsum [options] [files]

        When no filename provided or when '-' is provided, uses stdin as input.

        Options:
          -H#                  Select an xxhash algorithm (default: 1)
                                 0: XXH32
                                 1: XXH64 (default)
                                 2: XXH128
                                 3: XXH3
          -c, --check          Read xxHash checksum from [files] and check them
              --files-from     Generate hashes for files listed in [files]
              --filelist       Generate hashes for files listed in [files]
              --tag            Produce BSD-style checksum lines
              --little-endian  Checksum values use little endian convention
          -b                   Run benchmark
          -b#                  Bench only algorithm variant #
              --bench-all      Benchmark all algorithms
          -i#                  Number of times to run the benchmark (default: 1000)
          -q, --quiet          Don't display version header in benchmark mode
              --status         Don't output anything, status code shows success
              --strict         Exit non-zero for improperly formatted lines
              --warn           Warn about improperly formatted lines
              --ignore-missing Don't fail or report status for missing files
          -h, --help           Display this help message
          -V, --version        Display version information

        The following options are useful only when using lists in [files] to verify:
          -q, --quiet          Don't print OK for each successfully verified hash
              --status         Don't output anything, status code shows success
              --strict         Exit non-zero for improperly formatted lines
              --warn           Warn about improperly formatted lines
              --ignore-missing Don't fail or report status for missing files
      HELP
    end

    private def print_version
      version = LibXXH.versionNumber.to_i32
      major_minor, patch = version.divmod(100)
      major, minor = major_minor.divmod(100)
      puts "xxhsum #{major}.#{minor}.#{patch} by Yann Collet"
      puts "Compiled as Crystal FFI bindings"
    end

    # Parse size with K, KB, KiB, M, MB, MiB suffixes
    private def parse_size(str : String) : UInt64
      multiplier = 1_u64
      s = str

      if s.ends_with?("K") || s.ends_with?("k")
        multiplier = 1024_u64
        s = s[0..-2]
        if s.ends_with?("i")
          s = s[0..-2]
        end
      elsif s.ends_with?("M") || s.ends_with?("m")
        multiplier = 1024_u64 * 1024_u64
        s = s[0..-2]
        if s.ends_with?("i")
          s = s[0..-2]
        end
      end

      value = s.to_u64? || 0_u64
      (value * multiplier)
    end

    # Map benchmark ID to algorithm
    # Supports both C-style (1=XXH32, 2=XXH64, 3=XXH3, 4=XXH128)
    # and vendor-style (1=XXH32, 3=XXH64, 5=XXH3, 11=XXH128)
    def self.map_bench_id(id : Int32) : Algorithm?
      case id
      when  1 then Algorithm::XXH32
      when  2 then Algorithm::XXH64  # C-style XXH64
      when  3 then Algorithm::XXH64  # Vendor-style XXH64
      when  4 then Algorithm::XXH128 # C-style XXH128
      when  5 then Algorithm::XXH3   # Vendor-style XXH3
      when 11 then Algorithm::XXH128 # Vendor-style XXH128
      else
        nil
      end
    end

    # Map benchmark ID to algorithm
    # Supports both C-style (1=XXH32, 2=XXH64, 3=XXH3, 4=XXH128)
    # and vendor-style (1=XXH32, 3=XXH64, 5=XXH3, 11=XXH128)
    private def map_bench_id(id : Int32) : Algorithm?
      Parser.map_bench_id(id)
    end

    private def error(message : String)
      STDERR.puts "Error: #{message}"
    end
  end
end
