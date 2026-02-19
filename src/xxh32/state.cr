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

      def update(data : Bytes | String)
        ErrorHandler.check!(LibXXH.XXH32_update(@state, data.to_unsafe, data.size), "XXH32 update")
        self
      end

      def digest : UInt32
        LibXXH.XXH32_digest(@state)
      end

      def reset(seed : Seed32 = 0_u32)
        LibXXH.XXH32_reset(@state, seed)
        self
      end

      def dispose
        return if @state.null?
        LibXXH.XXH32_freeState(@state)
        @state = Pointer(LibXXH::XXH_state_t).null
      end

      def finalize
        dispose
      end
    end
  end
end
