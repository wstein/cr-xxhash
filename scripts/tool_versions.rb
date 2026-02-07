#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'
require 'json'
require 'optparse'

options = {
  json: false,
  tools: nil,
  output: nil
}

opt_parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options]"

  opts.on('--json', 'Output results as JSON') do
    options[:json] = true
  end

  opts.on('--tools x,y,z', Array, 'Comma-separated list of tools to check') do |list|
    options[:tools] = list.map(&:to_s)
  end

  opts.on('-o', '--output FILE', 'Write output to FILE (JSON)') do |file|
    options[:output] = file
  end

  opts.on('-h', '--help', 'Prints this help') do
    puts opts
    exit
  end
end

begin
  opt_parser.parse!(ARGV)
rescue OptionParser::InvalidOption => e
  warn "ERROR: #{e.message}\n"
  puts opt_parser
  exit 1
end

ALL_CHECKS = {
  'ruby' => 'ruby -v',
  'crystal' => 'crystal -v',
  'shards' => 'shards --version',
  'llvm-config' => 'llvm-config --version',
  'clang' => 'clang --version',
  'gcc' => 'gcc --version',
  'sw_vers' => 'sw_vers -productVersion',
  'uname' => 'uname -srm'
}

selected = if options[:tools]
  # validate requested tools
  unknown = options[:tools] - ALL_CHECKS.keys
  unless unknown.empty?
    warn "Unknown tools requested: #{unknown.join(', ')}\nAvailable: #{ALL_CHECKS.keys.join(', ')}"
    exit 2
  end
  ALL_CHECKS.slice(*options[:tools])
else
  ALL_CHECKS
end


def run(cmd)
  out, status = Open3.capture2e(cmd)
  return out.strip if status.success?
  nil
rescue Errno::ENOENT
  nil
end

results = {}
selected.each do |name, cmd|
  results[name] = run(cmd) || 'not found'
end

if options[:json] || options[:output]
  json_out = JSON.pretty_generate(results)
  if options[:output]
    File.write(options[:output], json_out)
    puts "Wrote JSON output to #{options[:output]}"
  else
    puts json_out
  end
else
  puts "Detected tool versions:\n\n"
  max = results.keys.map(&:length).max
  results.each do |k, v|
    puts format("%-#{max}s : %s", k, v)
  end
  puts "\nTip: run with --json to get machine-readable output, or --output file.json to write JSON to disk."
end
