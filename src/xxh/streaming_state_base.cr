# Unified streaming state base class for all hash algorithms (XXH32, XXH64, XXH3).
# Consolidates common lifecycle logic: buffer management and state operations.
# Subclasses override abstract methods for algorithm-specific behavior.

module XXH
  abstract class StreamingStateBase
    # Subclasses declare their own @total_len, @seed, @buffered, @buffer
    # (types vary; initialization delegated to subclass init_state)

    # Initialize with optional seed — calls init_state to set up subclass fields.
    def initialize(seed : UInt64 | UInt32 | Nil = nil)
      init_state(seed)
    end

    # Reset to initial state with optional new seed.
    def reset(seed : UInt64 | UInt32 | Nil = nil) : Nil
      init_state(seed)
      nil
    end

    # Append input to the streaming state.
    def update(input : Bytes) : Nil
      update_slice(input.to_slice)
    end

    def update(input : Slice(UInt8)) : Nil
      update_slice(input)
    end

    # Core update logic: buffer fill + stripe processing + remainder handling.
    protected def update_slice(input : Slice(UInt8)) : Nil
      remaining = input.size
      ptr = input.to_unsafe

      # Track total length (must be implemented by subclass)
      update_total_len(remaining)

      # Use helper to manage buffer and process complete stripes
      @buffered, ptr, remaining = XXH::StreamingHelpers.buffer_and_process_stripes(
        @buffer,
        @buffered,
        ptr,
        remaining,
        buffer_size
      ) do |p, size|
        process_stripe(p, size)
      end

      # Buffer any remaining partial data
      if remaining > 0
        @buffered = XXH::StreamingHelpers.buffer_remainder(@buffer, ptr, remaining)
      end
    end

    # Copy state from another — subclasses implement algorithm-specific logic.
    abstract def copy_from(other : StreamingStateBase) : Nil

    # ============= Abstract Methods (Subclass Responsibility) =============

    # Algorithm-specific buffer size (16 for XXH32, 32 for XXH64, 256+ for XXH3).
    abstract def buffer_size : Int32

    # Algorithm-specific initialization (seed, accumulator setup).
    abstract def init_state(seed : UInt64 | UInt32 | Nil) : Nil

    # Algorithm-specific total-length tracking (increment @total_len by input size).
    abstract def update_total_len(input_size : Int) : Nil

    # Algorithm-specific stripe processing (update accumulators or buffer).
    abstract def process_stripe(ptr : Pointer(UInt8), size : Int32) : Nil

    # Algorithm-specific digest finalization (compute final hash from state).
    abstract def finalize_digest : UInt32 | UInt64 | Hash128

    # ============= Public Digest API =============

    # Finalize and return hash.
    def digest : UInt32 | UInt64 | Hash128
      finalize_digest
    end

    # Free/cleanup (no-op for pure Crystal).
    def free : Nil
    end

    def finalize
      free
    end
  end
end
