require "../bindings/lib_xxh"
require "../common/errors"

module XXH
  module XXH3
    def self.canonical_from_hash(hash : ::XXH::Hash128) : Bytes
      canonical = LibXXH::XXH128_canonical_t.new
      LibXXH.XXH128_canonicalFromHash(canonical.to_unsafe, LibXXH::XXH128_hash_t.new(hash.low64, hash.high64))
      Bytes.new(16) { |i| canonical.digest[i] }
    end

    def self.hash_from_canonical(bytes : Bytes) : ::XXH::Hash128
      raise ArgumentError.new("Canonical XXH128 requires 16 bytes") unless bytes.size == 16
      canonical = LibXXH::XXH128_canonical_t.new
      16.times { |i| canonical.digest[i] = bytes[i] }
      c_hash = LibXXH.XXH128_hashFromCanonical(canonical.to_unsafe)
      ::XXH::Hash128.new(c_hash)
    end
  end
end
