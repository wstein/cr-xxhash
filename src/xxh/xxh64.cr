require "../xxh/primitives"
require "../xxh/common"

module XXH::XXH64
  # Pure-Crystal implementation of XXH64 (translated from vendored C)

  @[AlwaysInline]
  def self.round(acc : UInt64, input : UInt64) : UInt64
    # XXH64_round(acc, input) = ((acc + input * PRIME64_2) <<< 31) * PRIME64_1
    tmp = acc &+ (input &* XXH::Constants::PRIME64_2)
    XXH::Primitives.rotl64(tmp, 31_u32) &* XXH::Constants::PRIME64_1
  end

  @[AlwaysInline]
  def self.merge_round(h : UInt64, acc : UInt64) : UInt64
    # (h ^ XXH64_round(0, acc)) * PRIME64_1 + PRIME64_4
    ((h ^ round(0_u64, acc)) &* XXH::Constants::PRIME64_1) &+ XXH::Constants::PRIME64_4
  end

  @[AlwaysInline]
  def self.avalanche(hash : UInt64) : UInt64
    # XXH64_avalanche
    h = hash
    h = h ^ (h >> 33)
    h = h &* XXH::Constants::PRIME64_2
    h = h ^ (h >> 29)
    h = h &* XXH::Constants::PRIME64_3
    h = h ^ (h >> 32)
    h
  end

  @[AlwaysInline]
  def self.init_accs(accs : Pointer(UInt64), seed : UInt64)
    accs[0] = seed &+ (XXH::Constants::PRIME64_1 &+ XXH::Constants::PRIME64_2)
    accs[1] = seed &+ XXH::Constants::PRIME64_2
    accs[2] = seed &+ 0_u64
    accs[3] = seed &- XXH::Constants::PRIME64_1
  end

  @[AlwaysInline]
  def self.consume_long(accs : Pointer(UInt64), ptr : Pointer(UInt8), len : Int32) : Pointer(UInt8)
    # Consume chunks of 32 bytes (4 lanes × 8 bytes)
    input = ptr
    limit = ptr + (len - 31)
    # Unrolled loop (2×32 bytes per iteration) with light prefetch
    prefetch_dist = 64
    while input + prefetch_dist < limit
      # prefetch next cache line (software read)
      _ = XXH::Primitives.read_u64_le(input + prefetch_dist)

      # first 32 bytes
      accs[0] = round(accs[0], XXH::Primitives.read_u64_le(input))
      input += 8
      accs[1] = round(accs[1], XXH::Primitives.read_u64_le(input))
      input += 8
      accs[2] = round(accs[2], XXH::Primitives.read_u64_le(input))
      input += 8
      accs[3] = round(accs[3], XXH::Primitives.read_u64_le(input))
      input += 8

      # second 32 bytes
      accs[0] = round(accs[0], XXH::Primitives.read_u64_le(input))
      input += 8
      accs[1] = round(accs[1], XXH::Primitives.read_u64_le(input))
      input += 8
      accs[2] = round(accs[2], XXH::Primitives.read_u64_le(input))
      input += 8
      accs[3] = round(accs[3], XXH::Primitives.read_u64_le(input))
      input += 8
    end

    # finish remaining iterations
    while input < limit
      accs[0] = round(accs[0], XXH::Primitives.read_u64_le(input))
      input += 8
      accs[1] = round(accs[1], XXH::Primitives.read_u64_le(input))
      input += 8
      accs[2] = round(accs[2], XXH::Primitives.read_u64_le(input))
      input += 8
      accs[3] = round(accs[3], XXH::Primitives.read_u64_le(input))
      input += 8
    end
    input
  end

  @[AlwaysInline]
  def self.merge_accs(accs : Pointer(UInt64)) : UInt64
    h64 = XXH::Primitives.rotl64(accs[0], 1_u32) &+
          XXH::Primitives.rotl64(accs[1], 7_u32) &+
          XXH::Primitives.rotl64(accs[2], 12_u32) &+
          XXH::Primitives.rotl64(accs[3], 18_u32)

    h64 = merge_round(h64, accs[0])
    h64 = merge_round(h64, accs[1])
    h64 = merge_round(h64, accs[2])
    h64 = merge_round(h64, accs[3])
    h64
  end

  def self.finalize_hash(h : UInt64, ptr : Pointer(UInt8), len : Int32) : UInt64
    # tail processing
    # Only the remainder modulo 32 bytes is relevant here (match C behavior)
    len = len & 31

    # process 8-byte chunks
    while len >= 8
      k1 = round(0_u64, XXH::Primitives.read_u64_le(ptr))
      ptr += 8
      h ^= k1
      h = XXH::Primitives.rotl64(h, 27_u32) &* XXH::Constants::PRIME64_1 &+ XXH::Constants::PRIME64_4
      len -= 8
    end

    @[Likely]
    if len >= 4
      h ^= (XXH::Primitives.read_u32_le(ptr).to_u64) &* XXH::Constants::PRIME64_1
      ptr += 4
      h = XXH::Primitives.rotl64(h, 23_u32) &* XXH::Constants::PRIME64_2 &+ XXH::Constants::PRIME64_3
      len -= 4
    end

    while len > 0
      h ^= ptr[0].to_u64 &* XXH::Constants::PRIME64_5
      h = XXH::Primitives.rotl64(h, 11_u32) &* XXH::Constants::PRIME64_1
      ptr += 1
      len -= 1
    end

    avalanche(h)
  end

  # One-shot hashing
  def self.hash(input : Bytes, seed : UInt64 = 0_u64) : UInt64
    len = input.size
    @[Likely]
    if len >= 32
      accs = uninitialized UInt64[4]
      init_accs(accs.to_unsafe, seed)
      ptr = input.to_unsafe
      # consume long
      ptr = consume_long(accs.to_unsafe, ptr, len)
      h64 = merge_accs(accs.to_unsafe)
      finalize_hash(h64 &+ len.to_u64, ptr, len & 31)
    else
      h64 = seed &+ XXH::Constants::PRIME64_5
      h64 = h64 &+ len.to_u64
      ptr = input.to_unsafe
      finalize_hash(h64, ptr, len)
    end
  end

  # Streaming state wrapper
  class State
    @total_len : UInt64
    @accs : StaticArray(UInt64, 4)
    @buffer : Bytes
    @buffered : UInt32
    @seed : UInt64

    def initialize(seed : UInt64 = 0_u64)
      @total_len = 0_u64
      @accs = uninitialized UInt64[4]
      @buffer = Bytes.new(32)
      @buffered = 0_u32
      @seed = seed
      XXH::XXH64.init_accs(@accs.to_unsafe, seed)
    end

    # Copy contents from another state (mirror behaviour of XXH64_copyState)
    def copy_from(other : State)
      @total_len = other.@total_len
      @buffered = other.@buffered
      @seed = other.@seed
      # copy accumulators
      @accs[0] = other.@accs[0]
      @accs[1] = other.@accs[1]
      @accs[2] = other.@accs[2]
      @accs[3] = other.@accs[3]
      # copy buffer bytes
      i = 0
      while i < @buffered.to_i
        @buffer[i] = other.@buffer[i]
        i += 1
      end
      nil
    end

    def update(input : Bytes)
      update_slice(input.to_slice)
    end

    def update(input : Slice(UInt8))
      update_slice(input)
    end

    private def update_slice(input : Slice(UInt8))
      remaining = input.size
      ptr = input.to_unsafe
      @total_len = @total_len &+ remaining.to_u64

      # if there is existing buffered data, fill it
      if @buffered > 0
        to_copy = [32 - @buffered, remaining].min
        # copy to buffer
        i = 0
        while i < to_copy
          @buffer[@buffered + i] = ptr[i]
          i += 1
        end

        @buffered += to_copy
        remaining -= to_copy
        ptr += to_copy

        if @buffered == 32
          # consume buffer (exactly 32 bytes)
          p = @buffer.to_unsafe
          @accs[0] = XXH::XXH64.round(@accs[0], XXH::Primitives.read_u64_le(p)); p += 8
          @accs[1] = XXH::XXH64.round(@accs[1], XXH::Primitives.read_u64_le(p)); p += 8
          @accs[2] = XXH::XXH64.round(@accs[2], XXH::Primitives.read_u64_le(p)); p += 8
          @accs[3] = XXH::XXH64.round(@accs[3], XXH::Primitives.read_u64_le(p)); p += 8

          @buffered = 0
        end
      end

      # consume large chunks directly from input
      while remaining >= 32
        @accs[0] = XXH::XXH64.round(@accs[0], XXH::Primitives.read_u64_le(ptr)); ptr += 8
        @accs[1] = XXH::XXH64.round(@accs[1], XXH::Primitives.read_u64_le(ptr)); ptr += 8
        @accs[2] = XXH::XXH64.round(@accs[2], XXH::Primitives.read_u64_le(ptr)); ptr += 8
        @accs[3] = XXH::XXH64.round(@accs[3], XXH::Primitives.read_u64_le(ptr)); ptr += 8
        remaining -= 32
      end

      # buffer remainder
      if remaining > 0
        @buffered = remaining.to_u32
        # copy remaining bytes into buffer
        i = 0
        while i < remaining
          @buffer[i] = ptr[i]
          i += 1
        end
      end
    end

    def digest : UInt64
      if @total_len >= 32
        h64 = XXH::XXH64.merge_accs(@accs.to_unsafe)
      else
        # use acc[2] as per reference implementation (gives seed + PRIME64_5)
        h64 = @accs[2] &+ XXH::Constants::PRIME64_5
      end
      h64 = h64 &+ @total_len
      XXH::XXH64.finalize_hash(h64, @buffer.to_unsafe, @total_len.to_i)
    end

    def reset(seed : UInt64 = 0_u64)
      @total_len = 0_u64
      @buffered = 0_u32
      XXH::XXH64.init_accs(@accs.to_unsafe, seed)
    end

    def free
      # no-op for pure Crystal implementation
    end

    def finalize
      free
    end
  end

  def self.new_state(seed : UInt64 = 0_u64)
    State.new(seed)
  end

  # Compatibility wrappers mirroring LibXXH streaming API
  # Create a new streaming state (equivalent to LibXXH.XXH64_createState)
  def self.create_state(seed : UInt64 = 0_u64) : State
    State.new(seed)
  end

  # C-style API aliases (for compatibility with existing code)
  # C-style API aliases (lowercase names compatible with Crystal)
  def self.xxh64_create_state(seed : UInt64 = 0_u64) : State
    create_state(seed)
  end

  # Reset an existing state (equivalent to LibXXH.XXH64_reset)
  # Returns 0 on success to match C's XXH_errorcode semantics
  def self.reset_state(state : State, seed : UInt64 = 0_u64) : Int32
    state.reset(seed)
    0
  end

  def self.xxh64_reset(state : State, seed : UInt64 = 0_u64) : Int32
    reset_state(state, seed)
  end

  # Update a state with input (equivalent to LibXXH.XXH64_update)
  def self.update_state(state : State, input : Bytes) : Int32
    state.update(input)
    0
  end

  # Pointer-based update (mirrors C signature: void* input, size_t len)
  def self.xxh64_update(state : State, input_ptr : Pointer(Void), len : Int) : Int32
    return 0 if input_ptr.null? && len == 0
    ptr8 = input_ptr.as(Pointer(UInt8))
    slice = Slice.new(ptr8, len)
    state.update(slice)
    0
  end

  # Finalize/digest a state (equivalent to LibXXH.XXH64_digest)
  def self.digest_state(state : State) : UInt64
    state.digest
  end

  def self.xxh64_digest(state : State) : UInt64
    digest_state(state)
  end

  # Free state (no-op for pure Crystal implementation) — return 0 for success
  def self.xxh64_free_state(state : State) : Int32
    # Optionally clear state
    state.reset(0_u64)
    0
  end

  # Copy state (mirror C XXH64_copyState(dst, src))
  def self.xxh64_copy_state(dst : State, src : State)
    dst.copy_from(src)
    nil
  end

  # Canonical representation conversions (big-endian storage)
  # Writes 8 bytes (big-endian) into dst
  def self.xxh64_canonical_from_hash(dst : Bytes, hash : UInt64)
    # Ensure dst has at least 8 bytes
    (0...8).each do |i|
      dst[i] = ((hash >> ((7 - i) * 8)) & 0xFF_u64).to_u8
    end
    nil
  end

  def self.xxh64_hash_from_canonical(src : Bytes) : UInt64
    ((0...8).map { |i| src[i].to_u64 << ((7 - i) * 8) }).reduce(0_u64) { |acc, x| acc | x }
  end
end
