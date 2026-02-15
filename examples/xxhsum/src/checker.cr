require "cr-xxhash/src/xxh"

module XXHSum
  module CLI
    module Checker
      # Entry point for verifying from stdin
      def self.verify_stdin(options : Options, stdin : IO = STDIN, out_io : IO = STDOUT, err_io : IO = STDERR) : Int32
        exit_code = 0
        total_checked = 0
        total_failed = 0
        total_missing = 0
        total_bad_format = 0

        stdin.each_line do |line|
          # Skip empty lines and comments
          line = line.strip
          next if line.empty? || line.starts_with?("#")

          parsed = parse_line(line)

          unless parsed
            total_bad_format += 1
            if options.strict
              err_io.puts "xxhsum: stdin: improperly formatted line: #{line}"
              exit_code = 2
            end
            next
          end

          hash_str, filename, algo_str = parsed

          # Check if file exists
          unless File.exists?(filename)
            total_missing += 1
            unless options.ignore_missing
              err_io.puts "xxhsum: #{filename}: No such file or directory"
              total_failed += 1
              exit_code = 1
            end
            next
          end

          # Determine algorithm from line
          # Priority: algo_str > inferred from hash length > options.algorithm
          algo = if algo_str
                   parse_algorithm(algo_str)
                 else
                   inferred = infer_algorithm_from_hash(hash_str)
                   inferred || options.algorithm
                 end

          begin
            # Compute hash of the file
            computed_hash = compute_hash(filename, algo, options.seed)

            if computed_hash.downcase == hash_str.downcase
              unless options.quiet
                out_io.puts "#{filename}: OK"
              end
              total_checked += 1
            else
              err_io.puts "#{filename}: FAILED"
              total_failed += 1
              exit_code = 1
              total_checked += 1
            end
          rescue ex : Exception
            err_io.puts "xxhsum: #{filename}: #{ex.message}"
            total_failed += 1
            exit_code = 1
            total_checked += 1
          end
        end

        # Summary (quiet only suppresses per-file OK lines)
        if total_failed > 0
          err_io.puts "xxhsum: WARNING: #{total_failed} computed checksums did NOT match"
        end

        # Vendor parity: when --ignore-missing is used and no files were verified
        # from stdin, print a short message and fail.
        if options.ignore_missing && total_checked == 0
          out_io.puts "stdin: no file was verified"
          exit_code = 1
        end

        exit_code
      end

      # Entry point for verification mode
      def self.verify(checksum_files : Array(String), options : Options, out_io : IO = STDOUT, err_io : IO = STDERR) : Int32
        exit_code = 0
        total_checked = 0
        total_failed = 0
        total_missing = 0
        total_bad_format = 0

        checksum_files.each do |checksum_file|
          begin
            matched_in_file = 0

            File.each_line(checksum_file) do |line|
              # Skip empty lines and comments
              line = line.strip
              next if line.empty? || line.starts_with?("#")

              parsed = parse_line(line)

              unless parsed
                total_bad_format += 1
                if options.strict
                  err_io.puts "xxhsum: #{checksum_file}: improperly formatted line: #{line}"
                  exit_code = 2
                end
                next
              end

              hash_str, filename, algo_str = parsed

              # Check if file exists
              unless File.exists?(filename)
                total_missing += 1
                unless options.ignore_missing
                  err_io.puts "xxhsum: #{filename}: No such file or directory"
                  total_failed += 1
                  exit_code = 1
                end
                next
              end

              # Determine algorithm from line (prefer algo_str from BSD format)
              algo = algo_str ? parse_algorithm(algo_str) : options.algorithm

              begin
                # Compute hash of the file
                computed_hash = compute_hash(filename, algo, options.seed)

                if computed_hash.downcase == hash_str.downcase
                  unless options.quiet
                    out_io.puts "#{filename}: OK"
                  end
                  total_checked += 1
                  matched_in_file += 1
                else
                  err_io.puts "#{filename}: FAILED"
                  total_failed += 1
                  exit_code = 1
                  total_checked += 1
                end
              rescue ex : Exception
                err_io.puts "xxhsum: #{filename}: #{ex.message}"
                total_failed += 1
                exit_code = 1
                total_checked += 1
              end
            end

            # If --ignore-missing is enabled but no file from this checksum file was verified,
            # mirror vendor behavior and treat it as an error.
            if options.ignore_missing && matched_in_file == 0
              out_io.puts "#{checksum_file}: no file was verified"
              exit_code = 1
            end

          rescue ex : Exception
            err_io.puts "xxhsum: #{checksum_file}: #{ex.message}"
            exit_code = 1
          end
        end

        # Summary (quiet only suppresses per-file OK lines)
        if total_failed > 0
          err_io.puts "xxhsum: WARNING: #{total_failed} computed checksums did NOT match"
        end

        exit_code
      end

      # Parse a line in GNU or BSD format
      # GNU: "hash  filename"
      # BSD: "algo (filename) = hash"
      # Returns {hash, filename, algo_name} or nil if unparseable
      private def self.parse_line(line : String) : {String, String, String?}?
        line = line.strip

        # Try BSD format first: "algo (filename) = hash"
        if line.includes?(" (") && line.includes?(") = ")
          parts = line.split(" = ")
          return nil unless parts.size == 2

          hash_part = parts[1].strip
          prefix_part = parts[0]

          # Extract algo and filename from "algo (filename)"
          if prefix_part.ends_with?(")")
            open_paren = prefix_part.rindex('(')
            return nil unless open_paren

            algo = prefix_part[0...open_paren].strip
            filename = prefix_part[(open_paren + 1)...-1].strip

            return {hash_part, filename, algo}
          end
        end

        # Try GNU format: "hash  filename" (two or more spaces)
        if line.includes?("  ")
          parts = line.split("  ", 2)
          return nil unless parts.size == 2

          hash_part = parts[0].strip
          filename = parts[1].strip

          # Detect algorithm prefix and extract hash
          algo = nil
          hash_to_use = if hash_part.starts_with?("XXH3_")
                          algo = "XXH3"
                          hash_part[5..-1]
                        elsif hash_part.starts_with?("XXH32_")
                          algo = "XXH32"
                          hash_part[6..-1]
                        elsif hash_part.starts_with?("XXH128_")
                          algo = "XXH128"
                          hash_part[7..-1]
                        else
                          hash_part
                        end

          return {hash_to_use, filename, algo}
        end

        nil
      end

      # Infer algorithm from hash length
      # 8 hex chars (32-bit) -> XXH32
      # 16 hex chars (64-bit) -> XXH64 or XXH3_64 (ambiguous, return nil)
      # 32 hex chars (128-bit) -> XXH128
      private def self.infer_algorithm_from_hash(hash_str : String) : CLI::Algorithm?
        case hash_str.size
        when 8
          CLI::Algorithm::XXH32
        when 32
          CLI::Algorithm::XXH128
        else
          # 16 chars could be XXH64 or XXH3_64 - ambiguous, let caller decide
          nil
        end
      end

      # Parse algorithm name from BSD format
      private def self.parse_algorithm(algo_name : String) : CLI::Algorithm
        case algo_name.downcase
        when "xxh32"
          CLI::Algorithm::XXH32
        when "xxh64"
          CLI::Algorithm::XXH64
        when "xxh128"
          CLI::Algorithm::XXH128
        when "xxh3"
          CLI::Algorithm::XXH3_64
        else
          CLI::Algorithm::XXH64 # Default fallback
        end
      end

      # Compute hash of a file using the specified algorithm
      private def self.compute_hash(path : String, algorithm : CLI::Algorithm, seed : UInt64?) : String
        case algorithm
        when CLI::Algorithm::XXH32
          val = seed ? XXH::XXH32.hash_file(path, seed.to_u32) : XXH::XXH32.hash_file(path)
          val.to_s(16).rjust(8, '0')
        when CLI::Algorithm::XXH64
          val = seed ? XXH::XXH64.hash_file(path, seed) : XXH::XXH64.hash_file(path)
          val.to_s(16).rjust(16, '0')
        when CLI::Algorithm::XXH128
          val = seed ? XXH::XXH3.hash128_file(path, seed) : XXH::XXH3.hash128_file(path)
          val.to_hex32
        when CLI::Algorithm::XXH3_64
          val = seed ? XXH::XXH3.hash64_file(path, seed) : XXH::XXH3.hash64_file(path)
          val.to_s(16).rjust(16, '0')
        else
          raise "Unknown algorithm"
        end
      end
    end
  end
end
