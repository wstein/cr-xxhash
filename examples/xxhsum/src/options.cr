require "option_parser"

module XXHSum
  module CLI
    enum Algorithm
      XXH32
      XXH64
      XXH128
      XXH3_64
    end

    struct Options
      property algorithm : Algorithm = Algorithm::XXH64
      property bsd : Bool = false
      property quiet : Bool = false
      property little_endian : Bool = false
      property status_only : Bool = false
      property seed : UInt64? = nil
      property files : Array(String) = [] of String
      property check_mode : Bool = false
      property filelist_mode : Bool = false
      property warn : Bool = false
      property ignore_missing : Bool = false
      property strict : Bool = false
      property benchmark : Bool = false
      property benchmark_all : Bool = false
      property benchmark_ids : Array(Int32) = [] of Int32
      property benchmark_iterations : Int32 = 3
      property benchmark_size : UInt64 = 100_u64 * 1024_u64
      property simd_mode : String? = nil

      def self.program_name : String
        PROGRAM_NAME
      end

      def self.default_algorithm : Algorithm
        case File.basename(program_name)
        when "xxh32sum"  then Algorithm::XXH32
        when "xxh128sum" then Algorithm::XXH128
        when "xxh3sum"   then Algorithm::XXH3_64
        else                  Algorithm::XXH64
        end
      end

      def self.simd_backends : Array(String)
        {% if flag?(:x86_64) %}
          ["scalar", "sse2", "avx2", "avx512"]
        {% elsif flag?(:aarch64) %}
          ["scalar", "neon", "sve"]
        {% else %}
          ["scalar"]
        {% end %}
      end

      def initialize
        @algorithm = Options.default_algorithm
      end

      def self.help_text : String
        opts = Options.new
        parser = OptionParser.new(gnu_optional_args: true)
        configure_parser(parser, pointerof(opts))
        parser.to_s
      end

      def self.parse(argv : Array(String)) : Options
        opts = Options.new
        args = argv.dup

        # Normalize ambiguous GNU-style optional args so that "-b -i1" behaves like
        # vendor xxhsum (i.e. `-b` and then `-i1`), rather than treating "-i1" as
        # the optional argument for `-b`.
        i = 0
        while i < args.size - 1
          if args[i] == "-b" && args[i + 1].starts_with?("-")
            # Insert empty value so OptionParser treats -b as provided without a VARIANTS arg
            args.insert(i + 1, "")
            i += 2
          else
            i += 1
          end
        end

        OptionParser.parse(args, gnu_optional_args: true) do |parser|
          configure_parser(parser, pointerof(opts))
        end

        opts.files = args

        opts
      end

      private def self.configure_parser(parser : OptionParser, opts_ptr : Pointer(Options)) : Nil
        parser.banner = "xxhsum 0.8.3 (Using Crystal bindings)\n" \
                        "Create or verify checksums using fast non-cryptographic algorithm xxHash\n" \
                        "\nUsage: xxhsum [options] [FILES...]\n" \
                        "\nWhen no filename provided or when '-' is provided, uses stdin as input.\n" \
                        "\nOptions:"

        # Basic options
        default_algo = Options.default_algorithm.to_i
        parser.on("-H [ALGORITHM]", "select an xxhash algorithm (default: #{default_algo})\n" \
                                    "  0: XXH32\n" \
                                    "  1: XXH64\n" \
                                    "  2: XXH128 (also called XXH3_128bits)\n" \
                                    "  3: XXH3 (also called XXH3_64bits)") do |value|
          case value.to_i
          when 0 then opts_ptr.value.algorithm = Algorithm::XXH32
          when 1 then opts_ptr.value.algorithm = Algorithm::XXH64
          when 2 then opts_ptr.value.algorithm = Algorithm::XXH128
          when 3 then opts_ptr.value.algorithm = Algorithm::XXH3_64
          else
            STDERR.puts "Error: invalid algorithm '#{value}' (expected 0-3)"
            exit 1
          end
        end

        parser.on("-c", "--check", "read xxHash checksum from [FILES] and check them") { opts_ptr.value.check_mode = true }
        parser.on("--filelist", "generate hashes for files listed in [FILE]") { opts_ptr.value.filelist_mode = true }
        parser.on("-h", "--help", "display this help message") do
          puts parser
          exit 0
        end

        parser.separator
        parser.separator "Advanced:"

        # Advanced options
        parser.on("-V", "--version", "Display version information") do
          puts "xxhsum Crystal (example) #{XXH::VERSION}"
          exit 0
        end

        parser.on("--tag", "Produce BSD-style checksum lines") { opts_ptr.value.bsd = true }
        parser.on("--little-endian", "Checksum values use little endian convention (default: big endian)") { opts_ptr.value.little_endian = true }
        parser.on("--binary", "Read in binary mode (compat: no-op — files are binary by default)") do
          # Compatibility no-op: inputs are treated as binary by default.
        end
        # Separate -b (default benchmark) and -b [VARIANTS] (custom selection)
        parser.on("-b", "Run benchmark with default variant set (equivalent to -b1,3,5,11)") do
          opts_ptr.value.benchmark = true
        end
        parser.on("-b [VARIANTS]", "Run specified benchmark variant(s)\nVARIANTS may be comma-separated IDs (e.g. \"1,3,5\") or ranges (e.g. \"1-5\")") do |value|
          if value.empty?
            opts_ptr.value.benchmark = true
          else
            # Support vendor-compatible compact forms such as `-bi1` (iterations)
            # Treat leading alphabetic tokens (e.g. "i1") as separate short options
            if value =~ /^i(\d+)$/
              opts_ptr.value.benchmark = true
              opts_ptr.value.benchmark_iterations = value[1..-1].to_i
            elsif value.starts_with?("-") || value =~ /^\D/ && !(value =~ /^\d/)
              # Defensive: when OptionParser hands us a non-numeric token, treat as no-arg
              opts_ptr.value.benchmark = true
            else
              apply_benchmark_selector!(opts_ptr, value)
            end
          end
        end

        # Alias: --bench-all maps to -b0
        parser.on("--bench-all", "Run all 28 benchmark variants (equivalent to -b0)") do
          opts_ptr.value.benchmark = true
          opts_ptr.value.benchmark_all = true
          opts_ptr.value.benchmark_ids.clear
        end

        parser.on("-i [ITERATIONS]", "Number of times to run the benchmark (default: 3)") do |value|
          iterations = value.to_i
          if iterations < 1
            STDERR.puts "Error: benchmark iterations must be >= 1"
            exit 1
          end
          opts_ptr.value.benchmark_iterations = iterations
        end
        parser.on("-B [SIZE]", "Benchmark sample size (supports K,KB,M,MB,G,GB — 1024-based)") do |value|
          size = parse_size(value)
          if size == 0
            STDERR.puts "Error: benchmark sample size must be > 0"
            exit 1
          end
          opts_ptr.value.benchmark_size = size
        end
        parser.on("-s SEED", "--seed SEED", "Seed (decimal or 0xHEX)") do |value|
          seed_val = if value.starts_with?("0x") || value.starts_with?("0X")
                       value[2..-1].to_i(16)
                     else
                       value.to_i
                     end
          opts_ptr.value.seed = seed_val.to_u64
        end
        parser.on("--simd [BACKEND]", "Select SIMD backend for XXH3/XXH128 one-shot hashing (available: " + Options.simd_backends.join(", ") + ")") do |value|
          unless value.nil? || Options.simd_backends.includes?(value)
            STDERR.puts "Error: invalid SIMD backend '#{value}' (available: #{Options.simd_backends.join(", ")})"
            exit 1
          end
          opts_ptr.value.simd_mode = value
        end
        parser.on("-q", "--quiet", "Don't display version header in benchmark mode\nDon't print OK for each successfully verified hash") { opts_ptr.value.quiet = true }

        parser.separator
        parser.separator "The following five options are useful only when using lists in [files] to verify or generate checksums:"

        # File list options
        parser.on("--status", "Don't output anything, status code shows success") { opts_ptr.value.status_only = true }
        parser.on("--strict", "Exit non-zero for improperly formatted lines in [FILES]") { opts_ptr.value.strict = true }
        parser.on("--warn", "Warn about improperly formatted lines in [FILES]") { opts_ptr.value.warn = true }
        parser.on("--ignore-missing", "Don't fail or report status for missing files") { opts_ptr.value.ignore_missing = true }

        parser.invalid_option do |flag|
          STDERR.puts "Error: #{flag} is not a valid option or is not yet implemented"
          STDERR.puts parser
          exit 1
        end
      end

      private def self.apply_benchmark_selector!(opts_ptr : Pointer(Options), spec : String) : Nil
        # Accept comma-separated ids and ranges (e.g. "1,3,5" or "1-5")
        unless spec.split(",").all? { |t| t =~ /^\d+(-\d+)?$/ }
          STDERR.puts "Error: invalid benchmark selector '-b#{spec}'"
          exit 1
        end

        opts_ptr.value.benchmark = true
        spec.split(",").each do |token|
          next if token.empty?

          if token.includes?("-")
            start_s, end_s = token.split("-", 2)
            start_id = start_s.to_i
            end_id = end_s.to_i
            if start_id <= 0 || end_id < start_id
              STDERR.puts "Error: invalid benchmark range '#{token}'"
              exit 1
            end

            # If range includes 0 or an id >= 29 => treat as 'all'
            if start_id == 0 || end_id >= 29
              opts_ptr.value.benchmark_all = true
              opts_ptr.value.benchmark_ids.clear
              break
            end

            (start_id..end_id).each do |id|
              opts_ptr.value.benchmark_ids << id unless opts_ptr.value.benchmark_ids.includes?(id)
            end
          else
            id = token.to_i
            if id == 0 || id >= 29
              opts_ptr.value.benchmark_all = true
              opts_ptr.value.benchmark_ids.clear
              break
            elsif id >= 1
              opts_ptr.value.benchmark_ids << id unless opts_ptr.value.benchmark_ids.includes?(id)
            else
              STDERR.puts "Error: invalid benchmark id '#{id}'"
              exit 1
            end
          end
        end
      end

      private def self.parse_size(str : String) : UInt64
        s = str.strip
        return 0_u64 if s.empty?

        multiplier = 1_u64

        # All suffixes use 1024-based binary units (K/KB/M/MB/G/GB only)
        if s.ends_with?("GB") || s.ends_with?("gb")
          multiplier = 1024_u64 * 1024_u64 * 1024_u64
          s = s[0..-3]
        elsif s.ends_with?("MB") || s.ends_with?("mb")
          multiplier = 1024_u64 * 1024_u64
          s = s[0..-3]
        elsif s.ends_with?("KB") || s.ends_with?("kb")
          multiplier = 1024_u64
          s = s[0..-3]
        elsif s.ends_with?("G") || s.ends_with?("g")
          multiplier = 1024_u64 * 1024_u64 * 1024_u64
          s = s[0..-2]
        elsif s.ends_with?("M") || s.ends_with?("m")
          multiplier = 1024_u64 * 1024_u64
          s = s[0..-2]
        elsif s.ends_with?("K") || s.ends_with?("k")
          multiplier = 1024_u64
          s = s[0..-2]
        end

        value = s.to_u64?
        return 0_u64 unless value
        value * multiplier
      end
    end
  end
end
