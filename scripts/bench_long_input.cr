#!/usr/bin/env crystal
# Lightweight long-input benchmark for XXH3 using current public API
# Usage:
#   crystal run --release scripts/bench_long_input.cr -- --samples=5 --target=0.5 --out=bench_long_input_results.csv

require "../src/xxh"
require "time"

# CLI args
samples = 5
target_seconds = 0.5
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

# Helpers
def now_seconds
  Time.instant
end

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
  n.odd? ? s[n.tdiv(2)] : (s[n.tdiv(2) - 1] + s[n.tdiv(2)]) / 2.0
end

# Run enough iterations to exceed target seconds
def timed_sample(target_sec : Float64)
  iterations = 128
  loop do
    start = now_seconds
    iterations.times { yield }
    elapsed = (now_seconds - start).total_seconds
    return [iterations, elapsed] if elapsed >= target_sec || iterations >= 10_000_000
    iterations *= 2
  end
end

# Bench: one-shot XXH3.hash64 and streaming via State64
def bench_size(size : Int32, samples : Int32, target_sec : Float64)
  buf = Bytes.new(size) { |i| (i & 0xFF).to_u8 }

  oneshot_samples = [] of Float64
  streaming_samples = [] of Float64

  # Warmup
  50.times { XXH::XXH3.hash64(buf) }

  samples.times do
    iters, elapsed = timed_sample(target_sec) { XXH::XXH3.hash64(buf) }
    oneshot_samples << (size.to_f * iters.to_f) / elapsed / 1024.0 / 1024.0

    # streaming (State64)
    iters, elapsed = timed_sample(target_sec) do
      st = XXH::XXH3::State64.new
      st.update(buf)
      st.digest
    end
    streaming_samples << (size.to_f * iters.to_f) / elapsed / 1024.0 / 1024.0
  end

  [
    size,
    median(oneshot_samples), mean(oneshot_samples), stddev(oneshot_samples),
    median(streaming_samples), mean(streaming_samples), stddev(streaming_samples)
  ]
end

# CSV output
header = ["timestamp", "size", "oneshot_median_mbps", "oneshot_mean_mbps", "oneshot_std_mbps", "stream_median_mbps", "stream_mean_mbps", "stream_std_mbps"]
new_file = !File.exists?(out_file)
File.open(out_file, new_file ? "w" : "a") do |f|
  f.puts header.join(",") if new_file
  [64 * 1024, 256 * 1024, 1024 * 1024].each do |size|
    row = bench_size(size.to_i32, samples.to_i32, target_seconds.to_f)
    f.puts [Time.local.to_s, *row].join(",")
  end
end

puts "Benchmarks written to #{out_file}"
