require "./spec_helper"
require "file"

describe "xxh*sum alias behavior" do
  aliases = {"xxh32sum" => 0, "xxh64sum" => 1, "xxh128sum" => 2, "xxh3sum" => 3}
  bin_dir = "./bin"
  test_file = "README.md"

  it "prints help with program name and alias-specific default algorithm" do
    aliases.each do |name, default|
      path = File.join(bin_dir, name)
      if !File.exists?(path)
        next
      else
        tmp = "/tmp/xxh_alias_help_#{Process.pid}_#{Random.rand(1_000_000)}.out"
        File.open(tmp, "w") { |f| Process.run(path, ["-h"], output: f) }
        begin
          help_text = File.read(tmp)
          help_text.includes?("Usage: #{name}").should be_true
          help_text.includes?("(default: #{default})").should be_true
        ensure
          File.delete(tmp) if File.exists?(tmp)
        end
      end
    end
  end

  it "hashes a file using the alias algorithm by default" do
    aliases.each do |name, default|
      path = File.join(bin_dir, name)
      if !File.exists?(path)
        next
      else
        tmp1 = "/tmp/xxh_alias_hash_crystal_#{Process.pid}_#{Random.rand(1_000_000)}.out"
        tmp2 = "/tmp/xxh_alias_hash_expected_#{Process.pid}_#{Random.rand(1_000_000)}.out"
        File.open(tmp1, "w") { |f| Process.run(path, [test_file], output: f) }
        File.open(tmp2, "w") { |f| Process.run("./bin/xxhsum", ["-H#{default}", test_file], output: f) }

        begin
          File.read(tmp1).strip.should eq(File.read(tmp2).strip)
        ensure
          File.delete(tmp1) if File.exists?(tmp1)
          File.delete(tmp2) if File.exists?(tmp2)
        end
      end
    end
  end
end
