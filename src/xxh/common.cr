# Minimal common shim after native removal
# Keeps constants and a tiny Buffers API used by higher-level code.

module XXH
  module Constants
    PRIME32_1 = 0x9E3779B1_u32
    PRIME32_2 = 0x85EBCA77_u32
    PRIME32_3 = 0xC2B2AE3D_u32
    PRIME32_4 = 0x27D4EB2F_u32
    PRIME32_5 = 0x165667B1_u32

    PRIME64_1 = 0x9E3779B185EBCA87_u64
    PRIME64_2 = 0xC2B2AE3D27D4EB4F_u64
    PRIME64_3 = 0x165667B19E3779F9_u64
    PRIME64_4 = 0x85EBCA77C2B2AE63_u64
    PRIME64_5 = 0x27D4EB2F165667C5_u64

    PRIME_MIX           = 0x165667B19E3779F9_u64
    SECRET_DEFAULT_SIZE =                    192
    STRIPE_LEN          =                     64
    BLOCK_LEN           =                   1024
    ACC_NB              =                      8

    XXHASH32_BUFFER_SIZE =  16
    XXHASH64_BUFFER_SIZE =  32
    XXHASH3_BUFFER_SIZE  = 256
  end

  module Buffers
    @@scratch_buffer : Bytes? = nil
    @@stripe_buffer : Bytes? = nil
    @@default_secret : Bytes? = nil

    def self.scratch_buffer : Bytes
      @@scratch_buffer ||= Bytes.new(256)
    end

    def self.stripe_buffer : Bytes
      @@stripe_buffer ||= Bytes.new(64)
    end

    def self.default_secret : Bytes
      @@default_secret ||= Bytes.new(Constants::SECRET_DEFAULT_SIZE)
    end

    def self.aligned_alloc(size : Int32, _alignment : Int32 = 64) : Pointer(Void)
      LibC.malloc(size.to_size)
    end

    def self.aligned_free(ptr : Pointer(Void))
      LibC.free(ptr)
    end
  end

  module ThreadLocal
    def self.worker_accumulators : Array(Pointer(Void))
      # Keep minimal stable API: return empty array (no preallocated simd accs)
      [] of Pointer(Void)
    end
  end
end
