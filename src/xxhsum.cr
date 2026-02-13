# xxHash Crystal CLI - xxhsum
#
# Command-line interface for xxHash algorithm family.

require "./cli/options"
require "./cli/hasher"
require "./cli/formatter"
require "./common/common"
require "./common/primitives"

module XXH::CLI
  # Main CLI entry point
  def self.run(argv = ARGV)
    parser = Parser.new(argv)
    unless parser.parse
      STDERR.puts "Wrong parameters"
      exit 1
    end

    options = parser.options

    # Determine files to process
    files = options.files

    # Benchmark mode doesn't require files
    if options.mode == Options::Mode::Benchmark
      run_benchmark_mode(options)
      return
    end

    # Handle stdin case for hash/check modes
    if files.empty? || (files.size == 1 && files[0] == "-")
      if options.explicit_stdin || !STDIN.tty?
        files = ["-"]
      else
        STDERR.puts "No input provided"
        exit 1
      end
    end

    case options.mode
    when Options::Mode::Hash
      run_hash_mode(files, options)
    when Options::Mode::Check
      run_check_mode(files, options)
    when Options::Mode::FilesFrom
      run_files_from_mode(files, options)
    when Options::Mode::Benchmark
      run_benchmark_mode(options)
    end
  end

  private def self.run_hash_mode(files : Array(String), options : Options)
    # Hash files in parallel using fibers
    results = FileHasher.hash_files_parallel(files, options.algorithm, options.simd_mode)

    # Output results in order
    files.each do |filename|
      result = results.find { |r| r.filename == filename }
      next unless result

      output = Formatter.format(result, options.algorithm, options.convention, options.endianness)
      puts output if output
    end
  end

  private def self.run_check_mode(files : Array(String), options : Options)
    all_ok = true

    files.each do |filepath|
      ok = verify_checksum_file(filepath, options)
      all_ok = false unless ok
    end

    exit all_ok ? 0 : 1
  end

  private def self.verify_checksum_file(filepath : String, options : Options) : Bool
    return false unless File.exists?(filepath)

    algo_bitmask = (1 << Algorithm::XXH32.value) | (1 << Algorithm::XXH64.value) |
                   (1 << Algorithm::XXH128.value) | (1 << Algorithm::XXH3.value)

    line_number = 0
    properly_formatted = 0
    improperly_formatted = 0
    matched = 0
    mismatched = 0
    open_failures = 0

    File.each_line(filepath) do |line|
      line_number += 1

      parsed = Formatter.parse_checksum_line(line, algo_bitmask)
      unless parsed
        improperly_formatted += 1
        if options.warn
          STDERR.puts "#{filepath}:#{line_number}: Error: Improperly formatted checksum line"
        end
        next
      end

      properly_formatted += 1

      filename = parsed[:filename]
      algorithm = parsed[:algorithm]
      expected_hash = parsed[:hash]
      is_le = parsed[:is_le]

      # Handle stdin
      if filename == "stdin"
        actual = FileHasher.hash_stdin(algorithm, options.simd_mode)
      else
        # Check if file exists
        unless File.exists?(filename)
          if options.ignore_missing
            next
          else
            open_failures += 1
            unless options.status
              STDERR.puts "#{filepath}:#{line_number}: Could not open or read '#{filename}': No such file or directory"
            end
            next
          end
        end

        actual = FileHasher.hash_file(filename, algorithm, options.simd_mode)
      end

      next unless actual.success

      # Compare hashes
      hash_ok = false
      case algorithm
      when Algorithm::XXH32
        if h32 = actual.hash32
          hash_bytes = endianness_to_bytes(h32, is_le)
          hash_ok = hash_bytes == expected_hash
        end
      when Algorithm::XXH64, Algorithm::XXH3
        if h64 = actual.hash64
          hash_bytes = endianness_to_bytes(h64, is_le)
          hash_ok = hash_bytes == expected_hash
        end
      when Algorithm::XXH128
        if h128 = actual.hash128
          # Output format: high64 then low64 for big-endian, low64_le then high64_le for little-endian
          if is_le
            hash_bytes = endianness_to_bytes(h128[0], true) + endianness_to_bytes(h128[1], true)
          else
            hash_bytes = endianness_to_bytes(h128[1], false) + endianness_to_bytes(h128[0], false)
          end
          hash_ok = hash_bytes == expected_hash
        end
      end

      if hash_ok
        matched += 1
        unless options.quiet || options.status
          puts "#{filename}: OK"
        end
      else
        mismatched += 1
        puts "#{filename}: FAILED"
      end
    end

    # Summary
    unless options.status
      if properly_formatted == 0
        STDERR.puts "#{filepath}: no properly formatted xxHash checksum lines found"
      elsif improperly_formatted > 0
        puts "#{improperly_formatted} #{improperly_formatted == 1 ? "line is" : "lines are"} improperly formatted"
      end
      if open_failures > 0
        puts "#{open_failures} listed #{open_failures == 1 ? "file" : "files"} could not be read"
      end
      if mismatched > 0
        puts "#{mismatched} #{mismatched == 1 ? "checksum" : "checksums"} did NOT match"
      end
    end

    # Check result
    ok = properly_formatted > 0 &&
         mismatched == 0 &&
         open_failures == 0 &&
         (!options.strict || improperly_formatted == 0)

    if options.ignore_missing && matched == 0
      unless options.status
        puts "#{filepath}: no file was verified"
      end
      return false
    end

    ok
  end

  private def self.run_files_from_mode(files : Array(String), options : Options)
    # Read file list and hash files
    files.each do |filepath|
      if File.directory?(filepath)
        STDERR.puts "#{filepath}: Is a directory"
        next
      end

      begin
        File.read_lines(filepath).each do |line|
          line = line.strip
          next if line.empty?
          next if line.starts_with?('#')

          # Unescape filename if needed
          filename = if line.starts_with?('\\')
                       Formatter.unescape_filename(line[1..]) || line[1..]
                     else
                       line
                     end

          result = FileHasher.hash_file(filename, options.algorithm, options.simd_mode)
          output = Formatter.format(result, options.algorithm, options.convention, options.endianness)
          puts output if output
        end
      rescue ex
        STDERR.puts "Error reading #{filepath}: #{ex.message}"
      end
    end
  end

  # Benchmark variant structure
  private struct BenchmarkVariant
    def initialize(@id : Int32, @name : String, @aligned : Bool, @variant_type : String, @algorithm : Algorithm)
    end

    getter id : Int32
    getter name : String
    getter aligned : Bool
    getter variant_type : String
    getter algorithm : Algorithm
  end

  private def self.run_benchmark_mode(options : Options)
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
                        # User specified -b0, -b29+, --bench-all, or comma-separated list
                        # Run all 28 variants
                        all_variants
                      elsif !options.benchmark_variants.empty?
                        # User specified specific variants with -b1,3,5
                        options.benchmark_variants.map do |id|
                          all_variants.find { |v| v.id == id }
                        end.compact
                      elsif options.benchmark_id > 0
                        # User specified a single benchmark ID with -b1
                        variant = all_variants.find { |v| v.id == options.benchmark_id }
                        variant ? [variant] : ([] of BenchmarkVariant)
                      else
                        # No specific variants requested, use defaults (1,3,5,11)
                        default_ids = [1, 3, 5, 11]
                        all_variants.select { |v| default_ids.includes?(v.id) }
                      end

    # Run benchmarks
    variants_to_run.each do |variant|
      run_single_benchmark(aligned_data, unaligned_data, variant, options.iterations)
    end
  end

  private def self.build_benchmark_variants : Array(BenchmarkVariant)
    [
      # Basic variants (1-8)
      BenchmarkVariant.new(id: 1, name: "XXH32", aligned: true, variant_type: "basic", algorithm: Algorithm::XXH32),
      BenchmarkVariant.new(id: 2, name: "XXH32 unaligned", aligned: false, variant_type: "basic", algorithm: Algorithm::XXH32),
      BenchmarkVariant.new(id: 3, name: "XXH64", aligned: true, variant_type: "basic", algorithm: Algorithm::XXH64),
      BenchmarkVariant.new(id: 4, name: "XXH64 unaligned", aligned: false, variant_type: "basic", algorithm: Algorithm::XXH64),
      BenchmarkVariant.new(id: 5, name: "XXH3_64b", aligned: true, variant_type: "basic", algorithm: Algorithm::XXH3),
      BenchmarkVariant.new(id: 6, name: "XXH3_64b unaligned", aligned: false, variant_type: "basic", algorithm: Algorithm::XXH3),
      BenchmarkVariant.new(id: 7, name: "XXH3_64b w/seed", aligned: true, variant_type: "seeded", algorithm: Algorithm::XXH3),
      BenchmarkVariant.new(id: 8, name: "XXH3_64b w/seed unaligned", aligned: false, variant_type: "seeded", algorithm: Algorithm::XXH3),

      # Secret variants (9-16)
      BenchmarkVariant.new(id: 9, name: "XXH3_64b w/secret", aligned: true, variant_type: "secret", algorithm: Algorithm::XXH3),
      BenchmarkVariant.new(id: 10, name: "XXH3_64b w/secret unaligned", aligned: false, variant_type: "secret", algorithm: Algorithm::XXH3),
      BenchmarkVariant.new(id: 11, name: "XXH128", aligned: true, variant_type: "basic", algorithm: Algorithm::XXH128),
      BenchmarkVariant.new(id: 12, name: "XXH128 unaligned", aligned: false, variant_type: "basic", algorithm: Algorithm::XXH128),
      BenchmarkVariant.new(id: 13, name: "XXH128 w/seed", aligned: true, variant_type: "seeded", algorithm: Algorithm::XXH128),
      BenchmarkVariant.new(id: 14, name: "XXH128 w/seed unaligned", aligned: false, variant_type: "seeded", algorithm: Algorithm::XXH128),
      BenchmarkVariant.new(id: 15, name: "XXH128 w/secret", aligned: true, variant_type: "secret", algorithm: Algorithm::XXH128),
      BenchmarkVariant.new(id: 16, name: "XXH128 w/secret unaligned", aligned: false, variant_type: "secret", algorithm: Algorithm::XXH128),

      # Streaming variants (17-28)
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

  # Print live update showing progress with throughput
  # Uses \r to return to start of line for overwriting
  private def self.print_live_update(variant : BenchmarkVariant, buffer_size : Int32, iteration : Int32, iterations_per_sec : Float64, throughput_mb : Float64)
    printf("%2d-%-30s: %10d -> %8.0f it/s (%7.1f MB/s)\r",
      iteration,
      variant.name,
      buffer_size,
      iterations_per_sec,
      throughput_mb)
    STDOUT.flush
  end

  private def self.run_single_benchmark(aligned_data : Bytes, unaligned_data : Bytes, variant : BenchmarkVariant, user_iterations : Int32 = 0)
    # Select data based on alignment
    data = variant.aligned ? aligned_data : unaligned_data

    # If user specified iterations, use that as max calibration rounds
    # Otherwise use default calibration
    max_calibrations = if user_iterations > 0
                         user_iterations
                       else
                         3 # Default per original C code (NBLOOPS_DEFAULT)
                       end

    run_time_based_benchmark(data, variant, max_calibrations)
  end

  # Time-based benchmark following C99 xxhsum algorithm
  # max_calibrations: maximum number of calibration rounds
  private def self.run_time_based_benchmark(data : Bytes, variant : BenchmarkVariant, max_calibrations : Int32 = 3)
    target_duration = 1.0_f64 # Target: 1 second per iteration
    min_duration = 0.5_f64    # Minimum: 0.5 second to validate result

    # Initial estimate based on 10 MB/s speed target
    initial_throughput = 10_u64 * 1024_u64 * 1024_u64 # 10 MB/s
    nbh_per_iteration = ((initial_throughput / data.size) + 1).to_u32

    fastest_time_per_hash = Float64::INFINITY

    # Calibration loop
    max_calibrations.times do |attempt|
      # Time one iteration - run hashes in a loop until we reach target time
      start_time = Time.instant

      # The actual hashing loop - run hashes in blocks of nbh_per_iteration
      # until we hit the target duration
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

      # Guard against division by zero and underflow
      if elapsed_seconds > 0 && actual_iterations > 0
        time_per_hash = elapsed_seconds / actual_iterations.to_f

        if time_per_hash < fastest_time_per_hash
          fastest_time_per_hash = time_per_hash
        end
      end

      # Calculate live display metrics (avoid infinity)
      iterations_per_sec = if fastest_time_per_hash > 1e-15
                             1.0 / fastest_time_per_hash
                           else
                             0.0
                           end
      throughput_mb = (iterations_per_sec * data.size.to_f) / (1024_f64 * 1024_f64)

      # Print live progress update
      print_live_update(variant, data.size, attempt + 1, iterations_per_sec, throughput_mb)

      # Check if measurement is valid
      if elapsed_seconds >= min_duration
        # Valid measurement - but keep running for all calibrations to get the fastest
        # (only break if this is the last iteration)
      else
        # Not enough time - extrapolate for next attempt
        if elapsed_seconds == 0
          nbh_per_iteration *= 100_u32
        else
          # Calculate hashes needed to hit target duration
          new_nbh = ((target_duration / elapsed_seconds) * nbh_per_iteration).to_u32
          nbh_per_iteration = new_nbh.clamp(1_u32, 10_000_000_u32)
        end
      end
    end

    # Calculate final throughput from fastest measurement
    iterations_per_sec = if fastest_time_per_hash > 0 && fastest_time_per_hash != Float64::INFINITY
                           1.0 / fastest_time_per_hash
                         else
                           0.0
                         end
    # Throughput = hashes_per_second * bytes_per_hash
    throughput_mb = (iterations_per_sec * data.size.to_f) / (1024_f64 * 1024_f64)

    # Clear the live update line and print final result
    printf("%80s\r", "") # Clean line
    printf("%2d#%-30s: %10d -> %8.0f it/s (%7.1f MB/s)\n",
      variant.id, variant.name, data.size, iterations_per_sec, throughput_mb)
  end

  # Run one batch of nbh_per_iteration hashes with seed variation
  private def self.run_one_hash_batch(data : Bytes, variant : BenchmarkVariant, batch_seed : UInt32, nbh_per_iteration : UInt32) : UInt64
    result : UInt64 = 0_u64

    nbh_per_iteration.times do |hash_idx|
      seed = (batch_seed &* nbh_per_iteration) + hash_idx.to_u32
      result = run_single_hash(data, variant, seed)
    end

    @@benchmark_result = result
    result
  end

  # Run a single hash with the given seed variation
  private def self.run_single_hash(data : Bytes, variant : BenchmarkVariant, seed : UInt32) : UInt64
    case variant.variant_type
    when "basic"
      run_basic_benchmark_one(data, variant.algorithm, seed)
    when "seeded"
      run_seeded_benchmark_one(data, variant.algorithm, seed)
    when "secret"
      run_secret_benchmark_one(data, variant.algorithm, seed)
    when "stream"
      run_streaming_benchmark_one(data, variant.algorithm, seed)
    else
      0_u64
    end
  end

  # Class variable to store benchmark result (prevents optimization)
  @@benchmark_result : UInt64 = 0_u64

  private def self.run_benchmark_iterations(data : Bytes, variant : BenchmarkVariant, iterations : Int32)
    case variant.variant_type
    when "basic"
      run_basic_benchmark(data, variant.algorithm, iterations)
    when "seeded"
      run_seeded_benchmark(data, variant.algorithm, iterations)
    when "secret"
      run_secret_benchmark(data, variant.algorithm, iterations)
    when "stream"
      run_streaming_benchmark(data, variant.algorithm, iterations)
    end
  end

  # Single hash with seed variation (for time-based loop)
  private def self.run_basic_benchmark_one(data : Bytes, algorithm : Algorithm, seed_u : UInt32) : UInt64
    case algorithm
    when Algorithm::XXH32
      XXH::XXH32.hash(data, seed_u).to_u64
    when Algorithm::XXH64
      XXH::XXH64.hash(data, seed_u.to_u64)
    when Algorithm::XXH3
      XXH::XXH3.hash_with_seed(data, seed_u.to_u64)
    when Algorithm::XXH128
      h = XXH::XXH3.hash128(data)
      (h.low64 ^ h.high64).to_u64
    else
      0_u64
    end
  end

  # Old: Fixed iteration method (kept for compatibility)
  private def self.run_basic_benchmark(data : Bytes, algorithm : Algorithm, iterations : Int32)
    case algorithm
    when Algorithm::XXH32
      iterations.times do
        XXH::XXH32.hash(data, 0_u32)
      end
    when Algorithm::XXH64
      iterations.times do
        XXH::XXH64.hash(data, 0_u64)
      end
    when Algorithm::XXH3
      iterations.times do
        XXH::XXH3.hash(data)
      end
    when Algorithm::XXH128
      iterations.times do
        XXH::XXH3.hash128(data)
      end
    end
  end

  # Single seeded hash with seed variation (for time-based loop)
  private def self.run_seeded_benchmark_one(data : Bytes, algorithm : Algorithm, seed_u : UInt32) : UInt64
    base_seed = 42_u64
    # Vary seed across iterations to prevent optimization
    seed = (base_seed + seed_u.to_u64) ^ 0xc4ceb9fe1a85ec53_u64

    case algorithm
    when Algorithm::XXH32
      XXH::XXH32.hash(data, seed.to_u32).to_u64
    when Algorithm::XXH64
      XXH::XXH64.hash(data, seed)
    when Algorithm::XXH3
      XXH::XXH3.hash_with_seed(data, seed)
    when Algorithm::XXH128
      h = XXH::XXH3.hash128_with_seed(data, seed)
      (h.low64 ^ h.high64).to_u64
    else
      0_u64
    end
  end

  # Old: Fixed iteration seeded method (kept for compatibility)
  private def self.run_seeded_benchmark(data : Bytes, algorithm : Algorithm, iterations : Int32)
    seed = 42_u64
    case algorithm
    when Algorithm::XXH32
      iterations.times do
        XXH::XXH32.hash(data, seed.to_u32)
      end
    when Algorithm::XXH64
      iterations.times do
        XXH::XXH64.hash(data, seed)
      end
    when Algorithm::XXH3
      iterations.times do
        XXH::XXH3.hash_with_seed(data, seed)
      end
    when Algorithm::XXH128
      iterations.times do
        XXH::XXH3.hash128_with_seed(data, seed)
      end
    end
  end

  # Single secret hash with seed variation (for time-based loop)
  private def self.run_secret_benchmark_one(data : Bytes, algorithm : Algorithm, seed_u : UInt32) : UInt64
    # Generate a secret buffer (minimum required size for XXH3)
    secret_buffer = Bytes.new(XXH::Constants::XXH3_SECRET_SIZE_MIN) { |i| (((i * 17) ^ seed_u) % 256).to_u8 }

    # Derive a seed from the secret for native fallback
    seed_from_secret = XXH::Primitives.read_u64_le(secret_buffer.to_unsafe)

    case algorithm
    when Algorithm::XXH32
      # XXH32 doesn't support secret, fall back to seeded
      run_seeded_benchmark_one(data, algorithm, seed_u)
    when Algorithm::XXH64
      # XXH64 doesn't support secret, fall back to seeded
      run_seeded_benchmark_one(data, algorithm, seed_u)
    when Algorithm::XXH3
      XXH::XXH3.hash_with_seed(data, seed_from_secret)
    when Algorithm::XXH128
      h = XXH::XXH3.hash128_with_seed(data, seed_from_secret)
      (h.low64 ^ h.high64).to_u64
    else
      0_u64
    end
  end

  # Old: Fixed iteration method (kept for compatibility)
  private def self.run_secret_benchmark(data : Bytes, algorithm : Algorithm, iterations : Int32)
    # Generate a secret buffer (minimum required size for XXH3)
    secret_buffer = Bytes.new(XXH::Constants::XXH3_SECRET_SIZE_MIN) { |i| ((i * 17) % 256).to_u8 }

    # Derive seed from secret for native fallback
    seed_from_secret = XXH::Primitives.read_u64_le(secret_buffer.to_unsafe)

    case algorithm
    when Algorithm::XXH32
      # XXH32 doesn't support secret, fall back to seeded
      run_seeded_benchmark(data, algorithm, iterations)
    when Algorithm::XXH64
      # XXH64 doesn't support secret, fall back to seeded
      run_seeded_benchmark(data, algorithm, iterations)
    when Algorithm::XXH3
      iterations.times do
        XXH::XXH3.hash_with_seed(data, seed_from_secret)
      end
    when Algorithm::XXH128
      iterations.times do
        XXH::XXH3.hash128_with_seed(data, seed_from_secret)
      end
    end
  end

  # Single streaming hash with seed variation (for time-based loop)
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
      state = XXH::XXH3.new_state128(seed_u.to_u64)
      state.update(data)
      h = state.digest
      (h.low64 ^ h.high64).to_u64
    else
      0_u64
    end
  end

  # Old: Fixed iteration method (kept for compatibility)
  private def self.run_streaming_benchmark(data : Bytes, algorithm : Algorithm, iterations : Int32)
    case algorithm
    when Algorithm::XXH32
      iterations.times do
        state = XXH::XXH32::State.new(0_u32)
        state.update(data)
        state.digest
      end
    when Algorithm::XXH64
      iterations.times do
        state = XXH::XXH64::State.new(0_u64)
        state.update(data)
        state.digest
      end
    when Algorithm::XXH3
      iterations.times do
        state = XXH::XXH3.new_state(0_u64)
        state.update(data)
        state.digest
      end
    when Algorithm::XXH128
      iterations.times do
        state = XXH::XXH3.new_state128(0_u64)
        state.update(data)
        state.digest
      end
    end
  end

  # Helper to convert UInt32 to bytes with endianness
  private def self.endianness_to_bytes(value : UInt32, is_le : Bool) : Bytes
    Slice.new(4) do |i|
      if is_le
        ((value >> (i * 8)) & 0xFF_u32).to_u8
      else
        ((value >> ((3 - i) * 8)) & 0xFF_u32).to_u8
      end
    end
  end

  # Helper to convert UInt64 to bytes with endianness
  private def self.endianness_to_bytes(value : UInt64, is_le : Bool) : Bytes
    Slice.new(8) do |i|
      if is_le
        ((value >> (i * 8)) & 0xFF_u64).to_u8
      else
        ((value >> ((7 - i) * 8)) & 0xFF_u64).to_u8
      end
    end
  end
end

# Run CLI
XXH::CLI.run
