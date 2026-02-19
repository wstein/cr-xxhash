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
        LibXXH.XXH64_reset(@state, seed)
        self
      end

      def copy : State
        # Allocate a fresh destination object (allocates its own C state)
        dst = self.class.new(0_u64)
        begin
          # Deep-copy into the destination's C state
          ErrorHandler.check!(LibXXH.XXH3_copyState(dst.@state, @state), "XXH64 copyState")
          dst
        rescue ex
          dst.dispose
          raise ex
        end
      end

      def dispose
        return if @state.null?
        LibXXH.XXH64_freeState(@state)
        @state = Pointer(LibXXH::XXH_state_t).null
      end

      def finalize
        dispose
      end
    end
  end
end
