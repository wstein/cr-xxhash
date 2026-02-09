module XXH::StreamingHelpers
  # Consolidates shared streaming state management logic for both XXH32 and XXH64.
  # Rather than duplicating ~150 lines in each State class, we provide helper methods
  # that delegate type-specific operations (round functions, buffer sizes) to callers.

  # Helper to fill buffer from input, processing complete stripes when buffer is full.
  # Returns a tuple of (buffered_count, remaining_pointer, remaining_bytes).
  def self.buffer_and_process_stripes(
    buffer : Bytes,
    buffered : UInt32,
    input_ptr : Pointer(UInt8),
    remaining : Int,
    stride_byte_size : Int,
    &block : (Pointer(UInt8), Int32) -> Nil
  ) : Tuple(UInt32, Pointer(UInt8), Int32)
    ptr = input_ptr
    bytes_left = remaining
    buff_size : UInt32 = buffered
    stride_i32 = stride_byte_size.to_i32
    buf_ptr = buffer.to_unsafe

    # If buffer has partial data, try to complete it
    if buff_size > 0
      to_copy = [stride_byte_size - buff_size.to_i, bytes_left].min
      # Copy from input to buffer at offset buff_size
      i = 0
      while i < to_copy
        buf_ptr[buff_size + i] = ptr[i]
        i += 1
      end
      buff_size += to_copy.to_u32
      bytes_left -= to_copy
      ptr += to_copy

      # If buffer is complete, process it
      if buff_size == stride_byte_size
        block.call(buf_ptr, stride_i32)
        buff_size = 0_u32
      end
    end

    # Process complete strides directly from input
    while bytes_left >= stride_byte_size
      block.call(ptr, stride_i32)
      bytes_left -= stride_byte_size
      ptr += stride_byte_size
    end

    # Return remaining counts and pointer
    {buff_size, ptr, bytes_left.to_i32}
  end

  # Helper to finalize buffering: copy remainder into buffer
  def self.buffer_remainder(
    buffer : Bytes,
    input_ptr : Pointer(UInt8),
    remaining : Int,
  ) : UInt32
    if remaining > 0
      buf_ptr = buffer.to_unsafe
      i = 0
      while i < remaining
        buf_ptr[i] = input_ptr[i]
        i += 1
      end
      remaining.to_u32
    else
      0_u32
    end
  end
end
