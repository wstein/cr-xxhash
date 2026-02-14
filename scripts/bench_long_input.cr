# Hardened long-input streaming benchmark for XXH3: compare native streaming vs FFI streaming
# Usage:
#   crystal run --release scripts/bench_long_input.cr -- --samples=5 --target=1.0 --out=bench_long_input_results.csv

require "../src/common/common"
require "../src/common/primitives"
require "../src/xxh3/wrapper"
require "../src/vendor/bindings"

# Parse CLI args
samples = 5
target_seconds = 1.0
out_file = "bench_long_input_results.csv"

ARGV.each do |arg|
  if arg.starts_with?("--samples=")
    samples = arg.split("=")[1].to_i
  elsif arg.starts_with?("--target=")
    target_seconds = arg.split("=")[1].to_f
  elsif arg.starts_with?("--out=")
    out_file = arg.split("=")[1]
  end
end

# Basic monotonic timer
def now_seconds
  Time.instant
end

# Basic statistics helpers
def mean(arr : Array(Float64)) : Float64
  return 0.0 if arr.size == 0
  arr.sum / arr.size
end

def stddev(arr : Array(Float64)) : Float64
  return 0.0 if arr.size <= 1
  m = mean(arr)
  Math.sqrt(arr.sum { |x| (x - m) * (x - m) } / (arr.size - 1))
end

def median(arr : Array(Float64)) : Float64
  return 0.0 if arr.size == 0
  s = arr.sort
  n = s.size
  if n.odd?
    s[n.tdiv(2)]
  else
    (s[n.tdiv(2) - 1] + s[n.tdiv(2)]) / 2.0
  end
end

# Run a timed sample for the provided block, aiming for at least target seconds.
def timed_sample(target_sec : Float64, &block)
  iterations = 128
  loop do
    start = now_seconds
    iterations.times { block.call }
    elapsed = (now_seconds - start).total_seconds
    return [iterations, elapsed] if elapsed >= target_sec || iterations >= 10_000_000
    iterations *= 2
  end
end

# Measure throughput (MB/s) across multiple samples for native and ffi

def bench_streaming_for(size : Int32, bits : Int32, samples : Int32, target_sec : Float64)
  input = Bytes.new(size) { |i| (i & 0xFF).to_u8 }

  if bits == 64
    native_state = XXH::XXH3::State.new
    ffi_state_ptr = LibXXH.XXH3_createState
    # functions
    reset_native = -> { native_state.reset }
    update_native = -> { native_state.update(input) }
    reset_ffi = -> { LibXXH.XXH3_64bits_reset(ffi_state_ptr) }
    update_ffi = -> { LibXXH.XXH3_64bits_update(ffi_state_ptr, input.to_unsafe, size) }
  else
    native_state = XXH::XXH3::State128.new
    ffi_state_ptr = LibXXH.XXH3_createState
    reset_native = -> { native_state.reset }
    update_native = -> { native_state.update(input) }
    reset_ffi = -> { LibXXH.XXH3_128bits_reset(ffi_state_ptr) }
    update_ffi = -> { LibXXH.XXH3_128bits_update(ffi_state_ptr, input.to_unsafe, size) }
  end

  # Warmup (do a decent number to let caches / JIT-like effects stabilize)
  warmups = [100, 1000, (200_000 / (size / 1024 + 1)).to_i].max
  warmups.times do
    reset_native.call
    update_native.call
    if bits == 64
      (native_state.as(XXH::XXH3::State)).digest
    else
      (native_state.as(XXH::XXH3::State128)).digest
    end
    reset_ffi.call
    update_ffi.call
    if bits == 64
      LibXXH.XXH3_64bits_digest(ffi_state_ptr)
    else
      LibXXH.XXH3_128bits_digest(ffi_state_ptr)
    end
  end
  native_samples = [] of Float64
  ffi_samples = [] of Float64

  samples.times do |_|
    # native sample
    iterations, elapsed = timed_sample(target_sec) do
      reset_native.call
      update_native.call
      if bits == 64
        (native_state.as(XXH::XXH3::State)).digest
      else
        (native_state.as(XXH::XXH3::State128)).digest
      end
    end
    native_samples << (size.to_f * iterations.to_f) / elapsed / 1024.0 / 1024.0

    # ffi sample
    iterations, elapsed = timed_sample(target_sec) do
      reset_ffi.call
      update_ffi.call
      if bits == 64
        LibXXH.XXH3_64bits_digest(ffi_state_ptr)
      else
        LibXXH.XXH3_128bits_digest(ffi_state_ptr)
      end
    end
    ffi_samples << (size.to_f * iterations.to_f) / elapsed / 1024.0 / 1024.0
  end
  # correctness check
  reset_native.call
  update_native.call
  r_native : UInt64 | XXH::XXH3::Hash128
  r_ffi : UInt64 | LibXXH::XXH128_hash_t
  if bits == 64
    r_native = (native_state.as(XXH::XXH3::State)).digest
  else
    r_native = (native_state.as(XXH::XXH3::State128)).digest
  end
  reset_ffi.call
  update_ffi.call
  if bits == 64
    r_ffi = LibXXH.XXH3_64bits_digest(ffi_state_ptr)
  else
    r_ffi = LibXXH.XXH3_128bits_digest(ffi_state_ptr)
  end
  if bits == 64
    equal = (r_native.as(UInt64) == r_ffi.as(UInt64))
  else
    equal = (r_native.as(XXH::XXH3::Hash128).to_tuple == {r_ffi.as(LibXXH::XXH128_hash_t).low64, r_ffi.as(LibXXH::XXH128_hash_t).high64})
  end

  native_median = median(native_samples)
  native_mean = mean(native_samples)
  native_std = stddev(native_samples)

  ffi_median = median(ffi_samples)
  ffi_mean = mean(ffi_samples)
  ffi_std = stddev(ffi_samples)

  # print human-friendly
  puts "#{bits}-bit stream #{size / 1024}KB : native median=#{native_median.round(2)} MB/s (mean=#{native_mean.round(2)} std=#{native_std.round(2)}), ffi median=#{ffi_median.round(2)} MB/s (mean=#{ffi_mean.round(2)} std=#{ffi_std.round(2)}), equal=#{equal}"

  [size, bits, native_median, native_mean, native_std, ffi_median, ffi_mean, ffi_std, equal]
end

# CSV helpers
require "time"
header = ["timestamp", "size", "bits", "native_median_mbps", "native_mean_mbps", "native_std_mbps", "ffi_median_mbps", "ffi_mean_mbps", "ffi_std_mbps", "equal"]
new_file = !File.exists?(out_file)
f = if new_file
      File.new(out_file, "w")
    else
      File.new(out_file, "a")
    end
begin
  f.puts header.join(",") if new_file
  sizes = [1024 * 64, 1024 * 256, 1024 * 1024]
  sizes.each do |size|
    [64, 128].each do |bits|
      row = bench_streaming_for(size, bits, samples, target_seconds)
      f.puts [Time.local.to_s, *row].join(",")
    end
  end
ensure
  f.close
end

puts "Results appended to #{out_file}."
