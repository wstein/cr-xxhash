require "../../../src/xxh"
require "../../../src/common/constants"
require "../../../src/common/types"
require "./options"

module XXHSum
  module CLI
    module Benchmark
      TARGET_SECONDS = 1.0_f64
      MIN_SECONDS    = 0.1_f64
      FIRST_MBPS     =  10_u64

      record Variant,
        id : Int32,
        name : String,
        aligned : Bool,
        kind : Symbol

      def self.run(options : Options, stdout : IO = STDOUT) : Int32
        variants = selected_variants(options)
        data = prepare_data(options.benchmark_size)

        unless options.quiet
          stdout.puts "xxhsum Crystal benchmark (cr-xxhash)"
        end

        if options.benchmark_size >= 1024_u64
          kb = options.benchmark_size / 1024_u64
          stdout.puts "Sample of #{kb} KB..."
        else
          stdout.puts "Sample of #{options.benchmark_size} bytes..."
        end

        variants.each do |variant|
          run_variant(variant, data, options, stdout)
        end

        0
      end

      private def self.prepare_data(size : UInt64) : {aligned: Bytes, unaligned: Bytes}
        bytes = Bytes.new(size.to_i) { |i| ((i * 131 + 17) & 0xff).to_u8 }
        padded = Bytes.new(size.to_i + 3, 0_u8)
        bytes.each_with_index { |b, i| padded[i + 3] = b }
        {
          aligned:   bytes,
          unaligned: padded[3, size.to_i],
        }
      end

      private def self.run_variant(variant : Variant, data_set : {aligned: Bytes, unaligned: Bytes}, options : Options, stdout : IO)
        data = variant.aligned ? data_set[:aligned] : data_set[:unaligned]
        loops = ((FIRST_MBPS * 1024_u64 * 1024_u64) / (data.size + 1)).to_u64 + 1_u64
        loops = 1_u64 if loops < 1_u64

        fastest = Float64::INFINITY
        checksum = 0_u64

        options.benchmark_iterations.times do |iter|
          start = Time.instant
          local_sum = 0_u64
          i = 0_u64

          # Main benchmark loop - compute hashes with varying seeds
          while i < loops
            # Use wrapping add to ensure computation chain cannot be optimized away
            local_sum = local_sum &+ digest_variant(variant, data, i.to_u32)
            i += 1
          end

          # Accumulate checksum with data dependency to prevent optimization
          checksum = checksum &+ local_sum

          # Use checksum to create a data dependency the compiler cannot eliminate
          # This ensures all prior computation must execute
          # (The condition will never be true, but the compiler can't prove it)
          sink_value = checksum

          elapsed = (Time.instant - start).total_seconds

          # Calculate time per hash BEFORE adjusting loops for next iteration
          per_hash = elapsed > 0 ? (elapsed / loops.to_f64) : Float64::INFINITY
          fastest = per_hash if per_hash < fastest

          # Live update during calibration iterations
          if iter < options.benchmark_iterations - 1
            it_per_sec_current = per_hash.finite? && per_hash > 0 ? (1.0_f64 / per_hash) : 0.0_f64
            mb_per_sec_current = (it_per_sec_current * data.size.to_f64) / (1024_f64 * 1024_f64)
            stdout.printf("%2d#%-29s : %10d -> %8.0f it/s (%7.1f MB/s)\r",
              variant.id,
              variant.name,
              data.size,
              it_per_sec_current,
              mb_per_sec_current)
            STDOUT.flush
          end

          # Adjust loops for next iteration (if there is one)
          if elapsed < MIN_SECONDS
            adjust = (TARGET_SECONDS / (elapsed > 0 ? elapsed : 0.001_f64)).to_u64
            adjust = 1_u64 if adjust < 1_u64
            loops = (loops * adjust).clamp(1_u64, 4_000_u64 << 20)
          end
        end

        # Final result (clears the \r and prints final line)
        it_per_sec = fastest.finite? && fastest > 0 ? (1.0_f64 / fastest) : 0.0_f64
        mb_per_sec = (it_per_sec * data.size.to_f64) / (1024_f64 * 1024_f64)

        stdout.printf("%2d#%-29s : %10d -> %8.0f it/s (%7.1f MB/s)\n",
          variant.id,
          variant.name,
          data.size,
          it_per_sec,
          mb_per_sec)
      end

      private def self.digest_variant(variant : Variant, data : Bytes, seed_u32 : UInt32) : UInt64
        seed = seed_u32.to_u64
        secret = XXH::XXH3::Secret.default

        case variant.id
        when 1, 2
          XXH::XXH32.hash(data).to_u64
        when 3, 4
          XXH::XXH64.hash(data)
        when 5, 6
          XXH::XXH3.hash64(data)
        when 7, 8
          XXH::XXH3.hash64(data, seed)
        when 9, 10
          XXH::Bindings::XXH3_64.hash_with_secret(data, secret)
        when 11, 12
          reduce_u128(XXH::XXH3.hash128(data))
        when 13, 14
          reduce_u128(XXH::XXH3.hash128(data, seed))
        when 15, 16
          reduce_u128(XXH::Bindings::XXH3_128.hash_with_secret(data, secret))
        when 17, 18
          state = XXH::XXH32::State.new
          state.update(data)
          state.digest.to_u64
        when 19, 20
          state = XXH::XXH64::State.new
          state.update(data)
          state.digest
        when 21, 22
          state = XXH::XXH3::State64.new
          state.update(data)
          state.digest
        when 23, 24
          state = XXH::XXH3::State64.new(seed)
          state.update(data)
          state.digest
        when 25, 26
          state = XXH::XXH3::State128.new
          state.update(data)
          reduce_u128(state.digest)
        when 27, 28
          state = XXH::XXH3::State128.new(seed)
          state.update(data)
          reduce_u128(state.digest)
        else
          0_u64
        end
      end

      private def self.reduce_u128(value : UInt128) : UInt64
        value.low64 ^ value.high64
      end

      private def self.selected_variants(options : Options) : Array(Variant)
        all = all_variants
        return all if options.benchmark_all

        if options.benchmark_ids.empty?
          defaults = [1, 3, 5, 11]
          return all.select { |v| defaults.includes?(v.id) }
        end

        all.select { |v| options.benchmark_ids.includes?(v.id) }
      end

      private def self.all_variants : Array(Variant)
        [
          Variant.new(1, "XXH32", true, :basic),
          Variant.new(2, "XXH32 unaligned", false, :basic),
          Variant.new(3, "XXH64", true, :basic),
          Variant.new(4, "XXH64 unaligned", false, :basic),
          Variant.new(5, "XXH3_64b", true, :basic),
          Variant.new(6, "XXH3_64b unaligned", false, :basic),
          Variant.new(7, "XXH3_64b w/seed", true, :seeded),
          Variant.new(8, "XXH3_64b w/seed unaligned", false, :seeded),
          Variant.new(9, "XXH3_64b w/secret", true, :secret),
          Variant.new(10, "XXH3_64b w/secret unaligned", false, :secret),
          Variant.new(11, "XXH128", true, :basic),
          Variant.new(12, "XXH128 unaligned", false, :basic),
          Variant.new(13, "XXH128 w/seed", true, :seeded),
          Variant.new(14, "XXH128 w/seed unaligned", false, :seeded),
          Variant.new(15, "XXH128 w/secret", true, :secret),
          Variant.new(16, "XXH128 w/secret unaligned", false, :secret),
          Variant.new(17, "XXH32_stream", true, :stream),
          Variant.new(18, "XXH32_stream unaligned", false, :stream),
          Variant.new(19, "XXH64_stream", true, :stream),
          Variant.new(20, "XXH64_stream unaligned", false, :stream),
          Variant.new(21, "XXH3_stream", true, :stream),
          Variant.new(22, "XXH3_stream unaligned", false, :stream),
          Variant.new(23, "XXH3_stream w/seed", true, :stream),
          Variant.new(24, "XXH3_stream w/seed unaligned", false, :stream),
          Variant.new(25, "XXH128_stream", true, :stream),
          Variant.new(26, "XXH128_stream unaligned", false, :stream),
          Variant.new(27, "XXH128_stream w/seed", true, :stream),
          Variant.new(28, "XXH128_stream w/seed unaligned", false, :stream),
        ]
      end
    end
  end
end
