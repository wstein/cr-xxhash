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

  private def self.run_benchmark_mode(options : Options)
    sample_size = options.sample_size

    # Generate random sample data
    data = Random::Secure.random_bytes(sample_size)

    puts "Sample of #{sample_size / 1024} KB..."

    # Benchmark selected algorithms
    algorithms = if options.benchmark_all
                   [Algorithm::XXH32, Algorithm::XXH64, Algorithm::XXH3, Algorithm::XXH128]
                 else
                   [options.algorithm]
                 end

    algorithms.each do |algo|
      run_single_benchmark(data, algo)
    end
  end

  private def self.run_single_benchmark(data : Bytes, algorithm : Algorithm)
    # Determine vendor bench ID and name
    vendor_id, algo_name = case algorithm
                           when Algorithm::XXH32
                             {1, "XXH32"}
                           when Algorithm::XXH64
                             {3, "XXH64"}
                           when Algorithm::XXH3
                             {5, "XXH3_64b"}
                           when Algorithm::XXH128
                             {11, "XXH128"}
                           else
                             {0, "Unknown"}
                           end

    # Time a warm-up run
    start_time = Time.instant
    iterations = 0
    target_duration = 1.0 # Target 1 second

    case algorithm
    when Algorithm::XXH32
      while Time.instant - start_time < target_duration.seconds
        LibXXH.XXH32(data.to_unsafe, data.size, 0_u32)
        iterations += 1
      end
    when Algorithm::XXH64
      while Time.instant - start_time < target_duration.seconds
        LibXXH.XXH64(data.to_unsafe, data.size, 0_u64)
        iterations += 1
      end
    when Algorithm::XXH3
      while Time.instant - start_time < target_duration.seconds
        LibXXH.XXH3_64bits(data.to_unsafe, data.size)
        iterations += 1
      end
    when Algorithm::XXH128
      while Time.instant - start_time < target_duration.seconds
        LibXXH.XXH3_128bits(data.to_unsafe, data.size)
        iterations += 1
      end
    end

    elapsed = Time.instant - start_time
    elapsed_seconds = elapsed.total_seconds

    # Calculate throughput
    iterations_per_sec = iterations.to_f / elapsed_seconds
    total_bytes = data.size.to_f * iterations
    throughput_mb = (total_bytes / (1024 * 1024)) / elapsed_seconds

    # Format output like vendor: "1#XXH32                         :     102400 ->   133425 it/s (13029.8 MB/s)"
    printf("%2d#%-30s: %10d -> %8.0f it/s (%7.1f MB/s)\n",
      vendor_id, algo_name, data.size, iterations_per_sec, throughput_mb)
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
