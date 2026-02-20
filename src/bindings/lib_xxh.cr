@[Link(ldflags: "#{__DIR__}/../../vendor/xxhash-wrapper/build/libxxh3_wrapper_static.a")]
lib LibXXH
  enum XXHErrorcode : Int32
    XXH_OK    = 0
    XXH_ERROR = 1
  end

  alias XXH32HashT = UInt32
  alias XXH64HashT = UInt64

  struct XXH128_hash_t
    low64 : XXH64HashT
    high64 : XXH64HashT
  end

  struct XXH3_128_hash_t
    high : UInt64
    low : UInt64
  end

  struct XXH32_canonical_t
    digest : UInt8[4]
  end

  struct XXH64_canonical_t
    digest : UInt8[8]
  end

  struct XXH128_canonical_t
    digest : UInt8[16]
  end

  fun versionNumber = "XXH_versionNumber" : UInt32

  fun XXH32 = "xxh32"(input : Void*, length : LibC::SizeT, seed : XXH32HashT) : XXH32HashT
  fun XXH32_createState = "xxh3_createState" : XXH32_state_t*
  fun XXH32_freeState = "xxh3_freeState"(state : XXH32_state_t*) : Nil
  fun XXH32_reset = "xxh32_reset"(state : XXH32_state_t*, seed : XXH32HashT) : Nil
  fun XXH32_update = "xxh32_update"(state : XXH32_state_t*, input : Void*, length : LibC::SizeT) : Int32
  fun XXH32_digest = "xxh32_digest"(state : XXH32_state_t*) : XXH32HashT

  fun XXH32_canonicalFromHash(dst : XXH32_canonical_t*, hash : XXH32HashT)
  fun XXH32_hashFromCanonical(src : XXH32_canonical_t*) : XXH32HashT

  fun XXH64 = "xxh64"(input : Void*, length : LibC::SizeT, seed : XXH64HashT) : XXH64HashT
  fun XXH64_createState = "xxh3_createState" : XXH64_state_t*
  fun XXH64_freeState = "xxh3_freeState"(state : XXH64_state_t*) : Nil
  fun XXH64_reset = "xxh64_reset"(state : XXH64_state_t*, seed : XXH64HashT) : Nil
  fun XXH64_update = "xxh64_update"(state : XXH64_state_t*, input : Void*, length : LibC::SizeT) : Int32
  fun XXH64_digest = "xxh64_digest"(state : XXH64_state_t*) : XXH64HashT

  fun XXH64_canonicalFromHash(dst : XXH64_canonical_t*, hash : XXH64HashT)
  fun XXH64_hashFromCanonical(src : XXH64_canonical_t*) : XXH64HashT

  fun XXH3_64bits_withSeed = "xxh3_64_scalar"(input : Void*, length : LibC::SizeT, seed : XXH64HashT) : XXH64HashT
  fun XXH3_64bits = "xxh3_64_scalar_unseeded"(input : Void*, length : LibC::SizeT) : XXH64HashT
  fun XXH3_64bits_withSecret = "xxh3_64_withSecret"(input : Void*, length : LibC::SizeT, secret : Void*, secretSize : LibC::SizeT) : XXH64HashT

  fun XXH3_createState = "xxh3_createState" : XXH3_state_t*
  fun XXH3_freeState = "xxh3_freeState"(state : XXH3_state_t*) : Nil
  fun XXH3_copyState = "xxh3_copyState"(dst : XXH3_state_t*, src : XXH3_state_t*) : Int32
  fun XXH3_64bits_reset = "xxh3_64_reset"(state : XXH3_state_t*, seed : XXH64HashT) : Nil
  fun XXH3_64bits_reset_withSeed = "xxh3_64_reset"(state : XXH3_state_t*, seed : XXH64HashT) : Nil
  fun XXH3_64bits_reset_withSecret = "xxh3_64_reset_withSecret"(state : XXH3_state_t*, secret : Void*, secretSize : LibC::SizeT) : Nil
  fun XXH3_64bits_update = "xxh3_64_update"(state : XXH3_state_t*, input : Void*, length : LibC::SizeT) : Int32
  fun XXH3_64bits_digest = "xxh3_64_digest"(state : XXH3_state_t*) : XXH64HashT

  fun XXH3_generateSecret = "xxh3_generateSecret"(secretBuffer : Void*, secretSize : LibC::SizeT, seed : XXH64HashT) : Nil

  fun XXH3_128bits_withSeed = "xxh3_128_scalar"(input : Void*, length : LibC::SizeT, seed : XXH64HashT) : XXH3_128_hash_t
  fun XXH3_128bits = "xxh3_128_scalar_unseeded"(input : Void*, length : LibC::SizeT) : XXH3_128_hash_t
  fun XXH3_128bits_withSecret = "xxh3_128_withSecret"(input : Void*, length : LibC::SizeT, secret : Void*, secretSize : LibC::SizeT) : XXH3_128_hash_t

  fun XXH3_128bits_reset = "xxh3_128_reset"(state : XXH3_state_t*, seed : XXH64HashT) : Nil
  fun XXH3_128bits_reset_withSeed = "xxh3_128_reset"(state : XXH3_state_t*, seed : XXH64HashT) : Nil
  fun XXH3_128bits_reset_withSecret = "xxh3_128_reset_withSecret"(state : XXH3_state_t*, secret : Void*, secretSize : LibC::SizeT) : Nil
  fun XXH3_128bits_update = "xxh3_128_update"(state : XXH3_state_t*, input : Void*, length : LibC::SizeT) : Int32
  fun XXH3_128bits_digest = "xxh3_128_digest"(state : XXH3_state_t*) : XXH3_128_hash_t

  fun XXH128_canonicalFromHash(dst : XXH128_canonical_t*, hash : XXH128_hash_t)
  fun XXH128_hashFromCanonical(src : XXH128_canonical_t*) : XXH128_hash_t

  fun xxh3_64_scalar(input : Void*, length : LibC::SizeT, seed : XXH64HashT) : XXH64HashT
  fun xxh3_64_sse2(input : Void*, length : LibC::SizeT, seed : XXH64HashT) : XXH64HashT
  fun xxh3_64_avx2(input : Void*, length : LibC::SizeT, seed : XXH64HashT) : XXH64HashT
  fun xxh3_64_avx512(input : Void*, length : LibC::SizeT, seed : XXH64HashT) : XXH64HashT
  fun xxh3_64_neon(input : Void*, length : LibC::SizeT, seed : XXH64HashT) : XXH64HashT
  fun xxh3_64_sve(input : Void*, length : LibC::SizeT, seed : XXH64HashT) : XXH64HashT

  fun xxh3_128_scalar(input : Void*, length : LibC::SizeT, seed : XXH64HashT) : XXH3_128_hash_t
  fun xxh3_128_sse2(input : Void*, length : LibC::SizeT, seed : XXH64HashT) : XXH3_128_hash_t
  fun xxh3_128_avx2(input : Void*, length : LibC::SizeT, seed : XXH64HashT) : XXH3_128_hash_t
  fun xxh3_128_avx512(input : Void*, length : LibC::SizeT, seed : XXH64HashT) : XXH3_128_hash_t
  fun xxh3_128_neon(input : Void*, length : LibC::SizeT, seed : XXH64HashT) : XXH3_128_hash_t
  fun xxh3_128_sve(input : Void*, length : LibC::SizeT, seed : XXH64HashT) : XXH3_128_hash_t

  struct XXH_state_t
    bytes : UInt8[8]
  end

  alias XXH32_state_t = XXH_state_t
  alias XXH64_state_t = XXH_state_t
  alias XXH3_state_t = XXH_state_t
end
