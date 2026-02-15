require "./spec_helper"

describe XXH::XXH64::State do
  describe "#initialize" do
    it "creates state with default seed (0)" do
      state = XXH::XXH64::State.new
      state.should be_a(XXH::XXH64::State)
    end

    it "creates state with custom seed" do
      state = XXH::XXH64::State.new(0x9e3779b185ebca87_u64)
      state.should be_a(XXH::XXH64::State)
    end
  end

  describe "#update" do
    it "accepts Bytes/Slice input" do
      state = XXH::XXH64::State.new
      result = state.update("test".to_slice)
      result.should be(state)
    end

    it "accepts both String and Bytes inputs and produces identical digests" do
      data = "interchange"
      bytes = Bytes.new(data.bytesize) { |i| data.to_slice[i] }

      s_str = XXH::XXH64::State.new
      s_str.update(data)
      d_str = s_str.digest

      s_bytes = XXH::XXH64::State.new
      s_bytes.update(bytes)
      d_bytes = s_bytes.digest

      d_str.should eq(d_bytes)
      d_str.should eq(XXH::XXH64.hash(data))
    end

    it "returns self for method chaining" do
      state = XXH::XXH64::State.new
      result = state.update("hello".to_slice).update("world".to_slice)
      result.should be(state)
    end

    it "update returns self for both String and Bytes" do
      state = XXH::XXH64::State.new
      state.update("foo").should be(state)
      state.update(Bytes[0x66, 0x6F, 0x6F]).should be(state)
    end

    it "can be called multiple times" do
      state = XXH::XXH64::State.new
      state.update("Hello, ".to_slice)
      state.update("world!".to_slice)
      hash = state.digest
      expected = XXH::XXH64.hash("Hello, world!")
      hash.should eq(expected)
    end
  end

  describe "#digest" do
    it "returns UInt64 hash" do
      state = XXH::XXH64::State.new
      state.update("test".to_slice)
      result = state.digest
      result.should be_a(UInt64)
    end

    it "matches one-shot hash" do
      input = "test data for streaming"

      state = XXH::XXH64::State.new
      state.update(input.to_slice)
      streaming_hash = state.digest

      oneshot_hash = XXH::XXH64.hash(input)

      streaming_hash.should eq(oneshot_hash)
    end

    it "can be called multiple times without changing state" do
      state = XXH::XXH64::State.new
      state.update("test".to_slice)
      digest1 = state.digest
      digest2 = state.digest
      digest1.should eq(digest2)
    end

    it "produces consistent results across multiple states" do
      data = "consistency test"

      state1 = XXH::XXH64::State.new
      state1.update(data.to_slice)

      state2 = XXH::XXH64::State.new
      state2.update(data.to_slice)

      state1.digest.should eq(state2.digest)
    end
  end

  describe "#reset" do
    it "resets state for reuse" do
      state = XXH::XXH64::State.new
      state.update("first".to_slice)
      state.reset
      state.update("second".to_slice)
      hash = state.digest
      expected = XXH::XXH64.hash("second")
      hash.should eq(expected)
    end

    it "can reset with new seed" do
      state = XXH::XXH64::State.new(0_u64)
      state.update("test".to_slice)
      state.reset(0x9e3779b185ebca87_u64)
      state.update("test".to_slice)
      hash = state.digest
      expected = XXH::XXH64.hash("test", 0x9e3779b185ebca87_u64)
      hash.should eq(expected)
    end

    it "returns self for method chaining" do
      state = XXH::XXH64::State.new
      result = state.reset(0_u64)
      result.should be(state)
    end

    it "allows state reuse after reset" do
      state = XXH::XXH64::State.new

      state.update("first".to_slice)
      hash1 = state.digest

      state.reset
      state.update("second".to_slice)
      hash2 = state.digest

      hash1.should eq(XXH::XXH64.hash("first"))
      hash2.should eq(XXH::XXH64.hash("second"))
      hash1.should_not eq(hash2)
    end
  end

  describe "#dispose" do
    it "releases native state" do
      state = XXH::XXH64::State.new
      state.update("test".to_slice)
      state.dispose
      # No error should be raised
    end

    it "can be called safely multiple times" do
      state = XXH::XXH64::State.new
      state.dispose
      state.dispose # Should not raise
    end
  end

  describe "memory management" do
    it "doesn't leak memory with automatic cleanup" do
      100.times do
        state = XXH::XXH64::State.new
        state.update("test".to_slice)
        state.digest
      end
    end
  end

  describe "seeded state" do
    it "produces different hash for different seeds" do
      data = "same data"

      state1 = XXH::XXH64::State.new(0_u64)
      state1.update(data.to_slice)
      hash1 = state1.digest

      state2 = XXH::XXH64::State.new(1_u64)
      state2.update(data.to_slice)
      hash2 = state2.digest

      hash1.should_not eq(hash2)
    end

    it "seeded state matches seeded one-shot" do
      data = "test"
      seed = 0x9e3779b185ebca87_u64

      state = XXH::XXH64::State.new(seed)
      state.update(data.to_slice)
      state_hash = state.digest

      oneshot_hash = XXH::XXH64.hash(data, seed)

      state_hash.should eq(oneshot_hash)
    end
  end

  describe "large input streaming" do
    it "handles 1MB input in chunks" do
      large_data = incremental_bytes(1_000_000)

      state = XXH::XXH64::State.new
      chunk_size = 8192
      i = 0
      while i < large_data.size
        chunk = large_data[i...Math.min(i + chunk_size, large_data.size)]
        state.update(chunk)
        i += chunk_size
      end
      streaming_hash = state.digest

      oneshot_hash = XXH::XXH64.hash(large_data)

      streaming_hash.should eq(oneshot_hash)
    end

    it "handles single byte updates" do
      data = "test data"

      state = XXH::XXH64::State.new
      data.each_byte { |byte| state.update(Bytes[byte]) }
      streaming_hash = state.digest

      oneshot_hash = XXH::XXH64.hash(data)

      streaming_hash.should eq(oneshot_hash)
    end
  end

  describe "comparison with XXH32 state" do
    it "produces different results from XXH32" do
      data = "test"

      state32 = XXH::XXH32::State.new
      state32.update(data.to_slice)

      state64 = XXH::XXH64::State.new
      state64.update(data.to_slice)

      state32.digest.should_not eq(state64.digest)
    end
  end
end
