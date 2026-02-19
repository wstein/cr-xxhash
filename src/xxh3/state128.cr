require "../bindings/lib_xxh"
require "../common/errors"
require "../common/types"

module XXH
  module XXH3
    class State128
      def initialize(seed : Seed64 = 0_u64)
        @state = LibXXH.XXH3_createState
        raise StateError.new("Failed to allocate XXH3 state") if @state.null?
        reset(seed)
      end

      def update(data : Bytes | String)
        ErrorHandler.check!(LibXXH.XXH3_128bits_update(@state, data.to_unsafe, data.size), "XXH3_128 update")
        self
      end

      def digest : UInt128
        c_hash = LibXXH.XXH3_128bits_digest(@state)
        UInt128.from_c_hash(c_hash)
      end

      def reset(seed : Seed64)
        LibXXH.XXH3_128bits_reset_withSeed(@state, seed)
        self
      end

      def reset
        LibXXH.XXH3_128bits_reset(@state, 0_u64)
        self
      end

      def copy : State128
        # Allocate a fresh destination object (allocates its own C state)
        dst = self.class.new(0_u64)
        begin
          # Deep-copy into the destination's C state
          ErrorHandler.check!(LibXXH.XXH3_copyState(dst.@state, @state), "XXH3 copyState")
          dst
        rescue ex
          dst.dispose
          raise ex
        end
      end

      def dispose
        return if @state.null?
        LibXXH.XXH3_freeState(@state)
        @state = Pointer(LibXXH::XXH_state_t).null
      end

      def finalize
        dispose
      end
    end
  end
end
