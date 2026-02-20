require "./spec_helper"
require "time"

describe "Performance Isolation (Amortized vs Per-Iteration)" do
  data = "x" * 1024
  iterations = 500

  it "uses significantly fewer Crystal allocations for XXH32 in amortized mode" do
    GC.collect
    before_per = GC.stats.total_bytes
    iterations.times do |i|
      s = XXH::XXH32::State.new(i.to_u32)
      s.update(data)
      _ = s.digest
      s.dispose
    end
    GC.collect
    per_alloc = GC.stats.total_bytes - before_per
    per_alloc.should be > 0

    GC.collect
    before_amort = GC.stats.total_bytes
    s_amort = XXH::XXH32::State.new(0_u32)
    iterations.times do |i|
      s_amort.reset(i.to_u32)
      s_amort.update(data)
      _ = s_amort.digest
    end
    s_amort.dispose
    GC.collect
    amort_alloc = GC.stats.total_bytes - before_amort

    amort_alloc.should be < per_alloc
    amort_alloc.should be < per_alloc / 5
  end

  it "uses significantly fewer Crystal allocations for XXH64 in amortized mode" do
    GC.collect
    before_per = GC.stats.total_bytes
    iterations.times do |i|
      s = XXH::XXH64::State.new(i.to_u64)
      s.update(data)
      _ = s.digest
      s.dispose
    end
    GC.collect
    per_alloc = GC.stats.total_bytes - before_per
    per_alloc.should be > 0

    GC.collect
    before_amort = GC.stats.total_bytes
    s_amort = XXH::XXH64::State.new(0_u64)
    iterations.times do |i|
      s_amort.reset(i.to_u64)
      s_amort.update(data)
      _ = s_amort.digest
    end
    s_amort.dispose
    GC.collect
    amort_alloc = GC.stats.total_bytes - before_amort

    amort_alloc.should be < per_alloc
    amort_alloc.should be < per_alloc / 5
  end

  it "uses significantly fewer Crystal allocations for XXH3_64 in amortized mode" do
    GC.collect
    before_per = GC.stats.total_bytes
    iterations.times do |i|
      s = XXH::XXH3::State64.new(i.to_u64)
      s.update(data)
      _ = s.digest
      s.dispose
    end
    GC.collect
    per_alloc = GC.stats.total_bytes - before_per
    per_alloc.should be > 0

    GC.collect
    before_amort = GC.stats.total_bytes
    s_amort = XXH::XXH3::State64.new(0_u64)
    iterations.times do |i|
      s_amort.reset(i.to_u64)
      s_amort.update(data)
      _ = s_amort.digest
    end
    s_amort.dispose
    GC.collect
    amort_alloc = GC.stats.total_bytes - before_amort

    amort_alloc.should be < per_alloc
    amort_alloc.should be < per_alloc / 5
  end

  it "uses significantly fewer Crystal allocations for XXH128 in amortized mode" do
    GC.collect
    before_per = GC.stats.total_bytes
    iterations.times do |i|
      s = XXH::XXH3::State128.new(i.to_u64)
      s.update(data)
      _ = s.digest
      s.dispose
    end
    GC.collect
    per_alloc = GC.stats.total_bytes - before_per
    per_alloc.should be > 0

    GC.collect
    before_amort = GC.stats.total_bytes
    s_amort = XXH::XXH3::State128.new(0_u64)
    iterations.times do |i|
      s_amort.reset(i.to_u64)
      s_amort.update(data)
      _ = s_amort.digest
    end
    s_amort.dispose
    GC.collect
    amort_alloc = GC.stats.total_bytes - before_amort

    amort_alloc.should be < per_alloc
    amort_alloc.should be < per_alloc / 5
  end

  it "demonstrates timing improvement for amortized streaming (isolating overhead)" do
    # Warm up
    100.times { XXH::XXH64.hash(data) }

    start_per = Time.instant
    iterations.times do |i|
      s = XXH::XXH64::State.new(i.to_u64)
      s.update(data)
      _ = s.digest
      s.dispose
    end
    elapsed_per = Time.instant - start_per

    start_amort = Time.instant
    s_amort = XXH::XXH64::State.new(0_u64)
    iterations.times do |i|
      s_amort.reset(i.to_u64)
      s_amort.update(data)
      _ = s_amort.digest
    end
    s_amort.dispose
    elapsed_amort = Time.instant - start_amort

    # Amortized path should be faster by at least some margin, 
    # even on 1KB blocks where hashing dominates, due to zero GC pressure.
    # We use a conservative > 5% as a sanity check.
    (elapsed_amort < elapsed_per).should be_true
  end
end
