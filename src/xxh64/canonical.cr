require "../bindings/lib_xxh"
require "../common/errors"

module XXH
  module XXH64
    def self.canonical_from_hash(hash : UInt64) : Bytes
      canonical = LibXXH::XXH64_canonical_t.new
      LibXXH.XXH64_canonicalFromHash(pointerof(canonical), hash)
      Bytes.new(8) { |i| canonical.digest[i] }
    end

    def self.hash_from_canonical(bytes : Bytes) : UInt64
      raise ArgumentError.new("Canonical XXH64 requires 8 bytes") unless bytes.size == 8
      canonical = LibXXH::XXH64_canonical_t.new
      8.times { |i| canonical.digest[i] = bytes[i] }
      LibXXH.XXH64_hashFromCanonical(pointerof(canonical))
    end
  end
end
