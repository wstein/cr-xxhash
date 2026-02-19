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

  describe "#copy" do
    it "creates independent deep copy of state" do
      original = XXH::XXH64::State.new(0x9876543210FEDCBA_u64)
      original.update("initial data")
      
      # Copy the state
      copy = original.copy
      
      # Verify copy is a different object
      copy.should_not be(original)
      
      # Verify both states produce the same hash after copying
      original.digest.should eq(copy.digest)
    end

    it "copy can be mutated independently" do
      original = XXH::XXH64::State.new
      original.update("base")
      
      # Create a copy
      copy = original.copy
      
      # Mutate the copy with additional data
      copy.update(" extension")
      
      # Verify original and copy produce different hashes
      original.digest.should_not eq(copy.digest)
      
      # Verify original still matches expected value
      original.digest.should eq(XXH::XXH64.hash("base"))
    end

    it "multiple levels of copying work correctly" do
      state1 = XXH::XXH64::State.new
      state1.update("data")
      
      # Create copy 1
      state2 = state1.copy
      
      # Create copy 2 from copy 1
      state3 = state2.copy
      
      # All should have identical digests at this point
      state1.digest.should eq(state2.digest)
      state2.digest.should eq(state3.digest)
      
      # Mutate state3
      state3.update("more")
      
      # Now state3 should differ
      state1.digest.should_not eq(state3.digest)
      state2.digest.should_not eq(state3.digest)
      state1.digest.should eq(state2.digest)
    end
  end
end
