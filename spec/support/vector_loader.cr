require "json"

module XXH::VectorLoader
  extend self

  # Load fixtures lazily (cached per-file)
  @@fixture_cache : Hash(String, JSON::Any)? = nil
  @@sanity_buffer : Bytes? = nil
  @@sanity_buffer_max_len : Int32? = nil

  # Helper to parse hex strings (strips 0x prefix)
  private def parse_hex_string(s : String) : UInt64
    s.starts_with?("0x") ? s[2..].to_u64(16) : s.to_u64(16)
  end

  # Load a per-algorithm fixture file (e.g. "xxh32") and cache it.
  # New fixture shape: { "vectors": [ ... ], "sanity_buffer_max_len": N }
  private def load_fixture(name : String) : JSON::Any
    cache = (@@fixture_cache ||= {} of String => JSON::Any)
    return cache[name] if cache.has_key?(name)

    path = File.expand_path("../fixtures/vendor_vectors_#{name}.json", __DIR__)
    unless File.exists?(path)
      raise Error.new("Fixture not found: #{path}. Run: crystal scripts/generate_vectors.cr")
    end
    parsed = JSON.parse(File.read(path))
    cache[name] = parsed
    parsed
  end

  # Load metadata (sanity_buffer_max_len) from the first available per-algorithm fixture
  private def load_meta : Int32
    return @@sanity_buffer_max_len.not_nil! if @@sanity_buffer_max_len

    %w[xxh32 xxh64 xxh3 xxh128].each do |name|
      begin
        fixture = load_fixture(name)
        @@sanity_buffer_max_len = fixture.as_h["sanity_buffer_max_len"].as_i.to_i32
        return @@sanity_buffer_max_len.not_nil!
      rescue
        next
      end
    end

    @@sanity_buffer_max_len = 4160
    return @@sanity_buffer_max_len.not_nil!
  end

  # Get the sanity buffer (cached after first load)
  def sanity_buffer(len : Int) : Bytes
    # Load max_len from metadata if not already cached
    unless @@sanity_buffer_max_len
      @@sanity_buffer_max_len = load_meta
    end

    max_len = @@sanity_buffer_max_len.not_nil!
    raise ArgumentError.new("len must be <= #{max_len}") if len > max_len

    # Generate on demand using the same algorithm as vendor
    buf = Bytes.new(len)
    byte_gen = 2654435761_u64
    (0...len).each do |i|
      buf[i] = ((byte_gen >> 56) & 0xFF).to_u8
      byte_gen = ((byte_gen.to_u128 * 11400714785074694797_u128) & 0xFFFFFFFFFFFFFFFF_u128).to_u64
    end
    buf
  end

  # Get XXH32 test vectors as {len, seed} => result
  def xxh32_vectors : Hash(Tuple(Int32, UInt32), UInt32)
    result = {} of Tuple(Int32, UInt32) => UInt32
    # support new object-shaped fixtures { vectors: [...], sanity_buffer_max_len: N }
    fixture = load_fixture("xxh32")
    fixture["vectors"].as_a.each do |v|
      len = v["len"].as_i.to_i32
      seed = parse_hex_string(v["seed"].as_s).to_u32
      result_val = parse_hex_string(v["result"].as_s).to_u32
      result[{len, seed}] = result_val
    end
    result
  end

  # Get XXH64 test vectors as {len, seed} => result
  def xxh64_vectors : Hash(Tuple(Int32, UInt64), UInt64)
    result = {} of Tuple(Int32, UInt64) => UInt64
    fixture = load_fixture("xxh64")
    arr = fixture["vectors"].as_a
    arr.each do |v|
      len = v["len"].as_i.to_i32
      seed = parse_hex_string(v["seed"].as_s)
      result_val = parse_hex_string(v["result"].as_s)
      result[{len, seed}] = result_val
    end
    result
  end

  # Get XXH3-64 test vectors as {len, seed} => result
  def xxh3_vectors : Hash(Tuple(Int32, UInt64), UInt64)
    result = {} of Tuple(Int32, UInt64) => UInt64
    fixture = load_fixture("xxh3")
    arr = fixture["vectors"].as_a

    arr.each do |v|
      len = v["len"].as_i.to_i32
      seed = parse_hex_string(v["seed"].as_s)
      result_val = parse_hex_string(v["result"].as_s)
      result[{len, seed}] = result_val
    end
    result
  end

  # Get XXH128 test vectors as {len, seed} => {high, low}
  def xxh128_vectors : Hash(Tuple(Int32, UInt64), NamedTuple(high: UInt64, low: UInt64))
    result = {} of Tuple(Int32, UInt64) => NamedTuple(high: UInt64, low: UInt64)
    fixture = load_fixture("xxh128")
    arr = fixture["vectors"].as_a
    arr.each do |v|
      len = v["len"].as_i.to_i32
      seed = parse_hex_string(v["seed"].as_s)
      high = parse_hex_string(v["high"].as_s)
      low = parse_hex_string(v["low"].as_s)
      result[{len, seed}] = {high: high, low: low}
    end
    result
  end
end
