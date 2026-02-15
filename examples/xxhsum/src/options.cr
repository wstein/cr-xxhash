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
      property seed : UInt64? = nil
      property files : Array(String) = [] of String
      property check_mode : Bool = false
      property ignore_missing : Bool = false
      property strict : Bool = false
      property benchmark : Bool = false
      property benchmark_all : Bool = false
      property benchmark_ids : Array(Int32) = [] of Int32
      property benchmark_iterations : Int32 = 3
      property benchmark_size : UInt64 = 100_u64 * 1024_u64

      def self.help_text : String
        parser = OptionParser.new do |p|
          p.banner = "xxhsum 0.8.3 (Crystal implementation)\n" \
                     "Create or verify checksums using fast non-cryptographic algorithm xxHash\n" \
                     "\nUsage: xxhsum [options] [FILES...]\n" \
                     "\nWhen no filename provided or when '-' is provided, uses stdin as input.\n" \
                     "\nOptions:"

          # Basic options
          p.on("-H#", "select an xxhash algorithm (default: 1)\n" \
                      "  0: XXH32\n" \
                      "  1: XXH64\n" \
                      "  2: XXH128 (also called XXH3_128bits)\n" \
                      "  3: XXH3 (also called XXH3_64bits)") { }
          p.on("-c", "--check", "read xxHash checksum from [FILES] and check them") { }
          p.on("--filelist", "(NOT YET IMPLEMENTED) generate hashes for files listed in [FILES]") { }
          p.on("-h", "--help", "display this help message") { }

          p.separator
          p.separator "Advanced:"

          # Advanced options
          p.on("-V", "--version", "Display version information") { }
          p.on("--tag", "Produce BSD-style checksum lines") { }
          p.on("--little-endian", "(NOT YET IMPLEMENTED) Checksum values use little endian convention (default: big endian)") { }
          p.on("--binary", "(NOT YET IMPLEMENTED) Read in binary mode") { }
          p.on("-b", "Run benchmark") { }
          p.on("-b#", "Bench only algorithm variant #") { }
          p.on("-i#", "Number of times to run the benchmark (default: 3)") { }
          p.on("-B#", "Benchmark sample size (supports K,KB,M,MB,G,GB — 1024-based)") { }
          p.on("-q", "--quiet", "Don't display version header in benchmark mode") { }

          p.separator
          p.separator "File list options:"

          # File list options
          p.on("--status", "(NOT YET IMPLEMENTED) Don't output anything, status code shows success") { }
          p.on("--strict", "Exit non-zero for improperly formatted lines in [FILES]") { }
          p.on("--warn", "(NOT YET IMPLEMENTED) Warn about improperly formatted lines in [FILES]") { }
          p.on("--ignore-missing", "Don't fail or report status for missing files") { }

          p.on("-s SEED", "--seed SEED", "Seed (decimal or 0xHEX)") { }
          p.on("--bench-all", "Run all 28 benchmark variants (equivalent to -b0)") { }
        end
        parser.to_s
      end

      def self.parse(argv : Array(String)) : Options
        opts = Options.new

        filtered_argv = [] of String
        argv.each do |arg|
          if arg.starts_with?("-i") && !arg.starts_with?("--") && arg.size > 2
            spec = arg[2..]
            unless spec.chars.all?(&.ascii_number?)
              STDERR.puts "Error: invalid benchmark iterations '#{arg}'"
              exit 1
            end
            iters = spec.to_i
            if iters < 1
              STDERR.puts "Error: benchmark iterations must be >= 1"
              exit 1
            end
            opts.benchmark_iterations = iters
            next
          end

          if arg.starts_with?("-B") && !arg.starts_with?("--") && arg.size > 2
            spec = arg[2..]
            size = parse_size(spec)
            if size == 0
              STDERR.puts "Error: benchmark sample size must be > 0"
              exit 1
            end
            opts.benchmark_size = size
            next
          end

          if arg.starts_with?("-b") && arg.size > 2
            # Support vendor-style compact IDs: -b3, -b1,3,5, -b0 (all)
            spec = arg[2..]
            unless spec.gsub(",", "").chars.all?(&.ascii_number?)
              STDERR.puts "Error: invalid benchmark selector '#{arg}'"
              exit 1
            end

            opts.benchmark = true
            spec.split(",").each do |token|
              next if token.empty?
              id = token.to_i
              if id == 0 || id >= 29
                opts.benchmark_all = true
                opts.benchmark_ids.clear
                break
              elsif id >= 1
                opts.benchmark_ids << id unless opts.benchmark_ids.includes?(id)
              else
                STDERR.puts "Error: invalid benchmark id '#{id}'"
                exit 1
              end
            end
            next
          end

          filtered_argv << arg
        end

        parser = OptionParser.new do |p|
          p.banner = "xxhsum 0.8.3 (Crystal implementation)\n" \
                     "Create or verify checksums using fast non-cryptographic algorithm xxHash\n" \
                     "\nUsage: xxhsum [options] [FILES...]\n" \
                     "\nWhen no filename provided or when '-' is provided, uses stdin as input.\n" \
                     "\nOptions:"

          # Basic options
          p.on("-H#", "select an xxhash algorithm (default: 1)") do |v|
            case v.to_i
            when 0 then opts.algorithm = Algorithm::XXH32
            when 1 then opts.algorithm = Algorithm::XXH64
            when 2 then opts.algorithm = Algorithm::XXH128
            when 3 then opts.algorithm = Algorithm::XXH3_64
            else
              STDERR.puts "Error: invalid algorithm '#{v}' (expected 0-3)"
              exit 1
            end
          end

          p.on("-c", "--check", "read xxHash checksum from [FILES] and check them") { opts.check_mode = true }
          p.on("--filelist", "generate hashes for files listed in [FILES]") do
            STDERR.puts "Error: --filelist is not yet implemented"
            exit 1
          end
          p.on("-h", "--help", "display this help message") do
            puts p
            exit 0
          end

          p.separator
          p.separator "Advanced:"

          # Advanced options
          p.on("-V", "--version", "Display version information") do
            puts "xxhsum Crystal (example) #{XXH::VERSION}"
            exit 0
          end
          p.on("--tag", "Produce BSD-style checksum lines") { opts.bsd = true }
          p.on("--little-endian", "Checksum values use little endian convention (default: big endian)") do
            STDERR.puts "Error: --little-endian is not yet implemented"
            exit 1
          end
          p.on("--binary", "Read in binary mode") do
            STDERR.puts "Error: --binary is not yet implemented"
            exit 1
          end
          p.on("-b#", "Bench only algorithm variant #") do |v|
            spec = v
            unless spec.gsub(",", "").chars.all?(&.ascii_number?)
              STDERR.puts "Error: invalid benchmark selector '-b#{spec}'"
              exit 1
            end
            opts.benchmark = true
            spec.split(",").each do |token|
              next if token.empty?
              id = token.to_i
              if id == 0 || id >= 29
                opts.benchmark_all = true
                opts.benchmark_ids.clear
                break
              elsif id >= 1
                opts.benchmark_ids << id unless opts.benchmark_ids.includes?(id)
              else
                STDERR.puts "Error: invalid benchmark id '#{id}'"
                exit 1
              end
            end
          end
          p.on("-b", "Run benchmark") { opts.benchmark = true }
          p.on("-i#", "Number of times to run the benchmark (default: 3)") do |v|
            iters = v.to_i
            if iters < 1
              STDERR.puts "Error: benchmark iterations must be >= 1"
              exit 1
            end
            opts.benchmark_iterations = iters
          end
          p.on("-q", "--quiet", "Don't display version header in benchmark mode") { opts.quiet = true }

          p.separator
          p.separator "File list options:"

          # File list options
          p.on("--status", "Don't output anything, status code shows success") do
            STDERR.puts "Error: --status is not yet implemented"
            exit 1
          end
          p.on("--strict", "Exit non-zero for improperly formatted lines in [FILES]") { opts.strict = true }
          p.on("--warn", "Warn about improperly formatted lines in [FILES]") do
            STDERR.puts "Error: --warn is not yet implemented"
            exit 1
          end
          p.on("--ignore-missing", "Don't fail or report status for missing files") { opts.ignore_missing = true }

          p.separator
          p.on("-B#", "Benchmark sample size (supports K,KB,M,MB,G,GB — 1024-based; KiB/MiB/GiB accepted)") do |v|
            size = parse_size(v)
            if size == 0
              STDERR.puts "Error: benchmark sample size must be > 0"
              exit 1
            end
            opts.benchmark_size = size
          end

          p.on("-s SEED", "--seed SEED", "Seed (decimal or 0xHEX)") do |v|
            seed_val = if v.starts_with?("0x") || v.starts_with?("0X")
                         v[2..-1].to_i(16)
                       else
                         v.to_i
                       end
            opts.seed = seed_val.to_u64
          end

          # Alias: --bench-all maps to -b0
          p.on("--bench-all", "Run all 28 benchmark variants (equivalent to -b0)") do
            opts.benchmark = true
            opts.benchmark_all = true
            opts.benchmark_ids.clear
          end

          p.invalid_option do |flag|
            STDERR.puts "Error: #{flag} is not a valid option or is not yet implemented"
            STDERR.puts p
            exit 1
          end

          p.unknown_args do |args|
            opts.files = args
          end
        end

        parser.parse(filtered_argv)
        opts
      end

      private def self.parse_size(str : String) : UInt64
        s = str.strip
        return 0_u64 if s.empty?

        multiplier = 1_u64

        # All suffixes use 1024-based binary units
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
