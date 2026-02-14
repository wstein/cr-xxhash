require "../bindings/lib_xxh"
require "../common/errors"
require "../common/types"

module XXH
  module XXH3
    class State64
      def initialize(seed : Seed64 = 0_u64)
        @state = LibXXH.XXH3_createState
        raise StateError.new("Failed to allocate XXH3 state") if @state.null?
        reset(seed)
      end

      def update(str : String)
        update(str.to_slice)
      end

      def update(slice : Slice(UInt8))
        ErrorHandler.check!(LibXXH.XXH3_64bits_update(@state, slice.to_unsafe, slice.size), "XXH3_64 update")
        self
      end

      def digest : UInt64
        LibXXH.XXH3_64bits_digest(@state)
      end

      def reset(seed : Seed64 = 0_u64)
        if seed == 0_u64
          ErrorHandler.check!(LibXXH.XXH3_64bits_reset(@state), "XXH3_64 reset")
        else
          ErrorHandler.check!(LibXXH.XXH3_64bits_reset_withSeed(@state, seed), "XXH3_64 reset with seed")
        end
        @seed = seed
        self
      end

      def dispose
        return if @state.null?
        ErrorHandler.check!(LibXXH.XXH3_freeState(@state), "XXH3 free state")
        @state = Pointer(LibXXH::XXH3_state_t).null
      end

      def finalize
        dispose
      end
    end

    class State128
      def initialize(seed : Seed64 = 0_u64)
        @state = LibXXH.XXH3_createState
        raise StateError.new("Failed to allocate XXH3 state") if @state.null?
        reset(seed)
      end

      def update(data : Bytes)
        update(str.to_slice)
      end

      def update(slice : Slice(UInt8))
        ErrorHandler.check!(LibXXH.XXH3_128bits_update(@state, slice.to_unsafe, slice.size), "XXH3_128 update")
        self
      end

      def digest : ::XXH::Hash128
        ::XXH::Hash128.new(LibXXH.XXH3_128bits_digest(@state))
      end

      def reset(seed : Seed64 = 0_u64)
        if seed == 0_u64
          ErrorHandler.check!(LibXXH.XXH3_128bits_reset(@state), "XXH3_128 reset")
        else
          ErrorHandler.check!(LibXXH.XXH3_128bits_reset_withSeed(@state, seed), "XXH3_128 reset with seed")
        end
        @seed = seed
        self
      end

      def dispose
        return if @state.null?
        ErrorHandler.check!(LibXXH.XXH3_freeState(@state), "XXH3 free state")
        @state = Pointer(LibXXH::XXH3_state_t).null
      end

      def finalize
        dispose
      end
    end
  end
end
