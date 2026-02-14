require "../bindings/lib_xxh"
require "../common/errors"

module XXH
  module XXH32
    def self.canonical_from_hash(hash : UInt32) : Bytes
      canonical = LibXXH::XXH32_canonical_t.new
      LibXXH.XXH32_canonicalFromHash(canonical.to_unsafe, hash)
      Bytes.new(4) { |i| canonical.digest[i] }
    end

    def self.hash_from_canonical(bytes : Bytes) : UInt32
      raise ArgumentError.new("Canonical XXH32 requires 4 bytes") unless bytes.size == 4
      canonical = LibXXH::XXH32_canonical_t.new
      4.times { |i| canonical.digest[i] = bytes[i] }
      LibXXH.XXH32_hashFromCanonical(canonical.to_unsafe)
    end
  end
end
