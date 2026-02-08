# xxHash Crystal bindings and CLI
#
# This library provides Crystal bindings to the xxHash hashing algorithm family.
# It includes both the core hashing functionality and a CLI tool (xxhsum).

# require "./ffi/bindings"

# Main module for xxHash Crystal bindings
module XXH
  VERSION = "0.1.0"

  # Get xxHash version number
  def self.version : UInt32
    VERSION
  end

  # Get version as a string
  def self.version_string : String
    v = version
    "#{v / 100 / 100}.#{v / 100 % 100}.#{v % 100}"
  end
end

# Run CLI if this executable looks like the xxHash CLI (support aliases like xxh32sum)
if File.basename(PROGRAM_NAME).downcase.starts_with?("xxh")
  require "./xxhsum"
end
