require "../bindings/lib_xxh"
require "../common/errors"
require "../common/types"

module XXH
  module XXH32
    class State
      def initialize(seed : Seed32 = 0_u32)
        @state = LibXXH.XXH32_createState
        raise StateError.new("Failed to allocate XXH32 state") if @state.null?
        reset(seed)
      end

      def update(slice : Slice(UInt8))
        ErrorHandler.check!(LibXXH.XXH32_update(@state, slice.to_unsafe, slice.size), "XXH32 update")
        self
      end

      def update(str : String)
        update(str.to_slice)
      end

      def digest : UInt32
        LibXXH.XXH32_digest(@state)
      end

      def reset(seed : Seed32 = 0_u32)
        ErrorHandler.check!(LibXXH.XXH32_reset(@state, seed), "XXH32 reset")
        @seed = seed
        self
      end

      def dispose
        return if @state.null?
        ErrorHandler.check!(LibXXH.XXH32_freeState(@state), "XXH32 free state")
        @state = Pointer(LibXXH::XXH32_state_t).null
      end

      def finalize
        dispose
      end
    end
  end
end
