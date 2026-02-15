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

      def self.parse(argv : Array(String)) : Options
        opts = Options.new
        parser = OptionParser.new do |p|
          p.banner = "Usage: xxhsum [options] [FILES...]"

          p.on("-H INDEX", "Select algorithm (0=XXH32,1=XXH64,2=XXH128,3=XXH3_64)") do |v|
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

          p.on("--tag", "BSD-style output") { opts.bsd = true }
          p.on("-q", "--quiet", "Suppress extra output (bench/status) (not used in MVP)") { opts.quiet = true }

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

        parser.parse(argv)
        opts
      end
    end
  end
end
