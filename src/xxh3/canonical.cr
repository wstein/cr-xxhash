require "../bindings/lib_xxh"
require "../common/errors"

module XXH
  module XXH3
    def self.canonical_from_hash(hash : ::XXH::Hash128) : Bytes
      canonical = LibXXH::XXH128_canonical_t.new
      hash_t = LibXXH::XXH128_hash_t.new
      hash_t.low64 = hash.low64
      hash_t.high64 = hash.high64
      LibXXH.XXH128_canonicalFromHash(pointerof(canonical), hash_t)
      Bytes.new(16) { |i| canonical.digest[i] }
    end

    def self.hash_from_canonical(bytes : Bytes) : ::XXH::Hash128
      raise ArgumentError.new("Canonical XXH128 requires 16 bytes") unless bytes.size == 16
      canonical = LibXXH::XXH128_canonical_t.new
      16.times { |i| canonical.digest[i] = bytes[i] }
      c_hash = LibXXH.XXH128_hashFromCanonical(pointerof(canonical))
      ::XXH::Hash128.new(c_hash)
    end
  end
end
