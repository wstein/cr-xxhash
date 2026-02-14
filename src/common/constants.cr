# Auto-generated from vendor/xxHash/xxhash.h
# DO NOT EDIT - run `crystal scripts/generate_constants.cr` to regenerate

lib LibXXH
  # Vendor macro constants (imported from C headers)
  # NOTE: Default secret (XXH3_kSecret / XXH_SECRET_DEFAULT_SIZE) is defined in vendor headers — keep hardcoded; it never changes.
  XXH3_SECRET_SIZE_MIN     =                    136
  XXH3_SECRET_DEFAULT_SIZE =                    192
  XXH_SECRET_DEFAULT_SIZE  =                    192
  XXH3_MIDSIZE_MAX         =                    240
  XXH3_MIDSIZE_STARTOFFSET =                      3
  XXH3_MIDSIZE_LASTOFFSET  =                     17
  XXH_STRIPE_LEN           =                     64
  XXH_PRIME32_1            =         0x9e3779b1_u32
  XXH_PRIME32_2            =         0x85ebca77_u32
  XXH_PRIME32_3            =         0xc2b2ae3d_u32
  XXH_PRIME32_4            =         0x27d4eb2f_u32
  XXH_PRIME32_5            =         0x165667b1_u32
  XXH_PRIME64_1            = 0x9e3779b185ebca87_u64
  XXH_PRIME64_2            = 0xc2b2ae3d27d4eb4f_u64
  XXH_PRIME64_3            = 0x165667b19e3779f9_u64
  XXH_PRIME64_4            = 0x85ebca77c2b2ae63_u64
  XXH_PRIME64_5            = 0x27d4eb2f165667c5_u64
end
