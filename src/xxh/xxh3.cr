# XXH3 Hash Implementation - Module Aggregator
# This module imports the separated XXH3 implementations:
# - xxh3_types.cr: Hash128 struct
# - xxh3_base.cr: Shared helper and accumulation functions
# - xxh3_64.cr: 64-bit one-shot and long-input hashing
# - xxh3_128.cr: 128-bit one-shot and long-input hashing
#
# All implementations use stack-allocated UInt64[8] accumulators
# for optimal LLVM auto-vectorization in release builds.

require "./xxh3/xxh3_types"
require "./xxh3/xxh3_base"
require "./xxh3/xxh3_64"
require "./xxh3/xxh3_128"
require "./xxh3/state"
require "./xxh3/state128"

module XXH::XXH3
  # Streaming state wrapper moved to `src/xxh/xxh3/state.cr`
  # See that file for the `State` implementation and methods

  # 128-bit Streaming state wrapper (native)

  # 128-bit Streaming state wrapper moved to `src/xxh/xxh3/state128.cr`

  # factory helpers moved to `state.cr` and `state128.cr` to keep this module purely declarative
end
