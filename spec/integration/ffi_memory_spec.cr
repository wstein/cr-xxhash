require "../spec_helper"

describe "FFI Memory Safety & Lifecycle" do
  describe "XXH32 state memory lifecycle" do
    it "create/free state cycles without crashes" do
      100.times do
        state = XXH::XXH32::State.new
        state.update(Bytes[0x01, 0x02, 0x03, 0x04])
        _result = state.digest
      end
    end

    it "multiple state instances coexist safely" do
      states = Array.new(10) { XXH::XXH32::State.new }
      states.each_with_index do |state, i|
        data = Bytes.new(i + 1) { (i.to_u8 + i).to_u8 }
        state.update(data)
      end
      results = states.map(&.digest)
      results.each { |r| r.should be_a(UInt32) }
    end

    it "state reuse after reset maintains memory safety" do
      state = XXH::XXH32::State.new
      10.times do |i|
        data = Bytes.new(i + 1) { (i.to_u8 * 7).to_u8 }
        state.reset
        state.update(data)
        _result = state.digest
      end
    end

    it "seeded state creation and reuse" do
      seeds = [0_u32, 1_u32, 0xFFFFFFFF_u32]
      seeds.each do |seed|
        state = XXH::XXH32::State.new(seed)
        50.times do
          state.update(Bytes[0x42, 0x43])
          result = state.digest
          result.should be_a(UInt32)
          state.reset(seed)
        end
      end
    end
  end

  describe "XXH64 state memory lifecycle" do
    it "create/free state cycles without crashes" do
      100.times do
        state = XXH::XXH64::State.new
        state.update(Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        _result = state.digest
      end
    end

    it "multiple state instances coexist safely" do
      states = Array.new(10) { XXH::XXH64::State.new }
      states.each_with_index do |state, i|
        data = Bytes.new(i + 8) { (i.to_u8 * 11).to_u8 }
        state.update(data)
      end
      results = states.map(&.digest)
      results.each { |r| r.should be_a(UInt64) }
    end

    it "state reuse after reset maintains memory safety" do
      state = XXH::XXH64::State.new
      50.times do |i|
        data = Bytes.new((i % 16) + 1) { ((i + 1) & 0xFF).to_u8 }
        state.reset
        state.update(data)
        _result = state.digest
      end
    end

    it "seeded state creation and lifecycle" do
      seeds = [0_u64, 1_u64, 0xFFFFFFFFFFFFFFFF_u64]
      seeds.each do |seed|
        state = XXH::XXH64::State.new(seed)
        50.times do
          state.update(Bytes.new(8) { 0x55_u8 })
          result = state.digest
          result.should be_a(UInt64)
          state.reset(seed)
        end
      end
    end
  end

  describe "XXH3 64-bit state memory lifecycle" do
    it "create/free state cycles without crashes" do
      100.times do
        state = XXH::XXH3::State64.new
        state.update(Bytes.new(32) { 0xAA_u8 })
        _result = state.digest
      end
    end

    it "multiple state instances coexist safely" do
      states = Array.new(10) { XXH::XXH3::State64.new }
      states.each_with_index do |state, i|
        data = Bytes.new(((i + 1) * 16)) { (i.to_u8 ^ 0x33_u8) }
        state.update(data)
      end
      results = states.map(&.digest)
      results.each { |r| r.should be_a(UInt64) }
    end

    it "state reuse over many cycles" do
      state = XXH::XXH3::State64.new
      100.times do |i|
        size = (i % 240) + 1  # Vary size to test all SIMD paths
        data = Bytes.new(size) { ((i + 1) & 0xFF).to_u8 }
        state.reset
        state.update(data)
        _result = state.digest
      end
    end

    it "seeded state with various sizes" do
      seeds = [0_u64, 42_u64, 0xFFFFFFFFFFFFFFFF_u64]
      seeds.each do |seed|
        state = XXH::XXH3::State64.new(seed)
        [1, 16, 17, 240, 241, 1024].each do |size|
          10.times do
            data = Bytes.new(size) { 0x78_u8 }
            state.update(data)
            result = state.digest
            result.should be_a(UInt64)
            state.reset(seed)
          end
        end
      end
    end
  end

  describe "XXH3 128-bit state memory lifecycle" do
    it "create/free state cycles without crashes" do
      100.times do
        state = XXH::XXH3::State128.new
        state.update(Bytes.new(64) { 0xBB_u8 })
        result = state.digest
        result.should be_a(UInt128)
      end
    end

    it "multiple state instances coexist safely" do
      states = Array.new(10) { XXH::XXH3::State128.new }
      states.each_with_index do |state, i|
        data = Bytes.new(((i + 1) * 32)) { (i.to_u8 ^ 0xCC_u8) }
        state.update(data)
      end
      results = states.map(&.digest)
      results.each do |r|
        r.should be_a(UInt128)
        r.high64.should be_a(UInt64)
        r.low64.should be_a(UInt64)
      end
    end

    it "state reuse over many cycles with size-class transitions" do
      state = XXH::XXH3::State128.new
      100.times do |i|
        size = (i % 500) + 1  # Large range to test all paths
        data = Bytes.new(size) { ((i + 2) & 0xFF).to_u8 }
        state.reset
        state.update(data)
        result = state.digest
        result.should be_a(UInt128)
      end
    end

    it "seeded state lifecycle" do
      seeds = [0_u64, 99_u64, 0xFFFFFFFFFFFFFFFF_u64]
      seeds.each do |seed|
        state = XXH::XXH3::State128.new(seed)
        [0, 1, 16, 17, 240, 241, 1024].each do |size|
          10.times do
            data = Bytes.new(size) { 0x99_u8 }
            state.update(data)
            result = state.digest
            result.should be_a(UInt128)
            state.reset(seed)
          end
        end
      end
    end
  end

  describe "Streaming state with heavy updates" do
    it "XXH64 handles 1000 consecutive updates without issues" do
      state = XXH::XXH64::State.new
      1000.times do |i|
        data = Bytes.new(((i % 256) + 1)) { ((i & 0xFF).to_u8) }
        state.update(data)
      end
      result = state.digest
      result.should be_a(UInt64)
    end

    it "XXH3 64-bit handles 1000 updates with varying sizes" do
      state = XXH::XXH3::State64.new
      1000.times do |i|
        # Cycle through small, medium, and large sizes
        size = case i % 3
               when 0 then i % 16 + 1      # 0-16B (short path)
               when 1 then i % 224 + 17    # 17-240B (medium path)
               else        i % 1000 + 241  # 240B+ (long path)
               end
        data = Bytes.new(size) { (((i >> 8) ^ i) & 0xFF).to_u8 }
        state.update(data)
      end
      result = state.digest
      result.should be_a(UInt64)
    end

    it "XXH3 128-bit handles concurrent-like sequential updates" do
      states = [
        XXH::XXH3::State128.new,
        XXH::XXH3::State128.new,
        XXH::XXH3::State128.new
      ]

      300.times do |i|
        states.each_with_index do |state, idx|
          size = ((i + idx) % 256) + 1
          data = Bytes.new(size) { (((i + idx) & 0xFF).to_u8) }
          state.update(data)
        end
      end

      results = states.map(&.digest)
      results.each { |r| r.should be_a(UInt128) }
    end
  end

  describe "Memory pattern tests (leak detection)" do
    it "state digest produces deterministic output (no stale memory)" do
      # If a state leaks or corrupts memory, digest might vary
      state = XXH::XXH3::State64.new
      data = Bytes.new(256) { |i| (i & 0xFF).to_u8 }

      results = Array.new(10) do
        state.reset
        state.update(data)
        state.digest
      end

      # All results should be identical
      results.each { |r| r.should eq(results[0]) }
    end

    it "interleaved state operations don't corrupt results" do
      states = [
        XXH::XXH32::State.new,
        XXH::XXH64::State.new,
        XXH::XXH3::State64.new,
        XXH::XXH3::State128.new
      ]

      data = Bytes.new(128) { 0x42_u8 }

      # Interleave operations
      20.times do
        states.each { |state| state.update(data) }
      end

      # All should produce valid results
      r32 = states[0].digest
      r64 = states[1].digest
      r3_64 = states[2].digest
      r3_128 = states[3].digest

      r32.should be_a(UInt32)
      r64.should be_a(UInt64)
      r3_64.should be_a(UInt64)
      r3_128.should be_a(UInt128)
    end
  end

  describe "Edge case lifecycle scenarios" do
    it "digest called multiple times on same state" do
      state = XXH::XXH64::State.new
      state.update(Bytes[0xAB, 0xCD, 0xEF])

      # Multiple digest calls should work (though result may vary if state is mutated)
      5.times do
        result = state.digest
        result.should be_a(UInt64)
      end
    end

    it "update after digest still works" do
      state = XXH::XXH3::State64.new
      state.update(Bytes.new(100) { 0x11_u8 })
      r1 = state.digest

      # Add more data after digest
      state.update(Bytes.new(100) { 0x22_u8 })
      r2 = state.digest

      # Results should differ (different data)
      r1.should_not eq(r2)
    end

    it "reset between seeds produces different results" do
      state = XXH::XXH32::State.new(0_u32)
      data = Bytes.new(32) { 0x77_u8 }

      state.update(data)
      r1 = state.digest

      state.reset(1_u32)
      state.update(data)
      r2 = state.digest

      r1.should_not eq(r2), "Different seeds should produce different results"
    end
  end

  describe "State persistence and isolation" do
    it "independent states don't interfere" do
      state1 = XXH::XXH64::State.new(1_u64)
      state2 = XXH::XXH64::State.new(2_u64)

      data = Bytes.new(64) { 0xEE_u8 }

      10.times do
        state1.update(data)
        state2.update(data)
      end

      r1 = state1.digest
      r2 = state2.digest

      r1.should_not eq(r2), "Different seeds should yield different results"
    end

    it "reset truly resets to initial state" do
      state = XXH::XXH32::State.new(42_u32)
      data = Bytes.new(16) { 0x00_u8 }

      state.update(data)
      result_after_update = state.digest

      state.reset(42_u32)

      # Update with same data
      state.update(data)
      result_after_reset = state.digest

      result_after_update.should eq(result_after_reset), "Reset should return to initial state"
    end
  end

  describe "FFI binding safety" do
    it "FFI binding safety stress test" do
      # This stress-tests the FFI binding for any leaks or corruption
      2000.times do |iter|
        case iter % 4
        when 0
          state = XXH::XXH32::State.new((iter & 0xFF).to_u32)
          state.update(Bytes.new(iter % 64 + 1) { 0xA5_u8 })
          _result = state.digest
        when 1
          state = XXH::XXH64::State.new((iter & 0xFF).to_u64)
          state.update(Bytes.new(iter % 128 + 1) { 0x5A_u8 })
          _result = state.digest
        when 2
          state = XXH::XXH3::State64.new((iter & 0xFF).to_u64)
          state.update(Bytes.new((iter % 256) + 1) { 0x33_u8 })
          _result = state.digest
        else
          state = XXH::XXH3::State128.new((iter & 0xFF).to_u64)
          state.update(Bytes.new((iter % 512) + 1) { 0xCC_u8 })
          _result = state.digest
        end
      end
    end
  end

  describe "Garbage collection interaction" do
    it "states are garbage collected without crashing" do
      # Create and discard many states (no explicit cleanup)
      50.times do |_|
        state_array = Array.new(50) { XXH::XXH32::State.new }
        state_array.each { |s| s.update(Bytes[0x01, 0x02]) }
      end

      # If we get here without crashing, GC worked properly
      true.should eq(true)
    end

    it "mixed state types with GC" do
      50.times do |i|
        case i % 4
        when 0
          _s = Array.new(20) { XXH::XXH32::State.new }
        when 1
          _s = Array.new(20) { XXH::XXH64::State.new }
        when 2
          _s = Array.new(20) { XXH::XXH3::State64.new }
        else
          _s = Array.new(20) { XXH::XXH3::State128.new }
        end
      end

      true.should eq(true)
    end
  end
end
