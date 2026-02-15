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
          p.banner = "Usage: xxhsum [options] [FILES...]"
          p.on("-H#", "Select algorithm (0=XXH32,1=XXH64,2=XXH128,3=XXH3_64)") { }
          p.on("-c", "--check", "Verify checksums from file") { }
          p.on("--tag", "BSD-style output") { }
          p.on("-q", "--quiet", "Suppress extra output (bench/status) (not used in MVP)") { }
          p.on("--ignore-missing", "Don't fail for missing files") { }
          p.on("--strict", "Exit non-zero for improperly formatted lines") { }
          p.on("-b", "Run benchmark") { }
          p.on("--bench-all", "Run all 28 benchmark variants (equivalent to -b0)") { }
          p.on("-i#", "Number of times to run benchmark (default: 3)") { }
          p.on("-B#", "Benchmark sample size (supports K,KB,M,MB,G,GB — 1024-based; KiB/MiB/GiB accepted)") { }
          p.on("-s SEED", "--seed SEED", "Seed (decimal or 0xHEX)") { }
          p.on("--version", "Print version and exit") { }
          p.on("-h", "--help", "Show this help") { }
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
          p.banner = "Usage: xxhsum [options] [FILES...]"

          p.on("-H#", "Select algorithm (0=XXH32,1=XXH64,2=XXH128,3=XXH3_64)") do |v|
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

          p.on("-c", "--check", "Verify checksums from file") { opts.check_mode = true }
          p.on("--tag", "BSD-style output") { opts.bsd = true }
          p.on("-q", "--quiet", "Suppress extra output (bench/status) (not used in MVP)") { opts.quiet = true }
          p.on("--ignore-missing", "Don't fail for missing files") { opts.ignore_missing = true }
          p.on("--strict", "Exit non-zero for improperly formatted lines") { opts.strict = true }

          p.on("-b", "Run benchmark") { opts.benchmark = true }
          p.on("--bench-all", "Run all 28 benchmark variants (equivalent to -b0)") do
            opts.benchmark = true
            opts.benchmark_all = true
            opts.benchmark_ids.clear
          end

          p.on("-i#", "Number of times to run benchmark (default: 3)") do |v|
            iters = v.to_i
            if iters < 1
              STDERR.puts "Error: benchmark iterations must be >= 1"
              exit 1
            end
            opts.benchmark_iterations = iters
          end

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

          p.on("--version", "Print version and exit") do
            puts "xxhsum Crystal (example) #{XXH::VERSION}"
            exit 0
          end

          p.on("-h", "--help", "Show this help") do
            puts p
            exit 0
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
