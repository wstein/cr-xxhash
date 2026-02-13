# Consolidated streaming helpers for all hash algorithms (XXH32, XXH64, XXH3).
# Provides common buffer management, stripe processing, and finalization utilities
# Originally split across XXH::StreamingHelpers and XXH::XXH3::StreamingStateBase.

module XXH::StreamingHelpers
  # Generic buffer fill and stripe processing with caller-provided block.
  # Manages partial buffer completion and direct input stripe processing.
  # Returns (buffered_size, remaining_input_ptr, remaining_bytes).
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

  # Copy remainder of input into buffer for later processing.
  # Used when input has leftover bytes that don't fill a complete stride.
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
