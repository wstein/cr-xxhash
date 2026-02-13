require "../xxh/primitives"
require "../xxh/common"
require "../xxh/xxh_streaming_helpers"
require "../xxh/streaming_state_base"

module XXH::XXH32
  # Pure-Crystal XXH32 implementation (translated from vendored C)

  @[AlwaysInline]
  def self.round(acc : UInt32, input : UInt32) : UInt32
    tmp = (acc &+ (input &* XXH::Constants::PRIME32_2))
    XXH::Primitives.rotl32(tmp, 13_u32) &* XXH::Constants::PRIME32_1
  end

  @[AlwaysInline]
  def self.merge_accs(accs : Pointer(UInt32)) : UInt32
    XXH::Primitives.rotl32(accs[0], 1_u32) &+
      XXH::Primitives.rotl32(accs[1], 7_u32) &+
      XXH::Primitives.rotl32(accs[2], 12_u32) &+
      XXH::Primitives.rotl32(accs[3], 18_u32)
  end

  @[AlwaysInline]
  def self.avalanche(hash : UInt32) : UInt32
    h = hash
    h = h ^ (h >> 15)
    h = (h &* XXH::Constants::PRIME32_2)
    h = h ^ (h >> 13)
    h = (h &* XXH::Constants::PRIME32_3)
    h = h ^ (h >> 16)
    h
  end

  @[AlwaysInline]
  def self.init_accs(accs : Pointer(UInt32), seed : UInt32)
    accs[0] = seed &+ (XXH::Constants::PRIME32_1 &+ XXH::Constants::PRIME32_2)
    accs[1] = seed &+ XXH::Constants::PRIME32_2
    accs[2] = seed &+ 0_u32
    accs[3] = seed &- XXH::Constants::PRIME32_1
  end

  @[AlwaysInline]
  def self.consume_long(accs : Pointer(UInt32), ptr : Pointer(UInt8), len : Int32) : Pointer(UInt8)
    input = ptr
    limit = ptr + (len - 15)
    # Unroll 4 iterations (64 bytes) to increase ILP
    while input + 64 <= limit
      # iter 1
      accs[0] = round(accs[0], XXH::Primitives.read_u32_le(input)); input += 4
      accs[1] = round(accs[1], XXH::Primitives.read_u32_le(input)); input += 4
      accs[2] = round(accs[2], XXH::Primitives.read_u32_le(input)); input += 4
      accs[3] = round(accs[3], XXH::Primitives.read_u32_le(input)); input += 4
      # iter 2
      accs[0] = round(accs[0], XXH::Primitives.read_u32_le(input)); input += 4
      accs[1] = round(accs[1], XXH::Primitives.read_u32_le(input)); input += 4
      accs[2] = round(accs[2], XXH::Primitives.read_u32_le(input)); input += 4
      accs[3] = round(accs[3], XXH::Primitives.read_u32_le(input)); input += 4
      # iter 3
      accs[0] = round(accs[0], XXH::Primitives.read_u32_le(input)); input += 4
      accs[1] = round(accs[1], XXH::Primitives.read_u32_le(input)); input += 4
      accs[2] = round(accs[2], XXH::Primitives.read_u32_le(input)); input += 4
      accs[3] = round(accs[3], XXH::Primitives.read_u32_le(input)); input += 4
      # iter 4
      accs[0] = round(accs[0], XXH::Primitives.read_u32_le(input)); input += 4
      accs[1] = round(accs[1], XXH::Primitives.read_u32_le(input)); input += 4
      accs[2] = round(accs[2], XXH::Primitives.read_u32_le(input)); input += 4
      accs[3] = round(accs[3], XXH::Primitives.read_u32_le(input)); input += 4
    end

    # finish remaining iterations
    while input < limit
      accs[0] = round(accs[0], XXH::Primitives.read_u32_le(input))
      input += 4
      accs[1] = round(accs[1], XXH::Primitives.read_u32_le(input))
      input += 4
      accs[2] = round(accs[2], XXH::Primitives.read_u32_le(input))
      input += 4
      accs[3] = round(accs[3], XXH::Primitives.read_u32_le(input))
      input += 4
    end
    input
  end

  def self.finalize_hash(h : UInt32, ptr : Pointer(UInt8), len : Int32) : UInt32
    len = len & 15

    @[Likely]
    while len >= 4
      h = h &+ (XXH::Primitives.read_u32_le(ptr) &* XXH::Constants::PRIME32_3)
      ptr += 4
      h = XXH::Primitives.rotl32(h, 17_u32) &* XXH::Constants::PRIME32_4
      len -= 4
    end

    while len > 0
      h = h &+ (ptr[0].to_u32 &* XXH::Constants::PRIME32_5)
      ptr += 1
      h = XXH::Primitives.rotl32(h, 11_u32) &* XXH::Constants::PRIME32_1
      len -= 1
    end

    avalanche(h)
  end

  # One-shot hashing (C-backed via LibXXH)
  def self.hash(input : Bytes, seed : UInt32 = 0_u32) : UInt32
    LibXXH.XXH32(input.to_unsafe, input.size, seed)
  end

  # Streaming state wrapper — inherits common lifecycle from StreamingStateBase
  class State < XXH::StreamingStateBase
    @total_len : UInt32
    @accs : StaticArray(UInt32, 4)
    @seed : UInt32

    def buffer_size : Int32
      16
    end

    def init_state(seed : UInt64 | UInt32 | Nil) : Nil
      s = (seed || 0_u32).as(UInt32)
      @total_len = 0_u32
      @seed = s
      @accs = uninitialized UInt32[4]
      XXH::XXH32.init_accs(@accs.to_unsafe, s)
      nil
    end

    def update_total_len(input_size : Int) : Nil
      @total_len = @total_len &+ input_size.to_u32
      nil
    end

    def process_stripe(ptr : Pointer(UInt8), size : Int32) : Nil
      # Process one 16-byte stripe (4 × 4-byte rounds)
      p_mut = ptr
      @accs[0] = XXH::XXH32.round(@accs[0], XXH::Primitives.read_u32_le(p_mut)); p_mut += 4
      @accs[1] = XXH::XXH32.round(@accs[1], XXH::Primitives.read_u32_le(p_mut)); p_mut += 4
      @accs[2] = XXH::XXH32.round(@accs[2], XXH::Primitives.read_u32_le(p_mut)); p_mut += 4
      @accs[3] = XXH::XXH32.round(@accs[3], XXH::Primitives.read_u32_le(p_mut)); p_mut += 4
      nil
    end

    def finalize_digest : UInt32
      if @total_len >= 16
        h32 = XXH::XXH32.merge_accs(@accs.to_unsafe)
      else
        h32 = @accs[2] &+ XXH::Constants::PRIME32_5
      end
      h32 = h32 &+ @total_len
      XXH::XXH32.finalize_hash(h32, @buffer.to_unsafe, @total_len.to_i)
    end

    def copy_state_details(other : StreamingStateBase) : Nil
      other_state = other.as(State)
      @accs[0] = other_state.@accs[0]
      @accs[1] = other_state.@accs[1]
      @accs[2] = other_state.@accs[2]
      @accs[3] = other_state.@accs[3]
      nil
    end

    def copy_from(other : State)
      other_state = other.as(State)
      @total_len = other_state.@total_len
      @buffered = other_state.@buffered
      @seed = other_state.@seed
      @accs[0] = other_state.@accs[0]
      @accs[1] = other_state.@accs[1]
      @accs[2] = other_state.@accs[2]
      @accs[3] = other_state.@accs[3]
      i = 0
      while i < @buffered.to_i
        @buffer[i] = other_state.@buffer[i]
        i += 1
      end
      nil
    end
  end

  def self.new_state(seed : UInt32 = 0_u32)
    State.new(seed)
  end

  # C-style aliases
  def self.xxh32_create_state(seed : UInt32 = 0_u32) : State
    new_state(seed)
  end

  def self.xxh32_reset(state : State, seed : UInt32 = 0_u32) : Int32
    state.reset(seed)
    0
  end

  def self.xxh32_update(state : State, input_ptr : Pointer(Void), len : Int) : Int32
    return 0 if input_ptr.null? && len == 0
    ptr8 = input_ptr.as(Pointer(UInt8))
    slice = Slice.new(ptr8, len)
    state.update(slice)
    0
  end

  def self.xxh32_digest(state : State) : UInt32
    state.digest
  end

  def self.xxh32_free_state(state : State) : Int32
    state.reset(0_u32)
    0
  end

  def self.xxh32_copy_state(dst : State, src : State)
    dst.copy_from(src)
    nil
  end

  # Canonical conversions (big-endian)
  def self.xxh32_canonical_from_hash(dst : Bytes, hash : UInt32)
    (0...4).each do |i|
      dst[i] = ((hash >> ((3 - i) * 8)) & 0xFF_u32).to_u8
    end
    nil
  end

  def self.xxh32_hash_from_canonical(src : Bytes) : UInt32
    ((0...4).map { |i| src[i].to_u32 << ((3 - i) * 8) }).reduce(0_u32) { |acc, x| acc | x }
  end
end
