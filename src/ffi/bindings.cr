# FFI bindings to the vendored xxHash C library
#
# This module provides Crystal FFI bindings to the C99 xxHash implementation.
# The actual hashing is delegated to the vendored C code in vendor/xxHash/.

require "c/libc"

{% if flag?(:win32) %}
  @[Link(ldflags: "vendor/xxHash/xxhash.c", framework: "Security")]
{% else %}
  @[Link(ldflags: "vendor/xxHash/xxhash.c")]
{% end %}

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

  fun versionNumber : UInt32

  # =========================================
  # XXH32 Functions
  # =========================================

  # One-shot hashing
  fun xxh32(input : Void*, length : LibC::Size, seed : XXH32_hash_t) : XXH32_hash_t

  # Streaming state management
  fun xxh32_createState : XXH32_state_t*
  fun xxh32_freeState(state : XXH32_state_t*) : XXH_errorcode
  fun xxh32_copyState(dst : XXH32_state_t*, src : XXH32_state_t*)
  fun xxh32_reset(state : XXH32_state_t*, seed : XXH32_hash_t) : XXH_errorcode
  fun xxh32_update(state : XXH32_state_t*, input : Void*, length : LibC::Size) : XXH_errorcode
  fun xxh32_digest(state : XXH32_state_t*) : XXH32_hash_t

  # Canonical representation conversions
  fun xxh32_canonicalFromHash(dst : XXH32_canonical_t*, hash : XXH32_hash_t)
  fun xxh32_hashFromCanonical(src : XXH32_canonical_t*) : XXH32_hash_t

  # =========================================
  # XXH64 Functions
  # =========================================

  # One-shot hashing
  fun xxh64(input : Void*, length : LibC::Size, seed : XXH64_hash_t) : XXH64_hash_t

  # Streaming state management
  fun xxh64_createState : XXH64_state_t*
  fun xxh64_freeState(state : XXH64_state_t*) : XXH_errorcode
  fun xxh64_copyState(dst : XXH64_state_t*, src : XXH64_state_t*)
  fun xxh64_reset(state : XXH64_state_t*, seed : XXH64_hash_t) : XXH_errorcode
  fun xxh64_update(state : XXH64_state_t*, input : Void*, length : LibC::Size) : XXH_errorcode
  fun xxh64_digest(state : XXH64_state_t*) : XXH64_hash_t

  # Canonical representation conversions
  fun xxh64_canonicalFromHash(dst : XXH64_canonical_t*, hash : XXH64_hash_t)
  fun xxh64_hashFromCanonical(src : XXH64_canonical_t*) : XXH64_hash_t

  # =========================================
  # XXH3 64-bit Functions
  # =========================================

  # One-shot hashing
  fun xxh3_64bits(input : Void*, length : LibC::Size) : XXH64_hash_t
  fun xxh3_64bits_withSeed(input : Void*, length : LibC::Size, seed : XXH64_hash_t) : XXH64_hash_t
  fun xxh3_64bits_withSecret(input : Void*, length : LibC::Size, secret : Void*, secretSize : LibC::Size) : XXH64_hash_t
  fun xxh3_64bits_withSecretandSeed(input : Void*, length : LibC::Size, secret : Void*, secretSize : LibC::Size, seed : XXH64_hash_t) : XXH64_hash_t

  # Streaming state management
  fun xxh3_createState : XXH3_state_t*
  fun xxh3_freeState(state : XXH3_state_t*) : XXH_errorcode
  fun xxh3_copyState(dst : XXH3_state_t*, src : XXH3_state_t*)
  fun xxh3_64bits_reset(state : XXH3_state_t*) : XXH_errorcode
  fun xxh3_64bits_reset_withSeed(state : XXH3_state_t*, seed : XXH64_hash_t) : XXH_errorcode
  fun xxh3_64bits_reset_withSecret(state : XXH3_state_t*, secret : Void*, secretSize : LibC::Size) : XXH_errorcode
  fun xxh3_64bits_reset_withSecretandSeed(state : XXH3_state_t*, secret : Void*, secretSize : LibC::Size, seed : XXH64_hash_t) : XXH_errorcode
  fun xxh3_64bits_update(state : XXH3_state_t*, input : Void*, length : LibC::Size) : XXH_errorcode
  fun xxh3_64bits_digest(state : XXH3_state_t*) : XXH64_hash_t

  # Secret generation
  fun xxh3_generateSecret(secretBuffer : Void*, secretSize : LibC::Size, customSeed : Void*, customSeedSize : LibC::Size) : XXH_errorcode
  fun xxh3_generateSecret_fromSeed(secretBuffer : Void*, seed : XXH64_hash_t)

  # =========================================
  # XXH3 128-bit Functions
  # =========================================

  # One-shot hashing
  fun xxh3_128bits(input : Void*, length : LibC::Size) : XXH128_hash_t
  fun xxh3_128bits_withSeed(input : Void*, length : LibC::Size, seed : XXH64_hash_t) : XXH128_hash_t
  fun xxh3_128bits_withSecret(input : Void*, length : LibC::Size, secret : Void*, secretSize : LibC::Size) : XXH128_hash_t
  fun xxh3_128bits_withSecretandSeed(input : Void*, length : LibC::Size, secret : Void*, secretSize : LibC::Size, seed : XXH64_hash_t) : XXH128_hash_t
  fun xxh128(input : Void*, length : LibC::Size, seed : XXH64_hash_t) : XXH128_hash_t

  # Streaming state management (uses same state as XXH3 64-bit)
  fun xxh3_128bits_reset(state : XXH3_state_t*) : XXH_errorcode
  fun xxh3_128bits_reset_withSeed(state : XXH3_state_t*, seed : XXH64_hash_t) : XXH_errorcode
  fun xxh3_128bits_reset_withSecret(state : XXH3_state_t*, secret : Void*, secretSize : LibC::Size) : XXH_errorcode
  fun xxh3_128bits_reset_withSecretandSeed(state : XXH3_state_t*, secret : Void*, secretSize : LibC::Size, seed : XXH64_hash_t) : XXH_errorcode
  fun xxh3_128bits_update(state : XXH3_state_t*, input : Void*, length : LibC::Size) : XXH_errorcode
  fun xxh3_128bits_digest(state : XXH3_state_t*) : XXH128_hash_t

  # 128-bit comparisons
  fun xxh128_isEqual(h1 : XXH128_hash_t, h2 : XXH128_hash_t) : Int32
  fun xxh128_cmp(h128_1 : Void*, h128_2 : Void*) : Int32

  # Canonical representation conversions
  fun xxh128_canonicalFromHash(dst : XXH128_canonical_t*, hash : XXH128_hash_t)
  fun xxh128_hashFromCanonical(src : XXH128_canonical_t*) : XXH128_hash_t

  # =========================================
  # Opaque State Types (defined internally in C)
  # =========================================

  struct XXH32_state_t
    # Opaque structure - defined in xxhash.c
    # Do not access directly
    bytes : UInt8[64] # Enough space for the largest state
  end

  struct XXH64_state_t
    # Opaque structure - defined in xxhash.c
    bytes : UInt8[128] # Enough space for the largest state
  end

  struct XXH3_state_t
    # Opaque structure - defined in xxhash.c
    # Requires 64-byte alignment
    bytes : UInt8[512] # Enough space for XXH3_state_s
  end
end
