require "../ffi/bindings"
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

  # Stream-based file hasher using FFI
  # Uses fibers for parallel processing of multiple files
  module FileHasher
    DEFAULT_BLOCK_SIZE = 64 * 1024 # 64 KB blocks

    # Hash a single file using streaming API
    def self.hash_file(path : String, algorithm : Algorithm, block_size : Int32 = DEFAULT_BLOCK_SIZE) : HashResult
      result = HashResult.new(path)

      # Check if stdin
      if path == "-" || path == "stdin"
        stdin_result = hash_stdin(algorithm, block_size)
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
          result.hash32 = hash_file_xxh32(path, block_size)
        when Algorithm::XXH64
          result.hash64 = hash_file_xxh64(path, block_size)
        when Algorithm::XXH128
          result.hash128 = hash_file_xxh128(path, block_size)
        when Algorithm::XXH3
          result.hash64 = hash_file_xxh3(path, block_size)
        end
        result.success = true
      rescue ex
        result.success = false
        result.error = ex.message
      end

      result
    end

    # Hash stdin using streaming API
    def self.hash_stdin(algorithm : Algorithm, block_size : Int32 = DEFAULT_BLOCK_SIZE) : HashResult
      result = HashResult.new("stdin")

      begin
        case algorithm
        when Algorithm::XXH32
          result.hash32 = hash_io_xxh32(STDIN, block_size)
        when Algorithm::XXH64
          result.hash64 = hash_io_xxh64(STDIN, block_size)
        when Algorithm::XXH128
          result.hash128 = hash_io_xxh128(STDIN, block_size)
        when Algorithm::XXH3
          result.hash64 = hash_io_xxh3(STDIN, block_size)
        end
        result.success = true
      rescue ex
        result.success = false
        result.error = ex.message
      end

      result
    end

    # Hash multiple files in parallel using fibers
    def self.hash_files_parallel(paths : Array(String), algorithm : Algorithm, block_size : Int32 = DEFAULT_BLOCK_SIZE) : Array(HashResult)
      results = Array(HashResult).new(paths.size)
      channel = Channel(HashResult).new(paths.size)

      paths.each do |path|
        spawn do
          channel.send(hash_file(path, algorithm, block_size))
        end
      end

      paths.size.times do
        results << channel.receive
      end

      results
    end

    # Stream hashing implementations
    private def self.hash_file_xxh32(path : String, block_size : Int32) : UInt32
      state = LibXXH.XXH32_createState
      raise "Failed to create state" if state.nil?

      LibXXH.XXH32_reset(state, 0_u32)

      buffer = Slice(UInt8).new(block_size)
      File.open(path) do |file|
        loop do
          bytes = file.read(buffer)
          break if bytes == 0
          LibXXH.XXH32_update(state, buffer.to_unsafe, bytes)
        end
      end

      hash = LibXXH.XXH32_digest(state)
      LibXXH.XXH32_freeState(state)
      hash
    end

    private def self.hash_file_xxh64(path : String, block_size : Int32) : UInt64
      state = LibXXH.XXH64_createState
      raise "Failed to create state" if state.nil?

      LibXXH.XXH64_reset(state, 0_u64)

      buffer = Slice(UInt8).new(block_size)
      File.open(path) do |file|
        loop do
          bytes = file.read(buffer)
          break if bytes == 0
          LibXXH.XXH64_update(state, buffer.to_unsafe, bytes)
        end
      end

      hash = LibXXH.XXH64_digest(state)
      LibXXH.XXH64_freeState(state)
      hash
    end

    private def self.hash_file_xxh128(path : String, block_size : Int32) : Tuple(UInt64, UInt64)
      state = LibXXH.XXH3_createState
      raise "Failed to create state" if state.nil?

      LibXXH.XXH3_128bits_reset(state)

      buffer = Slice(UInt8).new(block_size)
      File.open(path) do |file|
        loop do
          bytes = file.read(buffer)
          break if bytes == 0
          LibXXH.XXH3_128bits_update(state, buffer.to_unsafe, bytes)
        end
      end

      hash = LibXXH.XXH3_128bits_digest(state)
      LibXXH.XXH3_freeState(state)
      {hash.low64, hash.high64}
    end

    private def self.hash_file_xxh3(path : String, block_size : Int32) : UInt64
      state = LibXXH.XXH3_createState
      raise "Failed to create state" if state.nil?

      LibXXH.XXH3_64bits_reset(state)

      buffer = Slice(UInt8).new(block_size)
      File.open(path) do |file|
        loop do
          bytes = file.read(buffer)
          break if bytes == 0
          LibXXH.XXH3_64bits_update(state, buffer.to_unsafe, bytes)
        end
      end

      hash = LibXXH.XXH3_64bits_digest(state)
      LibXXH.XXH3_freeState(state)
      hash
    end

    # IO-based hashing for stdin
    private def self.hash_io_xxh32(io : IO, block_size : Int32) : UInt32
      state = LibXXH.XXH32_createState
      raise "Failed to create state" if state.nil?

      LibXXH.XXH32_reset(state, 0_u32)

      buffer = Slice(UInt8).new(block_size)
      loop do
        bytes = io.read(buffer)
        break if bytes == 0
        LibXXH.XXH32_update(state, buffer.to_unsafe, bytes)
      end

      hash = LibXXH.XXH32_digest(state)
      LibXXH.XXH32_freeState(state)
      hash
    end

    private def self.hash_io_xxh64(io : IO, block_size : Int32) : UInt64
      state = LibXXH.XXH64_createState
      raise "Failed to create state" if state.nil?

      LibXXH.XXH64_reset(state, 0_u64)

      buffer = Slice(UInt8).new(block_size)
      loop do
        bytes = io.read(buffer)
        break if bytes == 0
        LibXXH.XXH64_update(state, buffer.to_unsafe, bytes)
      end

      hash = LibXXH.XXH64_digest(state)
      LibXXH.XXH64_freeState(state)
      hash
    end

    private def self.hash_io_xxh128(io : IO, block_size : Int32) : Tuple(UInt64, UInt64)
      state = LibXXH.XXH3_createState
      raise "Failed to create state" if state.nil?

      LibXXH.XXH3_128bits_reset(state)

      buffer = Slice(UInt8).new(block_size)
      loop do
        bytes = io.read(buffer)
        break if bytes == 0
        LibXXH.XXH3_128bits_update(state, buffer.to_unsafe, bytes)
      end

      hash = LibXXH.XXH3_128bits_digest(state)
      LibXXH.XXH3_freeState(state)
      {hash.low64, hash.high64}
    end

    private def self.hash_io_xxh3(io : IO, block_size : Int32) : UInt64
      state = LibXXH.XXH3_createState
      raise "Failed to create state" if state.nil?

      LibXXH.XXH3_64bits_reset(state)

      buffer = Slice(UInt8).new(block_size)
      loop do
        bytes = io.read(buffer)
        break if bytes == 0
        LibXXH.XXH3_64bits_update(state, buffer.to_unsafe, bytes)
      end

      hash = LibXXH.XXH3_64bits_digest(state)
      LibXXH.XXH3_freeState(state)
      hash
    end

    # One-shot hashing (for small files)
    def self.hash_bytes(data : Bytes, algorithm : Algorithm) : HashResult
      result = HashResult.new("")

      case algorithm
      when Algorithm::XXH32
        result.hash32 = LibXXH.XXH32(data.to_unsafe, data.size, 0_u32)
      when Algorithm::XXH64
        result.hash64 = LibXXH.XXH64(data.to_unsafe, data.size, 0_u64)
      when Algorithm::XXH128
        hash = LibXXH.XXH3_128bits(data.to_unsafe, data.size)
        result.hash128 = {hash.low64, hash.high64}
      when Algorithm::XXH3
        result.hash64 = LibXXH.XXH3_64bits(data.to_unsafe, data.size)
      end

      result.success = true
      result
    end
  end
end
