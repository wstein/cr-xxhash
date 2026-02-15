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

      def digest : ::XXH::Hash128
        ::XXH::Hash128.new(LibXXH.XXH3_128bits_digest(@state))
      end

      def reset(seed : Seed64)
        ErrorHandler.check!(LibXXH.XXH3_128bits_reset_withSeed(@state, seed), "XXH3_128 reset with seed")
        self
      end

      def reset
        ErrorHandler.check!(LibXXH.XXH3_128bits_reset(@state), "XXH3_128 reset")
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
