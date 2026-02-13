@[Link(ldflags: "#{__DIR__}/../../vendor/xxHash/xxhash.o")]
lib LibXXH
  # =========================================
  # Type Definitions
  # =========================================

  # Error codes
  enum XXH_errorcode : Int32
    XXH_OK    = 0
    XXH_ERROR = 1
  end

  # 32-bit hash type
  alias XXH32_hash_t = UInt32

  # 64-bit hash type
  alias XXH64_hash_t = UInt64

  # 128-bit hash type
  struct XXH128_hash_t
    low64 : XXH64_hash_t
    high64 : XXH64_hash_t
  end

  # Canonical representations (big-endian storage)
  struct XXH32_canonical_t
    digest : UInt8[4]
  end

  struct XXH64_canonical_t
    digest : UInt8[8]
  end

  struct XXH128_canonical_t
    digest : UInt8[16]
  end

  # =========================================
  # Version Information
  # =========================================

  fun versionNumber = "XXH_versionNumber" : UInt32

  # =========================================
  # XXH32 Functions
  # =========================================

  # One-shot hashing
  fun XXH32(input : Void*, length : LibC::SizeT, seed : XXH32_hash_t) : XXH32_hash_t

  # Streaming state management
  fun XXH32_createState : XXH32_state_t*
  fun XXH32_freeState(state : XXH32_state_t*) : XXH_errorcode
  fun XXH32_copyState(dst : XXH32_state_t*, src : XXH32_state_t*)
  fun XXH32_reset(state : XXH32_state_t*, seed : XXH32_hash_t) : XXH_errorcode
  fun XXH32_update(state : XXH32_state_t*, input : Void*, length : LibC::SizeT) : XXH_errorcode
  fun XXH32_digest(state : XXH32_state_t*) : XXH32_hash_t

  # Canonical representation conversions
  fun XXH32_canonicalFromHash(dst : XXH32_canonical_t*, hash : XXH32_hash_t)
  fun XXH32_hashFromCanonical(src : XXH32_canonical_t*) : XXH32_hash_t

  # =========================================
  # XXH64 Functions
  # =========================================

  # One-shot hashing
  fun XXH64(input : Void*, length : LibC::SizeT, seed : XXH64_hash_t) : XXH64_hash_t

  # Streaming state management
  fun XXH64_createState : XXH64_state_t*
  fun XXH64_freeState(state : XXH64_state_t*) : XXH_errorcode
  fun XXH64_copyState(dst : XXH64_state_t*, src : XXH64_state_t*)
  fun XXH64_reset(state : XXH64_state_t*, seed : XXH64_hash_t) : XXH_errorcode
  fun XXH64_update(state : XXH64_state_t*, input : Void*, length : LibC::SizeT) : XXH_errorcode
  fun XXH64_digest(state : XXH64_state_t*) : XXH64_hash_t

  # Canonical representation conversions
  fun XXH64_canonicalFromHash(dst : XXH64_canonical_t*, hash : XXH64_hash_t)
  fun XXH64_hashFromCanonical(src : XXH64_canonical_t*) : XXH64_hash_t

  # =========================================
  # XXH3 64-bit Functions
  # =========================================

  # One-shot hashing
  fun XXH3_64bits(input : Void*, length : LibC::SizeT) : XXH64_hash_t
  fun XXH3_64bits_withSeed(input : Void*, length : LibC::SizeT, seed : XXH64_hash_t) : XXH64_hash_t
  fun XXH3_64bits_withSecret(input : Void*, length : LibC::SizeT, secret : Void*, secretSize : LibC::SizeT) : XXH64_hash_t
  fun XXH3_64bits_withSecretandSeed(input : Void*, length : LibC::SizeT, secret : Void*, secretSize : LibC::SizeT, seed : XXH64_hash_t) : XXH64_hash_t

  # Streaming state management
  fun XXH3_createState : XXH3_state_t*
  fun XXH3_freeState(state : XXH3_state_t*) : XXH_errorcode
  fun XXH3_copyState(dst : XXH3_state_t*, src : XXH3_state_t*)
  fun XXH3_64bits_reset(state : XXH3_state_t*) : XXH_errorcode
  fun XXH3_64bits_reset_withSeed(state : XXH3_state_t*, seed : XXH64_hash_t) : XXH_errorcode
  fun XXH3_64bits_reset_withSecret(state : XXH3_state_t*, secret : Void*, secretSize : LibC::SizeT) : XXH_errorcode
  fun XXH3_64bits_reset_withSecretandSeed(state : XXH3_state_t*, secret : Void*, secretSize : LibC::SizeT, seed : XXH64_hash_t) : XXH_errorcode
  fun XXH3_64bits_update(state : XXH3_state_t*, input : Void*, length : LibC::SizeT) : XXH_errorcode
  fun XXH3_64bits_digest(state : XXH3_state_t*) : XXH64_hash_t

  # Secret generation
  fun XXH3_generateSecret(secretBuffer : Void*, secretSize : LibC::SizeT, customSeed : Void*, customSeedSize : LibC::SizeT) : XXH_errorcode
  fun XXH3_generateSecret_fromSeed(secretBuffer : Void*, seed : XXH64_hash_t)

  # =========================================
  # XXH3 128-bit Functions
  # =========================================

  # One-shot hashing
  fun XXH3_128bits(input : Void*, length : LibC::SizeT) : XXH128_hash_t
  fun XXH3_128bits_withSeed(input : Void*, length : LibC::SizeT, seed : XXH64_hash_t) : XXH128_hash_t
  fun XXH3_128bits_withSecret(input : Void*, length : LibC::SizeT, secret : Void*, secretSize : LibC::SizeT) : XXH128_hash_t
  fun XXH3_128bits_withSecretandSeed(input : Void*, length : LibC::SizeT, secret : Void*, secretSize : LibC::SizeT, seed : XXH64_hash_t) : XXH128_hash_t
  fun XXH128(input : Void*, length : LibC::SizeT, seed : XXH64_hash_t) : XXH128_hash_t

  # Streaming state management (uses same state as XXH3 64-bit)
  fun XXH3_128bits_reset(state : XXH3_state_t*) : XXH_errorcode
  fun XXH3_128bits_reset_withSeed(state : XXH3_state_t*, seed : XXH64_hash_t) : XXH_errorcode
  fun XXH3_128bits_reset_withSecret(state : XXH3_state_t*, secret : Void*, secretSize : LibC::SizeT) : XXH_errorcode
  fun XXH3_128bits_reset_withSecretandSeed(state : XXH3_state_t*, secret : Void*, secretSize : LibC::SizeT, seed : XXH64_hash_t) : XXH_errorcode
  fun XXH3_128bits_update(state : XXH3_state_t*, input : Void*, length : LibC::SizeT) : XXH_errorcode
  fun XXH3_128bits_digest(state : XXH3_state_t*) : XXH128_hash_t

  # 128-bit comparisons
  fun XXH128_isEqual(h1 : XXH128_hash_t, h2 : XXH128_hash_t) : Int32
  fun XXH128_cmp(h128_1 : Void*, h128_2 : Void*) : Int32

  # Canonical representation conversions
  fun XXH128_canonicalFromHash(dst : XXH128_canonical_t*, hash : XXH128_hash_t)
  fun XXH128_hashFromCanonical(src : XXH128_canonical_t*) : XXH128_hash_t

  # =========================================
  # Opaque State Types (defined internally in C)
  # =========================================

  struct XXH32_state_t
    bytes : UInt8[64]
  end

  struct XXH64_state_t
    bytes : UInt8[128]
  end

  struct XXH3_state_t
    bytes : UInt8[512]
  end
end
