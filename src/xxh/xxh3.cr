require "../ffi/bindings"

module XXH::XXH3
  # One-shot hashing
  def self.hash(input : Bytes) : UInt64
    XXH::FFI.show_deprecation_warning
    LibXXH.XXH3_64bits(input.to_unsafe, input.size)
  end

  def self.hash_with_seed(input : Bytes, seed : UInt64) : UInt64
    XXH::FFI.show_deprecation_warning
    LibXXH.XXH3_64bits_withSeed(input.to_unsafe, input.size, seed)
  end

  # Streaming state wrapper
  class State
    def initialize(seed : UInt64? = nil)
      XXH::FFI.show_deprecation_warning
      @ptr = LibXXH.XXH3_createState
      raise "failed to allocate XXH3 state" if @ptr.null?

      if seed.nil?
        LibXXH.XXH3_64bits_reset(@ptr)
      else
        LibXXH.XXH3_64bits_reset_withSeed(@ptr, seed.to_u64)
      end
    end

    def update(input : Bytes)
      LibXXH.XXH3_64bits_update(@ptr, input.to_unsafe, input.size)
    end

    def digest : UInt64
      LibXXH.XXH3_64bits_digest(@ptr)
    end

    def reset(seed : UInt64? = nil)
      if seed.nil?
        LibXXH.XXH3_64bits_reset(@ptr)
      else
        LibXXH.XXH3_64bits_reset_withSeed(@ptr, seed)
      end
    end

    def free
      LibXXH.XXH3_freeState(@ptr)
      @ptr = Pointer(LibXXH::XXH3_state_t).null
    end

    def finalize
      free unless @ptr.null?
    end
  end

  def self.new_state(seed : UInt64? = nil)
    State.new(seed)
  end
end
