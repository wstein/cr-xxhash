# Converts bench CSV into a human-friendly Markdown report and optionally updates README.md.
# Usage:
#   crystal run scripts/bench_csv_to_md.cr -- <csv-path> <md-out-path>
# Example:
#   crystal run scripts/bench_csv_to_md.cr -- bench_long_input_results.csv bench_reports/bench_long_input.md

require "time"
require "file_utils"

csv_path = ARGV.shift || "bench_long_input_results.csv"
out_path = ARGV.shift || "bench_reports/bench_long_input.md"

unless File.exists?(csv_path)
  STDERR.puts "CSV not found: #{csv_path}"
  exit 2
end

records = [] of Tuple(String, Int32, Float64, Float64)
# (timestamp, size_bytes, oneshot_median, stream_median)

File.each_line(csv_path) do |line|
  row = line.strip
  next if row.empty?
  cols = row.split(",")
  # If file contains a header (detect common header tokens)
  if cols[0].downcase.includes?("timestamp") || (cols.size > 1 && cols[1].downcase.includes?("size"))
    next
  end
  # Normalize: row expected to be: timestamp,size,oneshot_median,oneshot_mean,oneshot_std,stream_median,stream_mean,stream_std
  if cols.size < 7
    STDERR.puts "Skipping malformed CSV row: #{cols.inspect}"
    next
  end
  ts = cols[0]
  size = cols[1].to_i
  oneshot_median = cols[2].to_f
  stream_median = cols[5].to_f
  records << {ts, size.to_i32, oneshot_median, stream_median}
end

if records.empty?
  STDERR.puts "No bench records found in #{csv_path}"
  exit 1
end

# Sort by size ascending
records.sort_by! { |r| r[1] }

# Prepare table rows
table_rows = records.map do |ts, size, one, stream|
  size_kb = (size.to_f / 1024.0).round(0)
  ratio_pct = (stream / one * 100.0)
  [size_kb.to_i, one, stream, ratio_pct]
end

latest_ts = records.last[0]

md = String.build do |s|
  s << "# Nightly benchmark — long-input (XXH3, 64-bit)\n\n"
  s << "**Latest run:** #{latest_ts}\n\n"
  s << "This report converts `bench_long_input_results.csv` into a human-friendly table. The CSV is produced by `scripts/bench_long_input.cr` (oneshot vs streaming throughput measured in MB/s).\n\n"

  s << "| Size | One-shot median (MB/s) | Streaming median (MB/s) | Streaming / One-shot (%) |\n"
  s << "| ---: | ---: | ---: | ---: |\n"
  table_rows.each do |r|
    sz_kb = r[0]
    one = r[1]
    stream = r[2]
    pct = r[3]
    s << "| #{sz_kb} KB | #{one.round(2)} | #{stream.round(2)} | #{pct.round(2)}% |\n"
  end
  s << "\n"

  # Summary
  avg_one = table_rows.sum(0.0) { |r| r[1] } / table_rows.size
  avg_stream = table_rows.sum(0.0) { |r| r[2] } / table_rows.size
  avg_ratio = table_rows.sum(0.0) { |r| r[3] } / table_rows.size
  s << "**Summary (average across sizes):** one-shot ~ **#{avg_one.round(2)} MB/s**, streaming ~ **#{avg_stream.round(2)} MB/s** (streaming ≈ **#{avg_ratio.round(2)}%** of one-shot).\n\n"

  s << "> Note: oneshot uses the public `XXH::XXH3.hash64` fast path; streaming measures `XXH::XXH3::State64` throughput. Values vary by CPU and build flags.\n"
end

# Ensure output directory exists
FileUtils.mkdir_p(File.dirname(out_path))
File.write(out_path, md)
puts "Wrote #{out_path} (#{File.size(out_path)} bytes)"

# Also attempt to update README.md section between markers if they exist
readme = "README.md"
start_marker = "<!-- BENCH_TABLE_START -->"
end_marker = "<!-- BENCH_TABLE_END -->"
if File.exists?(readme)
  content = File.read(readme)
  if content.includes?(start_marker) && content.includes?(end_marker)
    before, rest = content.split(start_marker, 2)
    _old, after = rest.split(end_marker, 2)
    new_section = "\n#{start_marker}\n" + md + "\n#{end_marker}\n"
    new_content = before + new_section + after
    File.write(readme, new_content)
    puts "Updated #{readme} bench table between markers"
  else
    puts "README.md does not contain bench table markers; skipping README update"
  end
end
