require "../../../src/xxh"
require "../../../src/common/constants"
require "../../../src/common/types"
require "./options"

module XXHSum::CLI::Benchmark
  # Constants for benchmark tuning
  TARGET_SECONDS =   1.0_f64
  MIN_SECONDS    = 0.001_f64
  FIRST_MBPS     =    10_u64

  # Default variant IDs for quick benchmark
  DEFAULT_VARIANT_IDS = [1, 3, 5, 11]

  # Benchmark variant record (immutable, minimal boilerplate)
  # Fields:
  #   id - unique identifier (1-28)
  #   name - human-readable variant name
  #   aligned - whether to use aligned data (true) or unaligned+3 (false)
  #   kind - benchmark category: :basic, :seeded, :secret, :stream
  #   algorithm - which algorithm to test (XXH32, XXH64, XXH3_64, XXH128)
  record Variant,
    id : Int32,
    name : String,
    aligned : Bool,
    kind : Symbol,
    algorithm : Algorithm

  # Run benchmark mode with the given options
  def self.run(options : Options, io : IO = STDOUT) : Int32
    sample_size = options.benchmark_size

    # Generate fast pseudo-random sample data (not cryptographically secure)
    rng = Random.new
    aligned_data = Bytes.new(sample_size.to_i) { |i| rng.rand(256).to_u8 }

    # Create unaligned data (offset by +3 bytes) by slicing offset copy
    padded_data = Bytes.new((sample_size + 3).to_i) do |i|
      i < 3 ? 0_u8 : rng.rand(256).to_u8
    end
    unaligned_data = padded_data[3, sample_size.to_i]

    # Print version header unless -q (quiet) flag is set
    unless options.quiet
      io.puts "Crystal port of xxhsum 0.8.3"
    end

    io.puts "Sample of #{sample_size.to_f / 1024.0} KB..."

    # Build list of all available benchmark variants
    all_variants = build_benchmark_variants

    # Filter variants to run based on options
    variants_to_run = if options.benchmark_all
                        all_variants
                      elsif !options.benchmark_ids.empty?
                        options.benchmark_ids.compact_map do |id|
                          all_variants.find { |v| v.id == id }
                        end
                      else
                        all_variants.select { |v| DEFAULT_VARIANT_IDS.includes?(v.id) }
                      end

    variants_to_run.each do |variant|
      run_single_benchmark(aligned_data, unaligned_data, variant, options.benchmark_iterations, io)
    end

    0
  end

  def self.build_benchmark_variants : Array(Variant)
    [
      Variant.new(1, "XXH32", true, :basic, Algorithm::XXH32),
      Variant.new(2, "XXH32 unaligned", false, :basic, Algorithm::XXH32),
      Variant.new(3, "XXH64", true, :basic, Algorithm::XXH64),
      Variant.new(4, "XXH64 unaligned", false, :basic, Algorithm::XXH64),
      Variant.new(5, "XXH3_64b", true, :basic, Algorithm::XXH3_64),
      Variant.new(6, "XXH3_64b unaligned", false, :basic, Algorithm::XXH3_64),
      Variant.new(7, "XXH3_64b w/seed", true, :seeded, Algorithm::XXH3_64),
      Variant.new(8, "XXH3_64b w/seed unaligned", false, :seeded, Algorithm::XXH3_64),
      Variant.new(9, "XXH3_64b w/secret", true, :secret, Algorithm::XXH3_64),
      Variant.new(10, "XXH3_64b w/secret unaligned", false, :secret, Algorithm::XXH3_64),
      Variant.new(11, "XXH128", true, :basic, Algorithm::XXH128),
      Variant.new(12, "XXH128 unaligned", false, :basic, Algorithm::XXH128),
      Variant.new(13, "XXH128 w/seed", true, :seeded, Algorithm::XXH128),
      Variant.new(14, "XXH128 w/seed unaligned", false, :seeded, Algorithm::XXH128),
      Variant.new(15, "XXH128 w/secret", true, :secret, Algorithm::XXH128),
      Variant.new(16, "XXH128 w/secret unaligned", false, :secret, Algorithm::XXH128),
      Variant.new(17, "XXH32_stream", true, :stream, Algorithm::XXH32),
      Variant.new(18, "XXH32_stream unaligned", false, :stream, Algorithm::XXH32),
      Variant.new(19, "XXH64_stream", true, :stream, Algorithm::XXH64),
      Variant.new(20, "XXH64_stream unaligned", false, :stream, Algorithm::XXH64),
      Variant.new(21, "XXH3_stream", true, :stream, Algorithm::XXH3_64),
      Variant.new(22, "XXH3_stream unaligned", false, :stream, Algorithm::XXH3_64),
      Variant.new(23, "XXH3_stream w/seed", true, :stream, Algorithm::XXH3_64),
      Variant.new(24, "XXH3_stream w/seed unaligned", false, :stream, Algorithm::XXH3_64),
      Variant.new(25, "XXH128_stream", true, :stream, Algorithm::XXH128),
      Variant.new(26, "XXH128_stream unaligned", false, :stream, Algorithm::XXH128),
      Variant.new(27, "XXH128_stream w/seed", true, :stream, Algorithm::XXH128),
      Variant.new(28, "XXH128_stream w/seed unaligned", false, :stream, Algorithm::XXH128),
    ]
  end

  private def self.print_live_update(variant : Variant, buffer_size : Int32, iteration : Int32, iterations_per_sec : Float64, throughput_mb : Float64, io : IO)
    io.printf("%2d-%-30s: %10d -> %8.0f it/s (%7.1f MB/s)\r",
      iteration, variant.name, buffer_size, iterations_per_sec, throughput_mb)
    io.flush
  end

  private def self.run_single_benchmark(aligned_data : Bytes, unaligned_data : Bytes, variant : Variant, user_iterations : Int32 = 0, io : IO = STDOUT)
    data = variant.aligned ? aligned_data : unaligned_data
    max_calibrations = user_iterations > 0 ? user_iterations : 3
    run_time_based_benchmark(data, variant, max_calibrations, io)
  end

  private def self.run_time_based_benchmark(data : Bytes, variant : Variant, max_calibrations : Int32 = 3, io : IO = STDOUT)
    target_duration = TARGET_SECONDS
    min_duration = MIN_SECONDS
    initial_throughput = FIRST_MBPS * 1024_u64 * 1024_u64
    nbh_per_iteration = ((initial_throughput / data.size) + 1).to_u32
    fastest_time_per_hash = Float64::INFINITY

    max_calibrations.times do |attempt|
      start_time = Time.instant
      actual_iterations = 0_u32
      result = uninitialized UInt64
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
      print_live_update(variant, data.size, attempt + 1, iterations_per_sec, throughput_mb, io)

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
    io.printf("%80s\r", "")
    io.printf("%2d#%-30s: %10d -> %8.0f it/s (%7.1f MB/s)\n",
      variant.id, variant.name, data.size, iterations_per_sec, throughput_mb)
  end

  private def self.run_one_hash_batch(data : Bytes, variant : Variant, batch_seed : UInt32, nbh_per_iteration : UInt32) : UInt64
    result = 0_u64
    nbh_per_iteration.times do |hash_idx|
      seed = (batch_seed &* nbh_per_iteration) + hash_idx.to_u32
      result = run_single_hash(data, variant, seed)
    end
    result
  end

  private def self.run_single_hash(data : Bytes, variant : Variant, seed : UInt32) : UInt64
    case variant.kind
    when :basic  then run_basic_benchmark_one(data, variant.algorithm, seed)
    when :seeded then run_seeded_benchmark_one(data, variant.algorithm, seed)
    when :secret then run_secret_benchmark_one(data, variant.algorithm, seed)
    when :stream then run_streaming_benchmark_one(data, variant.algorithm, seed)
    else              0_u64
    end
  end

  private def self.run_basic_benchmark_one(data : Bytes, algorithm : Algorithm, seed_u : UInt32) : UInt64
    case algorithm
    when Algorithm::XXH32
      XXH::XXH32.hash(data, seed_u).to_u64
    when Algorithm::XXH64
      XXH::XXH64.hash(data, seed_u.to_u64)
    when Algorithm::XXH3_64
      XXH::XXH3.hash64(data, seed_u.to_u64)
    when Algorithm::XXH128
      result = XXH::XXH3.hash128(data, 0_u64)
      result.high64 ^ result.low64
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
    when Algorithm::XXH3_64
      XXH::XXH3.hash64(data, seed)
    when Algorithm::XXH128
      result = XXH::XXH3.hash128(data, seed)
      result.high64 ^ result.low64
    else
      0_u64
    end
  end

  private def self.run_secret_benchmark_one(data : Bytes, algorithm : Algorithm, seed_u : UInt32) : UInt64
    # Generate secret buffer on stack (136 bytes, minimal allocation)
    secret_buffer = uninitialized UInt8[136]
    (0...136).each { |i| secret_buffer[i] = (((i * 17) ^ seed_u) % 256).to_u8 }
    seed_from_secret = IO::ByteFormat::LittleEndian.decode(UInt64, Bytes.new(secret_buffer.to_unsafe, 8))
    case algorithm
    when Algorithm::XXH32, Algorithm::XXH64
      run_seeded_benchmark_one(data, algorithm, seed_u)
    when Algorithm::XXH3_64
      XXH::XXH3.hash64(data, seed_from_secret)
    when Algorithm::XXH128
      result = XXH::XXH3.hash128(data, seed_from_secret)
      result.high64 ^ result.low64
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
    when Algorithm::XXH3_64
      state = XXH::XXH3::State64.new(seed_u.to_u64)
      state.update(data)
      state.digest
    when Algorithm::XXH128
      result = XXH::XXH3.hash128(data, seed_u.to_u64)
      result.high64 ^ result.low64
    else
      0_u64
    end
  end
end
