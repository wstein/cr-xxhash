require "./options"
require "./hasher"
require "./formatter"

module XXH::CLI
  # Main CLI entry point
  def self.run(argv = ARGV)
    parser = Parser.new(argv)
    unless parser.parse
      STDERR.puts "Wrong parameters"
      puts parser.options
      exit 1
    end

    options = parser.options

    # Determine files to process
    files = options.files

    # Handle stdin case
    if files.empty? || (files.size == 1 && files[0] == "-")
      if options.explicit_stdin? || !STDIN.tty?
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
      result = results.find { |res| res.filename == filename }
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

    stats = collect_checksum_stats(filepath, algo_bitmask, options)

    print_checksum_summary(filepath, stats, options)

    ok = checksum_ok_from_stats?(stats, options)

    if options.ignore_missing? && stats[:matched] == 0
      unless options.status?
        puts "#{filepath}: no file was verified"
      end
      return false
    end

    ok
  end

  private def self.compare_hashes(actual : HashResult, algorithm : Algorithm, expected_hash : Bytes, is_le : Bool) : Bool
    case algorithm
    when Algorithm::XXH32
      if h = actual.hash32
        hash_bytes = is_le ? h.to_le.bytes : h.to_be.bytes
        return hash_bytes == expected_hash
      end
    when Algorithm::XXH64, Algorithm::XXH3
      if h = actual.hash64
        hash_bytes = is_le ? h.to_le.bytes : h.to_be.bytes
        return hash_bytes == expected_hash
      end
    when Algorithm::XXH128
      if h = actual.hash128
        hash_bytes = if is_le
                       h[0].to_le.bytes + h[1].to_le.bytes
                     else
                       h[0].to_be.bytes + h[1].to_be.bytes
                     end
        return hash_bytes == expected_hash
      end
    end
    false
  end

  private def self.process_parsed_checksum_line(parsed, filepath : String, line_number : Int32, options : Options) : Symbol
    filename = parsed[:filename]
    algorithm = parsed[:algorithm]
    expected_hash = parsed[:hash]
    is_le = parsed[:is_le]

    # Resolve actual hash (stdin or file)
    actual = if filename == "stdin"
               FileHasher.hash_stdin(algorithm, options.simd_mode)
             else
               unless File.exists?(filename)
                 return :open_failure unless options.ignore_missing?
                 return :none
               end
               FileHasher.hash_file(filename, algorithm, options.simd_mode)
             end

    return :none unless actual.success?

    hash_ok = compare_hashes(actual, algorithm, expected_hash, is_le)
    if hash_ok
      unless options.quiet? || options.status?
        puts "#{filename}: OK"
      end
      :matched
    else
      puts "#{filename}: FAILED"
      :mismatched
    end
  end

  private def self.collect_checksum_stats(filepath : String, algo_bitmask : Int32, options : Options)
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
        if options.warn?
          STDERR.puts "#{filepath}:#{line_number}: Error: Improperly formatted checksum line"
        end
        next
      end

      properly_formatted += 1

      case process_parsed_checksum_line(parsed, filepath, line_number, options)
      when :matched
        matched += 1
      when :mismatched
        mismatched += 1
      when :open_failure
        open_failures += 1
      end
    end

    {properly_formatted: properly_formatted, improperly_formatted: improperly_formatted, matched: matched, mismatched: mismatched, open_failures: open_failures}
  end

  private def self.print_checksum_summary(filepath : String, stats, options : Options)
    properly_formatted = stats[:properly_formatted]
    improperly_formatted = stats[:improperly_formatted]
    mismatched = stats[:mismatched]
    open_failures = stats[:open_failures]

    unless options.status?
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
  end

  private def self.checksum_ok_from_stats?(stats, options : Options) : Bool
    properly_formatted = stats[:properly_formatted]
    improperly_formatted = stats[:improperly_formatted]
    mismatched = stats[:mismatched]
    open_failures = stats[:open_failures]

    (properly_formatted > 0) && (mismatched == 0) && (open_failures == 0) && (!options.strict? || improperly_formatted == 0)
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

  private def self.run_benchmark_mode(options : Options)
    sample_size = options.sample_size
    iterations = options.iterations

    # Generate random sample data
    data = Random.new_bytes(sample_size)

    puts "Benchmark: #{sample_size} bytes, #{iterations} iterations"

    # Benchmark selected algorithms
    algorithms = if options.benchmark_all?
                   [Algorithm::XXH32, Algorithm::XXH64, Algorithm::XXH3, Algorithm::XXH128]
                 else
                   [options.algorithm]
                 end

    algorithms.each do |algo|
      run_single_benchmark(data, algo, iterations)
    end
  end

  private def self.run_single_benchmark(data : Bytes, algorithm : Algorithm, iterations : Int32)
    start_time = Time.instant

    case algorithm
    when Algorithm::XXH32
      iterations.times do
        XXH.XXH32(data, 0_u32)
      end
    when Algorithm::XXH64
      iterations.times do
        XXH::XXH64.hash(data, 0_u64)
      end
    when Algorithm::XXH3
      iterations.times do
        XXH.XXH3_64bits(data.to_unsafe, data.size)
      end
    when Algorithm::XXH128
      iterations.times do
        XXH.XXH3_128bits(data.to_unsafe, data.size)
      end
    end

    elapsed = Time.instant - start_time
    total_bytes = data.size * iterations
    throughput = total_bytes / elapsed.total_seconds

    algo_name = Formatter::ALGO_NAMES[algorithm]
    puts "#{algo_name}: #{(throughput / 1_000_000_000).round(2)} GB/s"
  end
end

# Run CLI
XXH::CLI.run
