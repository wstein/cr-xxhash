#!/usr/bin/env bash
set -euo pipefail

# Reproduce preprocessed ARM64 scalar extraction (no NEON)
# Output files:
#  - vendor/xxhash-wrapper/vendor/xxHash/xxhash.aarch64.scalar.i    (full preprocessed header)
#  - vendor/xxhash-wrapper/vendor/xxHash/xxhash.aarch64.scalar.impl.c (trimmed implementation, NEON lines removed)

HEADER=vendor/xxhash-wrapper/vendor/xxHash/xxhash.h
PREOUT=vendor/xxhash-wrapper/vendor/xxHash/xxhash.aarch64.scalar.i
IMPLOUT=vendor/xxhash-wrapper/vendor/xxHash/xxhash.aarch64.scalar.impl.c

echo "Preprocessing $HEADER -> $PREOUT (ARM64 scalar, no NEON)"
clang -E -P -x c -std=c99 -DXXH_IMPLEMENTATION -DXXH_VECTOR=XXH_SCALAR -D__aarch64__ "$HEADER" -o "$PREOUT"

echo "Extracting implementation portion and stripping NEON lines -> $IMPLOUT"
awk 'BEGIN{found=0} /XXH32_round/{found=1} found{print}' "$PREOUT" | grep -v -i 'neon' > "$IMPLOUT"

echo "Done. Files written: $PREOUT, $IMPLOUT"