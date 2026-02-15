require "../bindings/lib_xxh"
require "../common/errors"
require "../common/types"

module XXH
  module XXH64
    class State
      def initialize(seed : Seed64 = 0_u64)
        @state = LibXXH.XXH64_createState
        raise StateError.new("Failed to allocate XXH64 state") if @state.null?
        reset(seed)
      end

      def update(data : Bytes | String)
        ErrorHandler.check!(LibXXH.XXH64_update(@state, data.to_unsafe, data.size), "XXH64 update")
        self
      end

      def digest : UInt64
        LibXXH.XXH64_digest(@state)
      end

      def reset(seed : Seed64 = 0_u64)
        ErrorHandler.check!(LibXXH.XXH64_reset(@state, seed), "XXH64 reset")
        self
      end

      def dispose
        return if @state.null?
        ErrorHandler.check!(LibXXH.XXH64_freeState(@state), "XXH64 free state")
        @state = Pointer(LibXXH::XXH64_state_t).null
      end

      def finalize
        dispose
      end
    end
  end
end
