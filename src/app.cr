# xxHash Crystal bindings and CLI
#
# This library provides Crystal bindings to the xxHash hashing algorithm family.
# It includes both the core hashing functionality and a CLI tool (xxhsum).

require "./ffi/bindings"

# Main module for xxHash Crystal bindings
module XXH
  VERSION = "0.1.0"

  # Get xxHash version number
  def self.version : UInt32
    LibXXH.versionNumber
  end

  # Get version as a string
  def self.version_string : String
    v = version
    "#{v / 100 / 100}.#{v / 100 % 100}.#{v % 100}"
  end
end

# Run CLI if this is the main executable
if File.basename(PROGRAM_NAME) == "xxhsum"
  require "./cli/main"
end
