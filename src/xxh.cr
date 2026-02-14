require "./common/constants"
require "./common/types"
require "./common/errors"
require "./bindings/lib_xxh"
require "./bindings/safe"

# Main namespace entry point for XXH library
module XXH
  VERSION = "0.1.0"

  # Query vendored xxHash C library version
  def self.version_number : UInt32
    Bindings::Version.number
  end

  def self.version : String
    Bindings::Version.to_s
  end
end
