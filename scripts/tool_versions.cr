#!/usr/bin/env crystal
# frozen_string_literal: true

require "json"
require "option_parser"

struct Options
  property json : Bool = false
  property tools : Array(String)? = nil
  property output : String? = nil
end

options = Options.new

opt_parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} [options]"

  opts.on("--json", "Output results as JSON") do
    options.json = true
  end

  opts.on("--tools x,y,z", "Comma-separated list of tools to check") do |val|
    options.tools = val.split(",").map(&.strip)
  end

  opts.on("-o", "--output FILE", "Write output to FILE (JSON)") do |file|
    options.output = file
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end

begin
  opt_parser.parse(ARGV)
rescue e : OptionParser::InvalidOption
  STDERR.puts "ERROR: #{e.message}"
  puts opt_parser
  exit 1
end

ALL_CHECKS = {
  "ruby"        => "ruby -v",
  "crystal"     => "crystal -v",
  "shards"      => "shards --version",
  "llvm-config" => "llvm-config --version",
  "clang"       => "clang --version",
  "gcc"         => "gcc --version",
  "sw_vers"     => "sw_vers -productVersion",
  "uname"       => "uname -srm",
}

selected = if (tools = options.tools)
             # validate requested tools
             unknown = tools - ALL_CHECKS.keys
             unless unknown.empty?
               STDERR.puts "Unknown tools requested: #{unknown.join(", ")}\nAvailable: #{ALL_CHECKS.keys.join(", ")}"
               exit 2
             end

             # Build a subset of checks explicitly (Crystal Hash doesn't have Ruby's `slice` helper)
             subset = {} of String => String
             tools.each do |t|
               subset[t] = ALL_CHECKS[t]
             end
             subset
           else
             ALL_CHECKS
           end

def run(cmd : String) : String?
  # Execute command and capture stdout (use shell when `cmd` contains spaces/flags)
  out = `sh -c "#{cmd}"`.to_s.strip
  if out.size > 0
    out
  else
    nil
  end
rescue e : Exception
  nil
end

results = {} of String => String
selected.each do |name, cmd|
  results[name] = run(cmd) || "not found"
end

if options.json || options.output
  json_out = results.to_json
  if options.output
    File.write(options.output.not_nil!, json_out)
    puts "Wrote JSON output to #{options.output.not_nil!}"
  else
    puts json_out
  end
else
  puts "Detected tool versions:\n\n"
  max = results.keys.map(&.size).max
  results.each do |k, v|
    puts sprintf("%-#{max}s : %s", k, v)
  end
  puts "\nTip: run with --json to get machine-readable output, or --output file.json to write JSON to disk."
end
