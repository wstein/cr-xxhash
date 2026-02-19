require "./spec_helper"

describe XXH::XXH3::State64 do
  it "creates state with default seed" do
    state = XXH::XXH3::State64.new
    state.should be_a(XXH::XXH3::State64)
  end

  it "update returns self for chaining" do
    state = XXH::XXH3::State64.new
    result = state.update("test".to_slice)
    result.should be(state)
  end

  it "accepts both String and Bytes inputs (State64) and produces identical digests" do
    data = "interchangeable input"
    bytes = Bytes.new(data.bytesize) { |i| data.to_slice[i] }

    s_str = XXH::XXH3::State64.new
    s_str.update(data)
    d_str = s_str.digest

    s_bytes = XXH::XXH3::State64.new
    s_bytes.update(bytes)
    d_bytes = s_bytes.digest

    d_str.should eq(d_bytes)
    d_str.should eq(XXH::XXH3.hash64(data))
  end

  it "update returns self for String and Bytes (State64)" do
    state = XXH::XXH3::State64.new
    state.update("foo").should be(state)
    state.update(Bytes[0x66, 0x6F, 0x6F]).should be(state)
  end

  it "digest matches one-shot hash" do
    input = "test data for streaming"

    state = XXH::XXH3::State64.new
    state.update(input.to_slice)
    streaming_hash = state.digest

    oneshot_hash = XXH::XXH3.hash64(input)

    streaming_hash.should eq(oneshot_hash)
  end

  it "reset allows reuse" do
    state = XXH::XXH3::State64.new
    state.update("first".to_slice)
    state.reset
    state.update("second".to_slice)
    hash = state.digest
    expected = XXH::XXH3.hash64("second")
    hash.should eq(expected)
  end

  it "seeded state matches seeded one-shot" do
    data = "test"
    seed = 0x123456789ABCDEF0_u64

    state = XXH::XXH3::State64.new(seed)
    state.update(data.to_slice)
    state_hash = state.digest

    oneshot_hash = XXH::XXH3.hash64(data, seed)

    state_hash.should eq(oneshot_hash)
  end

  it "handles 1MB input in chunks" do
    large_data = incremental_bytes(1_000_000)

    state = XXH::XXH3::State64.new
    chunk_size = 8192
    i = 0
    while i < large_data.size
      chunk = large_data[i...Math.min(i + chunk_size, large_data.size)]
      state.update(chunk)
      i += chunk_size
    end
    streaming_hash = state.digest

    oneshot_hash = XXH::XXH3.hash64(large_data)

    streaming_hash.should eq(oneshot_hash)
  end
end

describe XXH::XXH3::State128 do
  it "creates state with default seed" do
    state = XXH::XXH3::State128.new
    state.should be_a(XXH::XXH3::State128)
  end

  it "update returns self for chaining" do
    state = XXH::XXH3::State128.new
    result = state.update("test".to_slice)
    result.should be(state)
  end

  it "accepts both String and Bytes inputs (State128) and produces identical digests" do
    data = "interchangeable input"
    bytes = Bytes.new(data.bytesize) { |i| data.to_slice[i] }

    s_str = XXH::XXH3::State128.new
    s_str.update(data)
    d_str = s_str.digest

    s_bytes = XXH::XXH3::State128.new
    s_bytes.update(bytes)
    d_bytes = s_bytes.digest

    d_str.should eq(d_bytes)
    d_str.should eq(XXH::XXH3.hash128(data))
  end

  it "update returns self for String and Bytes (State128)" do
    state = XXH::XXH3::State128.new
    state.update("foo").should be(state)
    state.update(Bytes[0x66, 0x6F, 0x6F]).should be(state)
  end

  it "digest returns Hash128" do
    state = XXH::XXH3::State128.new
    state.update("test".to_slice)
    result = state.digest
    result.should be_a(UInt128)
  end

  it "digest matches one-shot hash" do
    input = "test data for streaming"

    state = XXH::XXH3::State128.new
    state.update(input.to_slice)
    streaming_hash = state.digest

    oneshot_hash = XXH::XXH3.hash128(input)

    streaming_hash.should eq(oneshot_hash)
  end

  it "reset allows reuse" do
    state = XXH::XXH3::State128.new
    state.update("first".to_slice)
    state.reset
    state.update("second".to_slice)
    hash = state.digest
    expected = XXH::XXH3.hash128("second")
    hash.should eq(expected)
  end

  it "seeded state matches seeded one-shot" do
    data = "test"
    seed = 0x123456789ABCDEF0_u64

    state = XXH::XXH3::State128.new(seed)
    state.update(data.to_slice)
    state_hash = state.digest

    oneshot_hash = XXH::XXH3.hash128(data, seed)

    state_hash.should eq(oneshot_hash)
  end

  it "handles 1MB input in chunks" do
    large_data = incremental_bytes(1_000_000)

    state = XXH::XXH3::State128.new
    chunk_size = 8192
    i = 0
    while i < large_data.size
      chunk = large_data[i...Math.min(i + chunk_size, large_data.size)]
      state.update(chunk)
      i += chunk_size
    end
    streaming_hash = state.digest

    oneshot_hash = XXH::XXH3.hash128(large_data)

    streaming_hash.should eq(oneshot_hash)
  end

  it "produces different results from State64" do
    data = "test"

    state64 = XXH::XXH3::State64.new
    state64.update(data.to_slice)
    hash64 = state64.digest

    state128 = XXH::XXH3::State128.new
    state128.update(data.to_slice)
    hash128 = state128.digest

    (hash64 != hash128.high64).should be_true
    (hash64 != hash128.low64).should be_true
  end

  it "copy creates independent deep copy of State64" do
    original = XXH::XXH3::State64.new(0x1234567890ABCDEF_u64)
    original.update("first part")
    
    # Copy the state
    copy = original.copy
    
    # Verify copy is a different object
    copy.should_not be(original)
    
    # Verify both states produce the same hash after copying
    original.digest.should eq(copy.digest)
  end

  it "copy of State64 can be mutated independently" do
    original = XXH::XXH3::State64.new
    original.update("test data")
    
    # Create a copy
    copy = original.copy
    
    # Mutate the copy with additional data
    copy.update(" more data")
    
    # Verify original and copy produce different hashes
    original.digest.should_not eq(copy.digest)
    
    # Verify original still matches expected value
    original.digest.should eq(XXH::XXH3.hash64("test data"))
  end

  it "copy of State128 preserves state correctly" do
    original = XXH::XXH3::State128.new(0x9876543210FEDCBA_u64)
    original.update("test content")
    
    # Copy the state
    copy = original.copy
    
    # Verify copy is a different object
    copy.should_not be(original)
    
    # Verify both produce identical hash values
    original.digest.should eq(copy.digest)
  end

  it "copy of State128 can be mutated independently" do
    original = XXH::XXH3::State128.new
    original.update("initial data")
    
    # Create a copy
    copy = original.copy
    
    # Mutate the copy
    copy.update(" appended")
    
    # Verify they produce different results
    original.digest.should_not eq(copy.digest)
    
    # Verify original matches expected value
    original.digest.should eq(XXH::XXH3.hash128("initial data"))
  end

  it "multiple levels of copying work correctly" do
    state1 = XXH::XXH3::State64.new
    state1.update("data1")
    
    # Create copy 1
    state2 = state1.copy
    
    # Create copy 2 from copy 1
    state3 = state2.copy
    
    # All should have identical digests at this point
    state1.digest.should eq(state2.digest)
    state2.digest.should eq(state3.digest)
    
    # Mutate state3
    state3.update("extra")
    
    # Now state3 should differ
    state1.digest.should_not eq(state3.digest)
    state2.digest.should_not eq(state3.digest)
    state1.digest.should eq(state2.digest)
  end

end
