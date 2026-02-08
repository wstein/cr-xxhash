# Benchmark midsize XXH3 128-bit: compare native vs FFI
# Usage: crystal scripts/bench_midsize.cr

require "../src/xxh/common.cr"
require "../src/xxh/xxh64.cr"
require "../src/xxh/xxh3.cr"
require "../src/ffi/bindings.cr"

sizes = [17, 20, 32, 48, 64, 96, 128, 129, 160, 200, 240]

# Use monotonic high-resolution timing with Time.instant
def now_seconds
  Time.instant
end

def bench(name : String, size : Int32, &block)
  input = Bytes.new(size) { |i| (i & 0xFF).to_u8 }
  # sanity check correctness
  native = XXH::XXH3.hash128(input)
  ffi_r = LibXXH.XXH3_128bits(input.to_unsafe, size)
  if native.low64 != ffi_r.low64 || native.high64 != ffi_r.high64
    puts "[WARN] correctness mismatch for size=#{size} (native != ffi)"
  end

  # warmup
  2_000.times { block.call }

  iterations = 10_000
  elapsed = 0.0
  loop do
    start = now_seconds
    iterations.times { block.call }
    elapsed = (now_seconds - start).total_seconds
    break if elapsed >= 1.0 || iterations >= 10_000_000
    iterations *= 2
  end

  bytes = size.to_f * iterations.to_f
  mbps = bytes / elapsed / 1024.0 / 1024.0

  puts "%6d B : %-12s -> %8.2f MB/s (%d it, %.3fs)" % [size, name, mbps, iterations, elapsed]
end

puts "Benchmarking XXH3 (native) vs LibXXH (FFI) for midsize inputs (17..240 bytes)"
puts "Note: results are a simple local microbenchmark; run on your system for final numbers\n"

sizes.each do |size|
  bench("native", size) do
    # convert to Bytes once rather than each iter to avoid allocation bias
    input = Bytes.new(size) { |i| (i & 0xFF).to_u8 }
    XXH::XXH3.hash128(input)
  end

  bench("ffi", size) do
    input = Bytes.new(size) { |i| (i & 0xFF).to_u8 }
    LibXXH.XXH3_128bits(input.to_unsafe, size)
  end

  puts "-" * 60
end
