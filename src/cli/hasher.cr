require "../common/common"
require "../common/primitives"
require "../dispatch"
require "../xxh32/xxh32"
require "../xxh64/xxh64"
require "../xxh3/xxh3"
require "file"
require "channel"

module XXH::CLI
  # Result of a file hash operation
  struct HashResult
    property filename : String
    property hash32 : UInt32?
    property hash64 : UInt64?
    property hash128 : Tuple(UInt64, UInt64)?
    property success : Bool
    property error : String?

    def initialize(@filename, @success = true, @error = nil)
    end
  end

  # Stream-based file hasher using native Crystal implementations
  # Uses fibers for parallel processing of multiple files
  module FileHasher
    DEFAULT_BLOCK_SIZE = 64 * 1024 # 64 KB blocks

    # Hash a single file using streaming API
    def self.hash_file(path : String, algorithm : Algorithm, simd_mode : SIMDMode = SIMDMode::Auto, block_size : Int32 = DEFAULT_BLOCK_SIZE) : HashResult
      result = HashResult.new(path)

      # Check if stdin
      if path == "-" || path == "stdin"
        stdin_result = hash_stdin(algorithm, simd_mode, block_size)
        # Preserve the original path ("-" or "stdin") for consistent lookup
        stdin_result.filename = path
        return stdin_result
      end

      # Check if file exists
      unless File.exists?(path)
        return HashResult.new(path, false, "File not found")
      end

      # Check if directory
      if File.info?(path).try(&.directory?)
        return HashResult.new(path, false, "Is a directory")
      end

      begin
        case algorithm
        when Algorithm::XXH32
          result.hash32 = hash_file_xxh32(path, simd_mode, block_size)
        when Algorithm::XXH64
          result.hash64 = hash_file_xxh64(path, simd_mode, block_size)
        when Algorithm::XXH128
          result.hash128 = hash_file_xxh128(path, simd_mode, block_size)
        when Algorithm::XXH3
          result.hash64 = hash_file_xxh3(path, simd_mode, block_size)
        end
        result.success = true
      rescue ex
        result.success = false
        result.error = ex.message
      end

      result
    end

    # Hash stdin using streaming API
    def self.hash_stdin(algorithm : Algorithm, simd_mode : SIMDMode = SIMDMode::Auto, block_size : Int32 = DEFAULT_BLOCK_SIZE) : HashResult
      result = HashResult.new("stdin")

      begin
        case algorithm
        when Algorithm::XXH32
          result.hash32 = hash_io_xxh32(STDIN, simd_mode, block_size)
        when Algorithm::XXH64
          result.hash64 = hash_io_xxh64(STDIN, simd_mode, block_size)
        when Algorithm::XXH128
          result.hash128 = hash_io_xxh128(STDIN, simd_mode, block_size)
        when Algorithm::XXH3
          result.hash64 = hash_io_xxh3(STDIN, simd_mode, block_size)
        end
        result.success = true
      rescue ex
        result.success = false
        result.error = ex.message
      end

      result
    end

    # Hash multiple files in parallel using fibers
    def self.hash_files_parallel(paths : Array(String), algorithm : Algorithm, simd_mode : SIMDMode = SIMDMode::Auto, block_size : Int32 = DEFAULT_BLOCK_SIZE) : Array(HashResult)
      results = Array(HashResult).new(paths.size)
      channel = Channel(HashResult).new(paths.size)

      paths.each do |path|
        spawn do
          channel.send(hash_file(path, algorithm, simd_mode, block_size))
        end
      end

      paths.size.times do
        results << channel.receive
      end

      results
    end

    # Stream hashing implementations using native Crystal code
    # NOTE: Currently only scalar implementations exist (simd_mode is for future SIMD variants)
    # simd_mode values: Auto (default), Scalar, SSE2, AVX2, NEON
    # TODO: Wire actual SIMD dispatch once SIMD implementations are available
    private def self.hash_file_xxh32(path : String, simd_mode : SIMDMode, block_size : Int32) : UInt32
      # Read entire file and hash it
      # TODO: Implement true streaming for very large files
      data = File.read(path).to_slice

      # For now, all modes use the native scalar implementation
      case simd_mode
      when SIMDMode::Auto, SIMDMode::Scalar, SIMDMode::SSE2, SIMDMode::AVX2, SIMDMode::NEON
        XXH::XXH32.hash(data, 0_u32)
      else
        XXH::XXH32.hash(data, 0_u32)
      end
    end

    private def self.hash_file_xxh64(path : String, simd_mode : SIMDMode, block_size : Int32) : UInt64
      data = File.read(path).to_slice

      # SIMD dispatch (currently all use scalar implementation)
      case simd_mode
      when SIMDMode::Auto, SIMDMode::Scalar, SIMDMode::SSE2, SIMDMode::AVX2, SIMDMode::NEON
        XXH::XXH64.hash(data, 0_u64)
      else
        XXH::XXH64.hash(data, 0_u64)
      end
    end

    private def self.hash_file_xxh128(path : String, simd_mode : SIMDMode, block_size : Int32) : Tuple(UInt64, UInt64)
      data = File.read(path).to_slice
      result = XXH::Dispatch.hash_xxh128(data, 0_u64)
      {result[0], result[1]}
    end

    private def self.hash_file_xxh3(path : String, simd_mode : SIMDMode, block_size : Int32) : UInt64
      data = File.read(path).to_slice

      # SIMD dispatch (currently all use scalar implementation)
      case simd_mode
      when SIMDMode::Auto, SIMDMode::Scalar, SIMDMode::SSE2, SIMDMode::AVX2, SIMDMode::NEON
        XXH::XXH3.hash(data)
      else
        XXH::XXH3.hash(data)
      end
    end

    # IO-based hashing for stdin
    private def self.hash_io_xxh32(io : IO, simd_mode : SIMDMode, block_size : Int32) : UInt32
      # Read from IO into memory then hash
      data = io.gets_to_end.to_slice
      XXH::XXH32.hash(data, 0_u32)
    end

    private def self.hash_io_xxh64(io : IO, simd_mode : SIMDMode, block_size : Int32) : UInt64
      data = io.gets_to_end.to_slice
      XXH::XXH64.hash(data, 0_u64)
    end

    private def self.hash_io_xxh128(io : IO, simd_mode : SIMDMode, block_size : Int32) : Tuple(UInt64, UInt64)
      data = io.gets_to_end.to_slice
      result = XXH::Dispatch.hash_xxh128(data, 0_u64)
      {result[0], result[1]}
    end

    private def self.hash_io_xxh3(io : IO, simd_mode : SIMDMode, block_size : Int32) : UInt64
      data = io.gets_to_end.to_slice
      XXH::XXH3.hash(data)
    end

    # One-shot hashing (for small files)
    def self.hash_bytes(data : Bytes, algorithm : Algorithm) : HashResult
      result = HashResult.new("")

      case algorithm
      when Algorithm::XXH32
        result.hash32 = XXH::XXH32.hash(data, 0_u32)
      when Algorithm::XXH64
        result.hash64 = XXH::XXH64.hash(data, 0_u64)
      when Algorithm::XXH128
        res = XXH::Dispatch.hash_xxh128(data, 0_u64)
        result.hash128 = {res[0], res[1]}
      when Algorithm::XXH3
        result.hash64 = XXH::XXH3.hash(data)
      end

      result.success = true
      result
    end
  end
end
