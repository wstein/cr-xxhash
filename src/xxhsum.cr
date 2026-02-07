# xxHash Crystal CLI - xxhsum
#
# Command-line interface for xxHash algorithm family.

require "./ffi/bindings"
require "./cli/options"
require "./cli/hasher"
require "./cli/formatter"

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
    results = FileHasher.hash_files_parallel(files, options.algorithm)

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
        actual = FileHasher.hash_stdin(algorithm)
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

        actual = FileHasher.hash_file(filename, algorithm)
      end

      next unless actual.success

      # Compare hashes
      hash_ok = false
      case algorithm
      when Algorithm::XXH32
        if (h32 = actual.hash32)
          hash_bytes = endianness_to_bytes(h32, is_le)
          hash_ok = hash_bytes == expected_hash
        end
      when Algorithm::XXH64, Algorithm::XXH3
        if (h64 = actual.hash64)
          hash_bytes = endianness_to_bytes(h64, is_le)
          hash_ok = hash_bytes == expected_hash
        end
      when Algorithm::XXH128
        if (h128 = actual.hash128)
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

          result = FileHasher.hash_file(filename, options.algorithm)
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
      puts "xxhsum 0.8.3 by Yann Collet"
    end

    puts "Sample of #{sample_size / 1024} KB..."

    # Build list of all available benchmark variants
    all_variants = build_benchmark_variants

    # Filter variants to run based on options
    variants_to_run = if !options.benchmark_variants.empty?
                        # User specified specific variants with -b1,3,5
                        options.benchmark_variants.map do |id|
                          all_variants.find { |v| v.id == id }
                        end.compact
                      elsif options.benchmark_id > 0
                        # User specified a single benchmark ID with -b1
                        variant = all_variants.find { |v| v.id == options.benchmark_id }
                        variant ? [variant] : ([] of BenchmarkVariant)
                      else
                        # No specific variants requested, run all (default behavior)
                        all_variants
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

  private def self.run_single_benchmark(aligned_data : Bytes, unaligned_data : Bytes, variant : BenchmarkVariant, user_iterations : Int32 = 0)
    # Select data based on alignment
    data = variant.aligned ? aligned_data : unaligned_data

    # Auto-tune iterations to hit ~1 second target
    iterations = if user_iterations > 0
                   user_iterations
                 else
                   auto_tune_iterations(data, variant)
                 end

    # Run the actual benchmark
    start_time = Time.instant
    run_benchmark_iterations(data, variant, iterations)
    elapsed = Time.instant - start_time
    elapsed_seconds = elapsed.total_seconds

    # Calculate throughput
    iterations_per_sec = iterations.to_f / elapsed_seconds
    total_bytes = data.size.to_f * iterations
    throughput_mb = (total_bytes / (1024 * 1024)) / elapsed_seconds

    # Format output with live progress (no \r for simplicity in final output, but ready for future enhancement)
    printf("%2d#%-30s: %10d -> %8.0f it/s (%7.1f MB/s)\n",
      variant.id, variant.name, data.size, iterations_per_sec, throughput_mb)
  end

  private def self.auto_tune_iterations(data : Bytes, variant : BenchmarkVariant) : Int32
    target_duration = 1.0 # 1 second target
    iterations = 1
    max_iterations = 10000

    # Quick warmup run
    run_benchmark_iterations(data, variant, 1)

    # Measure how long one iteration takes
    start_time = Time.instant
    run_benchmark_iterations(data, variant, 1)
    elapsed = Time.instant - start_time
    elapsed_seconds = elapsed.total_seconds

    # Calculate iterations needed to hit target
    if elapsed_seconds > 0
      iterations = (target_duration / elapsed_seconds).to_i32.clamp(1, max_iterations)
    else
      # Too fast, do more iterations
      iterations = (max_iterations / 10).to_i32
    end

    iterations
  end

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

  private def self.run_basic_benchmark(data : Bytes, algorithm : Algorithm, iterations : Int32)
    case algorithm
    when Algorithm::XXH32
      iterations.times do
        LibXXH.XXH32(data.to_unsafe, data.size, 0_u32)
      end
    when Algorithm::XXH64
      iterations.times do
        LibXXH.XXH64(data.to_unsafe, data.size, 0_u64)
      end
    when Algorithm::XXH3
      iterations.times do
        LibXXH.XXH3_64bits(data.to_unsafe, data.size)
      end
    when Algorithm::XXH128
      iterations.times do
        LibXXH.XXH3_128bits(data.to_unsafe, data.size)
      end
    end
  end

  private def self.run_seeded_benchmark(data : Bytes, algorithm : Algorithm, iterations : Int32)
    seed = 42_u64
    case algorithm
    when Algorithm::XXH32
      iterations.times do
        LibXXH.XXH32(data.to_unsafe, data.size, seed.to_u32)
      end
    when Algorithm::XXH64
      iterations.times do
        LibXXH.XXH64(data.to_unsafe, data.size, seed)
      end
    when Algorithm::XXH3
      iterations.times do
        LibXXH.XXH3_64bits_withSeed(data.to_unsafe, data.size, seed)
      end
    when Algorithm::XXH128
      iterations.times do
        LibXXH.XXH3_128bits_withSeed(data.to_unsafe, data.size, seed)
      end
    end
  end

  private def self.run_secret_benchmark(data : Bytes, algorithm : Algorithm, iterations : Int32)
    # Generate a secret buffer (minimum required size for XXH3)
    secret_buffer = Bytes.new(136) { |i| ((i * 17) % 256).to_u8 }

    case algorithm
    when Algorithm::XXH32
      # XXH32 doesn't support secret, fall back to seeded
      run_seeded_benchmark(data, algorithm, iterations)
    when Algorithm::XXH64
      # XXH64 doesn't support secret, fall back to seeded
      run_seeded_benchmark(data, algorithm, iterations)
    when Algorithm::XXH3
      iterations.times do
        LibXXH.XXH3_64bits_withSecret(data.to_unsafe, data.size, secret_buffer.to_unsafe, secret_buffer.size)
      end
    when Algorithm::XXH128
      iterations.times do
        LibXXH.XXH3_128bits_withSecret(data.to_unsafe, data.size, secret_buffer.to_unsafe, secret_buffer.size)
      end
    end
  end

  private def self.run_streaming_benchmark(data : Bytes, algorithm : Algorithm, iterations : Int32)
    case algorithm
    when Algorithm::XXH32
      iterations.times do
        state = LibXXH.XXH32_createState
        if state
          LibXXH.XXH32_reset(state, 0_u32)
          LibXXH.XXH32_update(state, data.to_unsafe, data.size)
          LibXXH.XXH32_digest(state)
          LibXXH.XXH32_freeState(state)
        end
      end
    when Algorithm::XXH64
      iterations.times do
        state = LibXXH.XXH64_createState
        if state
          LibXXH.XXH64_reset(state, 0_u64)
          LibXXH.XXH64_update(state, data.to_unsafe, data.size)
          LibXXH.XXH64_digest(state)
          LibXXH.XXH64_freeState(state)
        end
      end
    when Algorithm::XXH3
      iterations.times do
        state = LibXXH.XXH3_createState
        if state
          LibXXH.XXH3_64bits_reset(state)
          LibXXH.XXH3_64bits_update(state, data.to_unsafe, data.size)
          LibXXH.XXH3_64bits_digest(state)
          LibXXH.XXH3_freeState(state)
        end
      end
    when Algorithm::XXH128
      iterations.times do
        state = LibXXH.XXH3_createState
        if state
          LibXXH.XXH3_128bits_reset(state)
          LibXXH.XXH3_128bits_update(state, data.to_unsafe, data.size)
          LibXXH.XXH3_128bits_digest(state)
          LibXXH.XXH3_freeState(state)
        end
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
