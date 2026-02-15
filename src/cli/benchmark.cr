require "../xxh/common"
require "../xxh/primitives"
require "../xxh/xxh32"
require "../xxh/xxh64"
require "../xxh/xxh3"
require "./formatter"
require "./options"

module XXH::CLI
  # Benchmark variant structure (used by CLI benchmark)
  struct BenchmarkVariant
    def initialize(@id : Int32, @name : String, @aligned : Bool, @variant_type : String, @algorithm : Algorithm)
    end

    getter id : Int32
    getter name : String
    getter aligned : Bool
    getter variant_type : String
    getter algorithm : Algorithm
  end

  # Run benchmark mode - delegates to Benchmark module
  def self.run_benchmark_mode(options : Options)
    Benchmark.run(options)
  end

  # Benchmark implementation module
  module Benchmark
    # Run benchmark mode with the given options
    def self.run(options : Options)
      sample_size = options.sample_size

      # Generate fast pseudo-random sample data (not cryptographically secure)
      rng = Random.new
      data_array = Array(UInt8).new(sample_size) { rng.rand(256).to_u8 }
      aligned_data = Bytes.new(data_array.size) { |i| data_array[i] }

      # Create unaligned data (offset by +3 bytes)
      padded_array = Array(UInt8).new(data_array.size + 3) { 0_u8 }
      data_array.each_with_index { |byte, i| padded_array[i + 3] = byte }
      unaligned_data = Bytes.new(padded_array.size - 3) { |i| padded_array[i + 3] }

      # Print version header unless -q (quiet) flag is set
      unless options.quiet
        puts "Crystal port of xxhsum 0.8.3"
      end

      puts "Sample of #{sample_size.to_f / 1024.0} KB..."

      # Build list of all available benchmark variants
      all_variants = build_benchmark_variants

      # Filter variants to run based on options
      variants_to_run = if options.benchmark_all
                          all_variants
                        elsif !options.benchmark_variants.empty?
                          options.benchmark_variants.map do |id|
                            all_variants.find { |v| v.id == id }
                          end.compact
                        elsif options.benchmark_id > 0
                          variant = all_variants.find { |v| v.id == options.benchmark_id }
                          variant ? [variant] : ([] of BenchmarkVariant)
                        else
                          default_ids = [1, 3, 5, 11]
                          all_variants.select { |v| default_ids.includes?(v.id) }
                        end

      variants_to_run.each do |variant|
        run_single_benchmark(aligned_data, unaligned_data, variant, options.iterations)
      end
    end

    def self.build_benchmark_variants : Array(BenchmarkVariant)
      [
        BenchmarkVariant.new(id: 1, name: "XXH32", aligned: true, variant_type: "basic", algorithm: Algorithm::XXH32),
        BenchmarkVariant.new(id: 2, name: "XXH32 unaligned", aligned: false, variant_type: "basic", algorithm: Algorithm::XXH32),
        BenchmarkVariant.new(id: 3, name: "XXH64", aligned: true, variant_type: "basic", algorithm: Algorithm::XXH64),
        BenchmarkVariant.new(id: 4, name: "XXH64 unaligned", aligned: false, variant_type: "basic", algorithm: Algorithm::XXH64),
        BenchmarkVariant.new(id: 5, name: "XXH3_64b", aligned: true, variant_type: "basic", algorithm: Algorithm::XXH3),
        BenchmarkVariant.new(id: 6, name: "XXH3_64b unaligned", aligned: false, variant_type: "basic", algorithm: Algorithm::XXH3),
        BenchmarkVariant.new(id: 7, name: "XXH3_64b w/seed", aligned: true, variant_type: "seeded", algorithm: Algorithm::XXH3),
        BenchmarkVariant.new(id: 8, name: "XXH3_64b w/seed unaligned", aligned: false, variant_type: "seeded", algorithm: Algorithm::XXH3),
        BenchmarkVariant.new(id: 9, name: "XXH3_64b w/secret", aligned: true, variant_type: "secret", algorithm: Algorithm::XXH3),
        BenchmarkVariant.new(id: 10, name: "XXH3_64b w/secret unaligned", aligned: false, variant_type: "secret", algorithm: Algorithm::XXH3),
        BenchmarkVariant.new(id: 11, name: "XXH128", aligned: true, variant_type: "basic", algorithm: Algorithm::XXH128),
        BenchmarkVariant.new(id: 12, name: "XXH128 unaligned", aligned: false, variant_type: "basic", algorithm: Algorithm::XXH128),
        BenchmarkVariant.new(id: 13, name: "XXH128 w/seed", aligned: true, variant_type: "seeded", algorithm: Algorithm::XXH128),
        BenchmarkVariant.new(id: 14, name: "XXH128 w/seed unaligned", aligned: false, variant_type: "seeded", algorithm: Algorithm::XXH128),
        BenchmarkVariant.new(id: 15, name: "XXH128 w/secret", aligned: true, variant_type: "secret", algorithm: Algorithm::XXH128),
        BenchmarkVariant.new(id: 16, name: "XXH128 w/secret unaligned", aligned: false, variant_type: "secret", algorithm: Algorithm::XXH128),
        BenchmarkVariant.new(id: 17, name: "XXH32_stream", aligned: true, variant_type: "stream", algorithm: Algorithm::XXH32),
        BenchmarkVariant.new(id: 18, name: "XXH32_stream unaligned", aligned: false, variant_type: "stream", algorithm: Algorithm::XXH32),
        BenchmarkVariant.new(id: 19, name: "XXH64_stream", aligned: true, variant_type: "stream", algorithm: Algorithm::XXH64),
        BenchmarkVariant.new(id: 20, name: "XXH64_stream unaligned", aligned: false, variant_type: "stream", algorithm: Algorithm::XXH64),
        BenchmarkVariant.new(id: 21, name: "XXH3_stream", aligned: true, variant_type: "stream", algorithm: Algorithm::XXH3),
        BenchmarkVariant.new(id: 22, name: "XXH3_stream unaligned", aligned: false, variant_type: "stream", algorithm: Algorithm::XXH3),
        BenchmarkVariant.new(id: 23, name: "XXH3_stream w/seed", aligned: true, variant_type: "stream", algorithm: Algorithm::XXH3),
        BenchmarkVariant.new(id: 24, name: "XXH3_stream w/seed unaligned", aligned: false, variant_type: "stream", algorithm: Algorithm::XXH3),
        BenchmarkVariant.new(id: 25, name: "XXH128_stream", aligned: true, variant_type: "stream", algorithm: Algorithm::XXH128),
        BenchmarkVariant.new(id: 26, name: "XXH128_stream unaligned", aligned: false, variant_type: "stream", algorithm: Algorithm::XXH128),
        BenchmarkVariant.new(id: 27, name: "XXH128_stream w/seed", aligned: true, variant_type: "stream", algorithm: Algorithm::XXH128),
        BenchmarkVariant.new(id: 28, name: "XXH128_stream w/seed unaligned", aligned: false, variant_type: "stream", algorithm: Algorithm::XXH128),
      ]
    end

    private def self.print_live_update(variant : BenchmarkVariant, buffer_size : Int32, iteration : Int32, iterations_per_sec : Float64, throughput_mb : Float64)
      printf("%2d-%-30s: %10d -> %8.0f it/s (%7.1f MB/s)\r",
        iteration, variant.name, buffer_size, iterations_per_sec, throughput_mb)
      STDOUT.flush
    end

    private def self.run_single_benchmark(aligned_data : Bytes, unaligned_data : Bytes, variant : BenchmarkVariant, user_iterations : Int32 = 0)
      data = variant.aligned ? aligned_data : unaligned_data
      max_calibrations = user_iterations > 0 ? user_iterations : 3
      run_time_based_benchmark(data, variant, max_calibrations)
    end

    private def self.run_time_based_benchmark(data : Bytes, variant : BenchmarkVariant, max_calibrations : Int32 = 3)
      target_duration = 1.0_f64
      min_duration = 0.5_f64
      initial_throughput = 10_u64 * 1024_u64 * 1024_u64
      nbh_per_iteration = ((initial_throughput / data.size) + 1).to_u32
      fastest_time_per_hash = Float64::INFINITY

      max_calibrations.times do |attempt|
        start_time = Time.instant
        actual_iterations = 0_u32
        result = 0_u64
        iteration_number = 0_u32

        while (Time.instant - start_time).total_seconds < target_duration
          result = run_one_hash_batch(data, variant, iteration_number, nbh_per_iteration)
          actual_iterations += nbh_per_iteration
          iteration_number += 1
        end

        elapsed = Time.instant - start_time
        elapsed_seconds = elapsed.total_seconds

        if elapsed_seconds > 0 && actual_iterations > 0
          time_per_hash = elapsed_seconds / actual_iterations.to_f
          if time_per_hash < fastest_time_per_hash
            fastest_time_per_hash = time_per_hash
          end
        end

        iterations_per_sec = fastest_time_per_hash > 1e-15 ? 1.0 / fastest_time_per_hash : 0.0
        throughput_mb = (iterations_per_sec * data.size.to_f) / (1024_f64 * 1024_f64)
        print_live_update(variant, data.size, attempt + 1, iterations_per_sec, throughput_mb)

        if elapsed_seconds >= min_duration
          # valid
        else
          if elapsed_seconds == 0
            nbh_per_iteration *= 100_u32
          else
            new_nbh = ((target_duration / elapsed_seconds) * nbh_per_iteration).to_u32
            nbh_per_iteration = new_nbh.clamp(1_u32, 10_000_000_u32)
          end
        end
      end

      iterations_per_sec = fastest_time_per_hash > 0 && fastest_time_per_hash != Float64::INFINITY ? 1.0 / fastest_time_per_hash : 0.0
      throughput_mb = (iterations_per_sec * data.size.to_f) / (1024_f64 * 1024_f64)
      printf("%80s\r", "")
      printf("%2d#%-30s: %10d -> %8.0f it/s (%7.1f MB/s)\n",
        variant.id, variant.name, data.size, iterations_per_sec, throughput_mb)
    end

    private def self.run_one_hash_batch(data : Bytes, variant : BenchmarkVariant, batch_seed : UInt32, nbh_per_iteration : UInt32) : UInt64
      result : UInt64 = 0_u64
      nbh_per_iteration.times do |hash_idx|
        seed = (batch_seed &* nbh_per_iteration) + hash_idx.to_u32
        result = run_single_hash(data, variant, seed)
      end
      result
    end

    private def self.run_single_hash(data : Bytes, variant : BenchmarkVariant, seed : UInt32) : UInt64
      case variant.variant_type
      when "basic"  then run_basic_benchmark_one(data, variant.algorithm, seed)
      when "seeded" then run_seeded_benchmark_one(data, variant.algorithm, seed)
      when "secret" then run_secret_benchmark_one(data, variant.algorithm, seed)
      when "stream" then run_streaming_benchmark_one(data, variant.algorithm, seed)
      else               0_u64
      end
    end

    private def self.run_basic_benchmark_one(data : Bytes, algorithm : Algorithm, seed_u : UInt32) : UInt64
      case algorithm
      when Algorithm::XXH32
        XXH::XXH32.hash(data, seed_u).to_u64
      when Algorithm::XXH64
        XXH::XXH64.hash(data, seed_u.to_u64)
      when Algorithm::XXH3
        XXH::XXH3.hash_with_seed(data, seed_u.to_u64)
      when Algorithm::XXH128
        result = XXH::Dispatch.hash_xxh128(data, 0_u64)
        (result[0] ^ result[1]).to_u64
      else
        0_u64
      end
    end

    private def self.run_seeded_benchmark_one(data : Bytes, algorithm : Algorithm, seed_u : UInt32) : UInt64
      base_seed = 42_u64
      seed = (base_seed + seed_u.to_u64) ^ 0xc4ceb9fe1a85ec53_u64
      case algorithm
      when Algorithm::XXH32
        XXH::XXH32.hash(data, seed.to_u32).to_u64
      when Algorithm::XXH64
        XXH::XXH64.hash(data, seed)
      when Algorithm::XXH3
        XXH::XXH3.hash_with_seed(data, seed)
      when Algorithm::XXH128
        result = XXH::Dispatch.hash_xxh128(data, seed)
        (result[0] ^ result[1]).to_u64
      else
        0_u64
      end
    end

    private def self.run_secret_benchmark_one(data : Bytes, algorithm : Algorithm, seed_u : UInt32) : UInt64
      secret_buffer = Bytes.new(XXH::Constants::XXH3_SECRET_SIZE_MIN) { |i| (((i * 17) ^ seed_u) % 256).to_u8 }
      seed_from_secret = XXH::Primitives.read_u64_le(secret_buffer.to_unsafe)
      case algorithm
      when Algorithm::XXH32, Algorithm::XXH64
        run_seeded_benchmark_one(data, algorithm, seed_u)
      when Algorithm::XXH3
        XXH::XXH3.hash_with_seed(data, seed_from_secret)
      when Algorithm::XXH128
        result = XXH::Dispatch.hash_xxh128(data, seed_from_secret)
        (result[0] ^ result[1]).to_u64
      else
        0_u64
      end
    end

    private def self.run_streaming_benchmark_one(data : Bytes, algorithm : Algorithm, seed_u : UInt32) : UInt64
      case algorithm
      when Algorithm::XXH32
        state = XXH::XXH32::State.new(seed_u)
        state.update(data)
        state.digest.to_u64
      when Algorithm::XXH64
        state = XXH::XXH64::State.new(seed_u.to_u64)
        state.update(data)
        state.digest
      when Algorithm::XXH3
        state = XXH::XXH3.new_state(seed_u.to_u64)
        state.update(data)
        state.digest
      when Algorithm::XXH128
        res = XXH::Dispatch.hash_xxh128(data, seed_u.to_u64)
        (res[0] ^ res[1]).to_u64
      else
        0_u64
      end
    end
  end
end
