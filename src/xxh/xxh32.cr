require "../xxh/primitives"
require "../xxh/common"

module XXH::XXH32
  # Pure-Crystal XXH32 implementation (translated from vendored C)

  @[AlwaysInline]
  def self.round(acc : UInt32, input : UInt32) : UInt32
    tmp = (acc &+ (input &* XXH::Constants::PRIME32_2))
    XXH::Primitives.rotl32(tmp, 13_u32) &* XXH::Constants::PRIME32_1
  end

  @[AlwaysInline]
  def self.merge_accs(accs : Array(UInt32)) : UInt32
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

  def self.init_accs(accs : Array(UInt32), seed : UInt32)
    accs[0] = seed &+ (XXH::Constants::PRIME32_1 &+ XXH::Constants::PRIME32_2)
    accs[1] = seed &+ XXH::Constants::PRIME32_2
    accs[2] = seed &+ 0_u32
    accs[3] = seed &- XXH::Constants::PRIME32_1
  end

  def self.consume_long(accs : Array(UInt32), ptr : Pointer(UInt8), len : Int32) : Pointer(UInt8)
    input = ptr
    limit = ptr + (len - 15)
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

  # One-shot hashing
  def self.hash(input : Bytes, seed : UInt32 = 0_u32) : UInt32
    len = input.size
    if len >= 16
      accs = Array(UInt32).new(4, 0_u32)
      init_accs(accs, seed)
      ptr = input.to_unsafe
      ptr = consume_long(accs, ptr, len)
      h32 = merge_accs(accs)
      finalize_hash(h32 &+ len.to_u32, ptr, len & 15)
    else
      h32 = seed &+ XXH::Constants::PRIME32_5
      h32 = h32 &+ len.to_u32
      ptr = input.to_unsafe
      finalize_hash(h32, ptr, len)
    end
  end

  # Streaming state wrapper
  class State
    @total_len : UInt32
    @accs : Array(UInt32)
    @buffer : Bytes
    @buffered : UInt32
    @seed : UInt32

    def initialize(seed : UInt32 = 0_u32)
      @total_len = 0_u32
      @accs = Array(UInt32).new(4, 0_u32)
      @buffer = Bytes.new(16)
      @buffered = 0_u32
      @seed = seed
      XXH::XXH32.init_accs(@accs, seed)
    end

    def copy_from(other : State)
      @total_len = other.@total_len
      @buffered = other.@buffered
      @seed = other.@seed
      @accs[0] = other.@accs[0]
      @accs[1] = other.@accs[1]
      @accs[2] = other.@accs[2]
      @accs[3] = other.@accs[3]
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
      @total_len = @total_len &+ remaining.to_u32

      if @buffered > 0
        to_copy = [16 - @buffered, remaining].min
        i = 0
        while i < to_copy
          @buffer[@buffered + i] = ptr[i]
          i += 1
        end
        @buffered += to_copy
        remaining -= to_copy
        ptr += to_copy
        if @buffered == 16
          p = @buffer.to_unsafe
          @accs[0] = XXH::XXH32.round(@accs[0], XXH::Primitives.read_u32_le(p)); p += 4
          @accs[1] = XXH::XXH32.round(@accs[1], XXH::Primitives.read_u32_le(p)); p += 4
          @accs[2] = XXH::XXH32.round(@accs[2], XXH::Primitives.read_u32_le(p)); p += 4
          @accs[3] = XXH::XXH32.round(@accs[3], XXH::Primitives.read_u32_le(p)); p += 4
          @buffered = 0
        end
      end

      while remaining >= 16
        @accs[0] = XXH::XXH32.round(@accs[0], XXH::Primitives.read_u32_le(ptr)); ptr += 4
        @accs[1] = XXH::XXH32.round(@accs[1], XXH::Primitives.read_u32_le(ptr)); ptr += 4
        @accs[2] = XXH::XXH32.round(@accs[2], XXH::Primitives.read_u32_le(ptr)); ptr += 4
        @accs[3] = XXH::XXH32.round(@accs[3], XXH::Primitives.read_u32_le(ptr)); ptr += 4
        remaining -= 16
      end

      if remaining > 0
        @buffered = remaining.to_u32
        i = 0
        while i < remaining
          @buffer[i] = ptr[i]
          i += 1
        end
      end
    end

    def digest : UInt32
      if @total_len >= 16
        h32 = XXH::XXH32.merge_accs(@accs)
      else
        h32 = @accs[2] &+ XXH::Constants::PRIME32_5
      end
      h32 = h32 &+ @total_len
      XXH::XXH32.finalize_hash(h32, @buffer.to_unsafe, @total_len.to_i)
    end

    def reset(seed : UInt32 = 0_u32)
      @total_len = 0_u32
      @buffered = 0_u32
      XXH::XXH32.init_accs(@accs, seed)
    end

    def free
      # no-op
    end

    def finalize
      free
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
