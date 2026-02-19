require "../../../src/xxh"

module XXHSum
  module CLI
    module Checker
      # Helper to reverse hex bytes for LE comparison
      private def self.reverse_hex_bytes(hex : String) : String
        hex.chars.each_slice(2).map { |slice| slice.join }.to_a.reverse.join
      end

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

            # --warn: print a warning (to stderr) but continue
            if options.warn && !options.status_only
              err_io.puts "stdin: Error: Improperly formatted checksum line."
            end

            # --strict: treat malformed lines as fatal
            if options.strict
              unless options.status_only
                err_io.puts "stdin: Error: Improperly formatted checksum line."
              end
              exit_code = 1
            end

            next
          end

          hash_str, filename, algo_str, is_le = parsed

          # Check if file exists
          unless File.exists?(filename)
            total_missing += 1
            unless options.ignore_missing
              unless options.status_only
                out_io.puts "stdin:1: Could not open or read '#{filename}': No such file or directory."
              end
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
            computed_hash = compute_hash(filename, algo, options.seed, options.simd_mode)
            # If file format is LE, reverse the computed hash for comparison
            hash_to_compare = is_le ? reverse_hex_bytes(computed_hash) : computed_hash

            if hash_to_compare.downcase == hash_str.downcase
              unless options.quiet || options.status_only
                out_io.puts "#{filename}: OK"
              end
              total_checked += 1
            else
              unless options.status_only
                out_io.puts "#{filename}: FAILED"
              end
              total_failed += 1
              exit_code = 1
              total_checked += 1
            end
          rescue ex : Exception
            unless options.status_only
              out_io.puts "#{filename}: FAILED"
            end
            total_failed += 1
            exit_code = 1
            total_checked += 1
          end
        end

        # Summary - output to stdout (vendor parity)
        unless options.status_only
          if total_missing > 0 && total_failed > 0
            # Mixed missing and mismatched
            verb = total_failed == 1 ? "checksum" : "checksums"
            out_io.puts "#{total_failed} computed #{verb} did NOT match"
          elsif total_missing > 0
            # Only missing files
            count_str = total_missing == 1 ? "file" : "files"
            out_io.puts "#{total_missing} listed #{count_str} could not be read"
          elsif total_failed > 0
            # Only mismatched hashes
            verb = total_failed == 1 ? "checksum" : "checksums"
            out_io.puts "#{total_failed} computed #{verb} did NOT match"
          end
        end

        # Vendor parity: when --ignore-missing is used and no files were verified
        # from stdin, print a short message and fail.
        if options.ignore_missing && total_checked == 0 && !options.status_only
          out_io.puts "stdin: no file was verified"
          exit_code = 1
        end

        exit_code
      end

      # Entry point for verification mode
      def self.verify(checksum_files : Array(String), options : Options, out_io : IO = STDOUT, err_io : IO = STDERR) : Int32
        exit_code = 0
        total_checked = 0
        total_failed = 0 # Count of hash mismatches
        total_missing = 0
        total_bad_format = 0
        total_properly_formatted = 0

        checksum_files.each do |checksum_file|
          begin
            matched_in_file = 0
            line_index = 0
            had_bad_format = false

            File.each_line(checksum_file) do |line|
              line_index += 1
              # Skip empty lines and comments
              line = line.strip
              next if line.empty? || line.starts_with?("#")

              parsed = parse_line(line)

              unless parsed
                total_bad_format += 1
                had_bad_format = true

                # Per-line warning when --warn is used (vendor parity)
                if options.warn && !options.status_only
                  err_io.puts "#{checksum_file}:#{line_index}: Error: Improperly formatted checksum line."
                end

                next
              end

              total_properly_formatted += 1

              hash_str, filename, algo_str, is_le = parsed

              # Check if file exists
              unless File.exists?(filename)
                total_missing += 1
                unless options.ignore_missing
                  unless options.status_only
                    out_io.puts "#{checksum_file}:#{line_index}: Could not open or read '#{filename}': No such file or directory."
                  end
                  exit_code = 1
                end
                next
              end

              # Determine algorithm from line (prefer algo_str from BSD format)
              algo = algo_str ? parse_algorithm(algo_str) : options.algorithm

              begin
                # Compute hash of the file
                computed_hash = compute_hash(filename, algo, options.seed, options.simd_mode)
                # If file format is LE, reverse the computed hash for comparison
                hash_to_compare = is_le ? reverse_hex_bytes(computed_hash) : computed_hash

                if hash_to_compare.downcase == hash_str.downcase
                  unless options.quiet || options.status_only
                    out_io.puts "#{filename}: OK"
                  end
                  total_checked += 1
                  matched_in_file += 1
                else
                  unless options.status_only
                    out_io.puts "#{filename}: FAILED"
                  end
                  total_failed += 1
                  exit_code = 1
                  total_checked += 1
                end
              rescue ex : Exception
                unless options.status_only
                  out_io.puts "#{filename}: FAILED"
                end
                total_failed += 1
                exit_code = 1
                total_checked += 1
              end
            end

            # When no properly formatted lines were found, mirror vendor behavior:
            # always treat as an error (exit code 1) but only print the message
            # when not in status-only mode.
            if total_properly_formatted == 0
              unless options.status_only
                err_io.puts "#{checksum_file}: no properly formatted xxHash checksum lines found"
              end
              exit_code = 1
            end

            # If --ignore-missing is enabled but no file from this checksum file was verified,
            # mirror vendor behavior and treat it as an error.
            if options.ignore_missing && matched_in_file == 0 && !options.status_only
              out_io.puts "#{checksum_file}: no file was verified"
              exit_code = 1
            end
          rescue ex : Exception
            out_io.puts "xxhsum: #{checksum_file}: #{ex.message}"
            exit_code = 1
          end
        end

        # Summary - output to stdout (vendor parity)
        # Don't output summary when using --ignore-missing or --status (vendor behavior)
        unless options.ignore_missing || options.status_only
          if total_missing > 0
            count_str = total_missing == 1 ? "file" : "files"
            out_io.puts "#{total_missing} listed #{count_str} could not be read"
          elsif total_failed > 0
            verb = total_failed == 1 ? "checksum" : "checksums"
            out_io.puts "#{total_failed} computed #{verb} did NOT match"
          end
        end

        exit_code
      end

      # Parse a line in GNU or BSD format
      # GNU: "hash  filename" or "XXH32_[LE_]hash  filename"
      # BSD: "algo (filename) = hash"
      # LE format: algo_name ends with _LE, and hex bytes are little-endian
      # Returns {hash, filename, algo_name, is_little_endian} or nil if unparseable
      private def self.parse_line(line : String) : {String, String, String?, Bool}?
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

            # Check for _LE suffix in algo name
            is_le = algo.ends_with?("_LE")
            algo_clean = is_le ? algo[0...-3] : algo

            return {hash_part, filename, algo_clean, is_le}
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
          is_le = false
          hash_to_use = if hash_part.starts_with?("XXH3_LE_")
                          is_le = true
                          algo = "XXH3"
                          hash_part[8..-1]
                        elsif hash_part.starts_with?("XXH3_")
                          algo = "XXH3"
                          hash_part[5..-1]
                        elsif hash_part.starts_with?("XXH32_LE_")
                          is_le = true
                          algo = "XXH32"
                          hash_part[9..-1]
                        elsif hash_part.starts_with?("XXH32_")
                          algo = "XXH32"
                          hash_part[6..-1]
                        elsif hash_part.starts_with?("XXH128_LE_")
                          is_le = true
                          algo = "XXH128"
                          hash_part[10..-1]
                        elsif hash_part.starts_with?("XXH128_")
                          algo = "XXH128"
                          hash_part[7..-1]
                        elsif hash_part.starts_with?("XXH64_LE_")
                          is_le = true
                          algo = "XXH64"
                          hash_part[9..-1]
                        elsif hash_part.starts_with?("XXH64_")
                          algo = "XXH64"
                          hash_part[6..-1]
                        else
                          hash_part
                        end

          return {hash_to_use, filename, algo, is_le}
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
      private def self.compute_hash(path : String, algorithm : CLI::Algorithm, seed : UInt64?, simd_mode : String?) : String
        case algorithm
        when CLI::Algorithm::XXH32
          val = seed ? XXH::XXH32.hash_file(path, seed.to_u32) : XXH::XXH32.hash_file(path)
          val.to_s(16).rjust(8, '0')
        when CLI::Algorithm::XXH64
          val = seed ? XXH::XXH64.hash_file(path, seed) : XXH::XXH64.hash_file(path)
          val.to_s(16).rjust(16, '0')
        when CLI::Algorithm::XXH128
          val = Hasher.hash_path(path, algorithm, seed, simd_mode)
          val
        when CLI::Algorithm::XXH3_64
          val = Hasher.hash_path(path, algorithm, seed, simd_mode)
          val
        else
          raise "Unknown algorithm"
        end
      end
    end
  end
end
