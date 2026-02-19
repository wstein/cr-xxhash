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

      def update(data : Bytes | String)
        ErrorHandler.check!(LibXXH.XXH3_64bits_update(@state, data.to_unsafe, data.size), "XXH3_64 update")
        self
      end

      def digest : UInt64
        LibXXH.XXH3_64bits_digest(@state)
      end

      def reset(seed : Seed64)
        LibXXH.XXH3_64bits_reset_withSeed(@state, seed)
        self
      end

      def reset
        LibXXH.XXH3_64bits_reset(@state, 0_u64)
        self
      end

      def copy : State64
        # Create destination state for copying
        copy_state = LibXXH.XXH3_createState
        raise StateError.new("Failed to allocate XXH3 state for copy") if copy_state.null?
        
        begin
          # Deep copy the source state into the destination
          ErrorHandler.check!(LibXXH.XXH3_copyState(copy_state, @state), "XXH3 copyState")
          
          # Create a new Ruby-side object wrapping the copied C state
          copied = self.class.allocate
          copied.instance_variable_set(:@state, copy_state)
          copied
        rescue
          # Clean up on error
          LibXXH.XXH3_freeState(copy_state)
          raise
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
