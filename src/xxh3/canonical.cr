require "../bindings/lib_xxh"
require "../common/errors"

module XXH
  module XXH3
    def self.canonical_from_hash(hash : UInt128) : Bytes
      canonical = LibXXH::XXH128_canonical_t.new
      hash_t = hash.to_c_hash
      LibXXH.XXH128_canonicalFromHash(pointerof(canonical), hash_t)
      Bytes.new(16) { |i| canonical.digest[i] }
    end

    def self.hash_from_canonical(bytes : Bytes) : UInt128
      raise ArgumentError.new("Canonical XXH128 requires 16 bytes") unless bytes.size == 16
      canonical = LibXXH::XXH128_canonical_t.new
      16.times { |i| canonical.digest[i] = bytes[i] }
      c_hash = LibXXH.XXH128_hashFromCanonical(pointerof(canonical))
      UInt128.from_c_hash(c_hash)
    end
  end
end
